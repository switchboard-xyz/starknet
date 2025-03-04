use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::traits::{Into, TryInto};
use core::byte_array::{ByteArrayTrait, ByteArray};
use core::sha256::{compute_sha256_byte_array};
use core::starknet::eth_address::EthAddress;
use core::starknet::eth_signature::is_eth_signature_valid;
use core::starknet::secp256_trait::Signature;
use crate::signature::ecrecover;


// Import the SHA256 functions

const UNEXPECTED_EOF: felt252 = 'Unexpected end of input';

#[derive(Drop, Clone, Debug)]
pub struct Parser {
    pub data: ByteArray,
    pub offset: u32,
}

#[derive(Drop, Clone, Debug, Default)]
pub enum Message {
    #[default]
    Invalid,
    UpdateMessage: UpdateMessage,
    AttestationMessage: AttestationMessage,
    RandomnessMessage: RandomnessMessage,
}

#[derive(Clone, Drop, Debug, Serde)]
pub struct UpdateMessage {
    pub aggregator_id: felt252,
    pub result: i128,
    pub block_number: u64,
    pub r: u256,
    pub s: u256,
    pub v: u8,
    pub timestamp: u64,
}

#[derive(Clone, Drop, Debug, Serde)]
pub struct AttestationMessage {
    pub oracle_id: u256,
    pub queue_id: u256,
    pub mr_enclave: u256,
    pub ed25519_key: u256,
    pub secp256k1_key: ByteArray,
    pub block_number: u64,
    pub r: u256,
    pub s: u256,
    pub v: u8,
    pub timestamp: u64,
    pub guardian_id: u256,
}

#[derive(Clone, Drop, Debug, Serde)]
pub struct RandomnessMessage {
    pub randomness_id: u256,
    pub result: u256,
    pub r: u256,
    pub s: u256,
    pub v: u8,
    pub timestamp: u64,
}


#[generate_trait]
pub(crate) impl ToHashPayloadUpdateMessage of ToHashPayloadUpdateMessageTrait {
    fn to_hash_payload(
        self: @UpdateMessage, 
        queue: u256,
        feed_hash: u256,
        max_variance: u64,
        min_responses: u32
    ) -> UpdateHashPayload {
        UpdateHashPayload {
            queue,
            feed_hash,
            result: *self.result,
            latest_hash: Default::default(),
            max_variance,
            min_responses,
            timestamp: *self.timestamp,
            r: *self.r,
            s: *self.s,
            v: *self.v,
        }
    }
}

#[generate_trait]
pub(crate) impl ToHashPayloadAttestationMessage of ToHashPayloadAttestationMessageTrait {
    fn to_hash_payload(
        self: @AttestationMessage,
    ) -> AttestationHashPayload {
        AttestationHashPayload {
            oracle: *self.oracle_id,
            queue: *self.queue_id,
            mr_enclave: *self.mr_enclave,
            latest_hash: Default::default(),
            secp256k1_key: self.secp256k1_key.clone(),
            timestamp: *self.timestamp,
            r: *self.r,
            s: *self.s,
            v: *self.v,
        }
    }
}

#[generate_trait]
pub(crate) impl ToHashPayloadRandomnessMessage of ToHashPayloadRandomnessMessageTrait {
    fn to_hash_payload(
        self: @RandomnessMessage,
        min_staleness_seconds: u64,
    ) -> RandomnessHashPayload {
        RandomnessHashPayload {
            randomness_id: *self.randomness_id,
            timestamp: *self.timestamp,
            min_staleness_seconds,
            randomness: *self.result,
            r: *self.r,
            s: *self.s,
            v: *self.v,
        }
    }
}

#[derive(Clone, Drop, Debug, Serde)]
pub struct UpdateHashPayload {
    pub queue: u256,
    pub feed_hash: u256,
    pub result: i128,
    pub latest_hash: u256,
    pub max_variance: u64,
    pub min_responses: u32,
    pub timestamp: u64,
    pub r: u256,
    pub s: u256,
    pub v: u8,
}

#[derive(Clone, Drop, Debug, Serde)]
pub struct AttestationHashPayload {
    pub oracle: u256,
    pub queue: u256,
    pub mr_enclave: u256,
    pub latest_hash: u256,
    pub secp256k1_key: ByteArray,
    pub timestamp: u64,
    pub r: u256,
    pub s: u256,
    pub v: u8,
}

#[derive(Clone, Drop, Debug, Serde)]
pub struct RandomnessHashPayload {
    pub randomness_id: u256,
    pub timestamp: u64,
    pub min_staleness_seconds: u64,
    pub randomness: u256,
    pub r: u256,
    pub s: u256,
    pub v: u8,
}


// Helper functions for bit manipulation
fn u32_from_byte_array(bytes: Array<u8>) -> u32 {
    assert(bytes.len() == 4, 'Invalid byte array length');
    let b0: u32 = (*bytes[0]).into();
    let b1: u32 = (*bytes[1]).into();
    let b2: u32 = (*bytes[2]).into();
    let b3: u32 = (*bytes[3]).into();
    b0 * 0x1000000 + b1 * 0x10000 + b2 * 0x100 + b3
}

#[generate_trait]
pub impl ParserImpl of ParserTrait {
    fn new(data: ByteArray) -> Parser {
        Parser { data, offset: 0 }
    }

    fn parse_u8(ref self: Parser) -> u8 {
        assert(self.offset < self.data.len(), UNEXPECTED_EOF);
        let value = self.data.at(self.offset).unwrap();
        self.offset += 1;
        value
    }

    fn parse_u16(ref self: Parser) -> u16 {
        let a: u16 = self.parse_u8().into();
        let b: u16 = self.parse_u8().into();
        a * 0x100 + b
    }

    fn parse_u32(ref self: Parser) -> u32 {
        let mut bytes = ArrayTrait::new();
        bytes.append(self.parse_u8());
        bytes.append(self.parse_u8());
        bytes.append(self.parse_u8());
        bytes.append(self.parse_u8());
        u32_from_byte_array(bytes)
    }

    fn parse_u64(ref self: Parser) -> u64 {
        let high: u64 = self.parse_u32().into();
        let low: u64 = self.parse_u32().into();
        high * 0x100000000 + low
    }

    fn parse_u128(ref self: Parser) -> u128 {
        let high: u128 = self.parse_u64().into();
        let low: u128 = self.parse_u64().into();
        high * 0x10000000000000000 + low
    }

    fn parse_bytes32(ref self: Parser) -> u256 {
        let byte_array = self.parse_n_bytes(32);
        
        let mut high: u128 = 0;
        let mut low: u128 = 0;

        // Extract high part (first 16 bytes)
        let mut i: usize = 0;
        loop {
            if i == 16 {
                break;
            }
            high = high * 256 + (byte_array.at(i).unwrap()).into();
            i += 1;
        };

        // Extract low part (last 16 bytes)
        loop {
            if i == 32 {
                break;
            }
            low = low * 256 + (byte_array.at(i).unwrap()).into();
            i += 1;
        };

        u256 {
            high: high,
            low: low,
        }
    }

    fn parse_n_bytes(ref self: Parser, size: u32) -> ByteArray {
        let mut bytearray: ByteArray = Default::default();
        let mut i = 0;
        loop {
            if i == size {
                break;
            }
            bytearray.append_byte(self.parse_u8());
            i += 1;
        };   
        bytearray
    }

    fn parse_u256(ref self: Parser) -> u256 {
        let high = self.parse_u128();
        let low = self.parse_u128();
        u256 { high, low }
    }

    fn parse_i128(ref self: Parser) -> i128 {
        let byte_array = self.parse_n_bytes(16).rev();
        
        // Convert ByteArray to u128 first
        let mut value: u128 = 0_u128;
        let mut multiplier: u128 = 1_u128;
        let len = byte_array.len();
        let mut i: usize = 0;
        loop {
            value += byte_array[i].into() * multiplier;
            i += 1;
            if i >= len {
                break;
            }
            multiplier *= 256_u128;
        };
        
        // Check if the number is negative (most significant bit is 1)
        if (value & 0x80000000000000000000000000000000_u128) != 0_u128 {

            // For negative numbers, perform two's complement conversion
            let positive_value = (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128 - value + 1_u128) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u128;
            -1 * positive_value.try_into().unwrap()
        } else {

            // For positive numbers, just convert to i128
            value.try_into().unwrap()
        }
    }

    fn parse_felt252(ref self: Parser) -> felt252 {
        let byte_array = self.parse_n_bytes(31);
        let mut value: felt252 = 0;
        let mut i = 0;
        loop {
            value = value * 256 + (byte_array.at(i).unwrap()).into();
            i += 1;
            if i == 31 {
                break;
            }
        };
        value
    }

    fn next(ref self: Parser, n: u32) {
        assert(self.offset + n <= self.data.len(), UNEXPECTED_EOF);
        self.offset += n;
    }
}

#[derive(Drop, Clone, Debug)]
pub struct HashState {
    buffer: ByteArray,
}

#[generate_trait]
pub impl HashStateImpl of HashStateTrait {
    fn new() -> HashState {
        HashState { buffer: Default::default()}
    }

    fn push_u8(ref self: HashState, value: u8) {
        self.buffer.append_byte(value.into());
    }

    fn push_u32(ref self: HashState, value: u32) {
        self.buffer.append_word(value.into(), 4);
    }

    fn push_u32_rev(ref self: HashState, value: u32) {
        self.buffer.append_word_rev(value.into(), 4);
    }

    fn push_u64(ref self: HashState, value: u64) {
        self.buffer.append_word(value.into(), 8);
    }

    fn push_u64_rev(ref self: HashState, value: u64) {
        self.buffer.append_word_rev(value.into(), 8);
    }

    fn push_u128(ref self: HashState, value: u128) {
        self.buffer.append_word(value.into(), 16);
    }

    fn push_i128(ref self: HashState, value: i128) {
       self.buffer.append_word(value.try_into().unwrap(), 16);
    }

    fn push_i128_rev(ref self: HashState, value: i128) {
        self.buffer.append_word_rev(value.try_into().unwrap(), 16);
    }

    fn push_bytes_32(ref self: HashState, value: u256) {
        let high = value.high;
        let low = value.low;
        self.buffer.append_word(high.into(), 16);
        self.buffer.append_word(low.into(), 16);
    }

    fn push_u256(ref self: HashState, value: u256) {
        self.push_u128(value.high.into());
        self.push_u128(value.low.into());
    }

    fn push_felt252(ref self: HashState, value: felt252) {
        self.buffer.append_word(value, 31);
    }

    fn push_bytes(ref self: HashState, value: @ByteArray) {
        self.buffer.append(value)
    }

    fn finalize(ref self: HashState) -> u256 {
        let hash: [u32; 8] = compute_sha256_byte_array(@self.buffer);
        let [a, b, c, d, e, f, g, h] = hash;
        let mut result: u256 = 0.into();
        result = (result + a.into()) * 0x100000000_u256;
        result = (result + b.into()) * 0x100000000_u256;
        result = (result + c.into()) * 0x100000000_u256;
        result = (result + d.into()) * 0x100000000_u256;
        result = (result + e.into()) * 0x100000000_u256;
        result = (result + f.into()) * 0x100000000_u256;
        result = (result + g.into()) * 0x100000000_u256;
        result = result + h.into();
        result
    }
}

pub fn parse_message(payload: ByteArray) -> Message {
    let mut reader = ParserImpl::new(payload);
    let discriminator = reader.parse_u8();
    match discriminator {
        1 => Message::UpdateMessage(parse_update_message(ref reader)),
        2 => Message::AttestationMessage(parse_attestation_message(ref reader)),
        3 => Message::RandomnessMessage(parse_randomness_message(ref reader)),
        0 | _ => Message::Invalid,
    }
}

pub fn parse_update_message(ref reader: Parser) -> UpdateMessage {
    let aggregator_id = reader.parse_felt252();
    reader.next(1); // skip the last aggregator_id byte (doesn't fit)
    UpdateMessage {
        aggregator_id: aggregator_id,
        result: reader.parse_i128(), 
        r: reader.parse_bytes32(),
        s: reader.parse_bytes32(),
        v: reader.parse_u8(),
        block_number: reader.parse_u64(),
        timestamp: reader.parse_u64(),
    }
}

pub fn parse_attestation_message(ref reader: Parser) -> AttestationMessage {
    AttestationMessage {
        oracle_id: reader.parse_bytes32(),
        queue_id: reader.parse_bytes32(),
        mr_enclave: reader.parse_bytes32(),
        ed25519_key: reader.parse_bytes32(),
        secp256k1_key: reader.parse_n_bytes(65),
        block_number: reader.parse_u64(),
        r: reader.parse_bytes32(),
        s: reader.parse_bytes32(),
        v: reader.parse_u8(),
        guardian_id: reader.parse_bytes32(),
        timestamp: reader.parse_u64(),
    }
}

pub fn parse_randomness_message(ref reader: Parser) -> RandomnessMessage {
    RandomnessMessage {
        randomness_id: reader.parse_bytes32(),
        result: reader.parse_bytes32(),
        r: reader.parse_bytes32(),
        s: reader.parse_bytes32(),
        v: reader.parse_u8(),
        timestamp: reader.parse_u64(),
    }
}

// Define the Hashable trait
pub trait Hashable<T> {
    fn hash(self: @T) -> u256;
}

// Implement Hashable for UpdateHashPayload
pub impl HashableUpdateHashPayload of Hashable<UpdateHashPayload> {
    fn hash(self: @UpdateHashPayload) -> u256 {
        let mut hash_state = HashStateImpl::new();
        hash_state.push_u256(*self.queue);
        hash_state.push_u256(*self.feed_hash);
        hash_state.push_i128_rev(*self.result);
        hash_state.push_u256(*self.latest_hash);
        hash_state.push_u64_rev(*self.max_variance);
        hash_state.push_u32_rev(*self.min_responses);
        hash_state.push_u64_rev(*self.timestamp);
        hash_state.finalize()
    }
}

// Implement Hashable for AttestationHashPayload
pub impl HashableAttestationHashPayload of Hashable<AttestationHashPayload> {
    fn hash(self: @AttestationHashPayload) -> u256 {
        let mut hash_state = HashStateImpl::new();
        hash_state.push_u256(*self.oracle);
        hash_state.push_u256(*self.queue);
        hash_state.push_u256(*self.mr_enclave);
        hash_state.push_u256(*self.latest_hash);
        // Assuming secp256k1_key is a fixed-size array or slice
        hash_state.push_bytes(self.secp256k1_key);
        hash_state.push_u64_rev(*self.timestamp);
        hash_state.finalize()
    }
}

// Implement Hashable for RandomnessHashPayload
pub impl HashableRandomnessHashPayload of Hashable<RandomnessHashPayload> {
    fn hash(self: @RandomnessHashPayload) -> u256 {
        let mut hash_state = HashStateImpl::new();
        hash_state.push_u256(*self.randomness_id);
        hash_state.push_u64_rev(*self.timestamp);
        hash_state.push_u64_rev(*self.min_staleness_seconds);
        hash_state.push_u256(*self.randomness);
        hash_state.finalize()
    }
}


pub trait Verifiable<T> {
    fn verify(self: @T, address: EthAddress) -> Result<(), felt252>;
    fn recover_address(self: @T) -> Result<EthAddress, felt252>;
}

pub impl VerifiableUpdateMessage of Verifiable<UpdateHashPayload> {
    fn verify(self: @UpdateHashPayload, address: EthAddress) -> Result<(), felt252> {
        let hash = self.hash();
        let signature = Signature {
            r: *self.r,
            s: *self.s,
            y_parity: (*self.v % 2) > 0
        };
        is_eth_signature_valid(hash, signature, address)
    }
    fn recover_address(self: @UpdateHashPayload) -> Result<EthAddress, felt252> {
        let hash = self.hash();
        let signature = Signature {
            r: *self.r,
            s: *self.s,
            y_parity: (*self.v % 2) > 0
        };
        ecrecover(hash, signature)
    }
}

pub impl VerifiableAttestationMessage of Verifiable<AttestationHashPayload> {
    fn verify(self: @AttestationHashPayload, address: EthAddress) -> Result<(), felt252> {
        let hash = self.hash();
        let signature = Signature {
            r: *self.r,
            s: *self.s,
            y_parity: (*self.v % 2) > 0
        };
        is_eth_signature_valid(hash, signature, address)
    }
    fn recover_address(self: @AttestationHashPayload) -> Result<EthAddress, felt252> {
        let hash = self.hash();
        let signature = Signature {
            r: *self.r,
            s: *self.s,
            y_parity: (*self.v % 2) > 0
        };
        ecrecover(hash, signature)
    }
}

pub impl VerifiableRandomnessMessage of Verifiable<RandomnessHashPayload> {
    fn verify(self: @RandomnessHashPayload, address: EthAddress) -> Result<(), felt252> {
        let hash = self.hash();
        let signature = Signature {
            r: *self.r,
            s: *self.s,
            y_parity: (*self.v % 2) > 0
        };
        is_eth_signature_valid(hash, signature, address)
    }
    fn recover_address(self: @RandomnessHashPayload) -> Result<EthAddress, felt252> {
        let hash = self.hash();
        let signature = Signature {
            r: *self.r,
            s: *self.s,
            y_parity: (*self.v % 2) > 0
        };
        ecrecover(hash, signature)
    }
}



#[cfg(test)]
mod tests {
    use super::{
        ParserImpl, 
        HashStateImpl, 
        ecrecover,
        parse_update_message
    };
    use core::array::SpanTrait;
    use core::starknet::secp256_trait::Signature;

    // Helper function to create a ByteArray from a list of u8 values
    fn create_byte_array(values: Array<u8>) -> ByteArray {
        let mut byte_array: ByteArray = Default::default();
        let mut span = values.span();
        loop {
            match span.pop_front() {
                Option::Some(value) => byte_array.append_byte(*value),
                Option::None => { break; }
            };
        };
        byte_array
    }

    #[test]
    fn test_parse_u8() {
        let data = create_byte_array(array![42]);
        let mut parser = ParserImpl::new(data);
        assert!(parser.parse_u8() == 42, "Failed to parse u8");
    }

    #[test]
    fn test_parse_u16() {
        let data = create_byte_array(array![1, 234]);
        let mut parser = ParserImpl::new(data);
        assert!(parser.parse_u16() == 0x01ea, "Failed to parse u16");
    }

    #[test]
    fn test_parse_u32() {
        let data = create_byte_array(array![0x12, 0x34, 0x56, 0x78]);
        let mut parser = ParserImpl::new(data);
        assert!(parser.parse_u32() == 0x12345678, "Failed to parse u32");
    }

    #[test]
    fn test_parse_u64() {
        let data = create_byte_array(array![0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]);
        let mut parser = ParserImpl::new(data);
        assert!(parser.parse_u64() == 0x1122334455667788, "Failed to parse u64");
    }

    #[test]
    fn test_parse_u128() {
        let data = create_byte_array(array![
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
            0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00
        ]);
        let mut parser = ParserImpl::new(data);
        assert!(
            parser.parse_u128() ==
            0x112233445566778899aabbccddeeff00,
            "Failed to parse u128"
        );
    }

    #[test]
    fn test_parse_bytes32() {
        let data = create_byte_array(array![
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
            0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88,
            0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00
        ]);
        let mut parser = ParserImpl::new(data);
        let result = parser.parse_bytes32();
        assert!(
            result ==
            u256 {
                high: 0x00112233445566778899aabbccddeeff,
                low: 0xffeeddccbbaa99887766554433221100_u128
            },
            "Failed to parse bytes32 {:?} {:?}",
            result.high,
            result.low
        );
    }

    #[test]
    fn test_parse_n_bytes() {
        let data = create_byte_array(array![0x11, 0x22, 0x33, 0x44, 0x55]);
        let mut parser = ParserImpl::new(data);
        let result = parser.parse_n_bytes(3);
        assert!(result == create_byte_array(array![0x11, 0x22, 0x33]), "Failed to parse n bytes expected: {:?}, got {:?}", create_byte_array(array![0x11, 0x22, 0x33]), result);
    }

    #[test]
    fn test_parse_u256() {
        let data = create_byte_array(array![
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
            0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00,
            0x00, 0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99,
            0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11
        ]);
        let mut parser = ParserImpl::new(data);
        let result = parser.parse_u256();
        assert!(
            result ==
            u256 {
                high: 0x112233445566778899aabbccddeeff00,
                low: 0x00ffeeddccbbaa998877665544332211
            },
            "Failed to parse u256"
        );
    }

    #[test]
    fn test_parse_i128() {
        let data = create_byte_array(array![
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFA, 0xC7
        ]);
        let mut parser = ParserImpl::new(data);
        let result = parser.parse_i128();
        assert!(
            result == -1337,
            "Negative two's complement doesn't work I guess Got: {:?}, expected: {:?}",
            result,
            -1337
        );
    }

    #[test]
    fn test_parse_felt252() {
        let data = create_byte_array(array![
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
            0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
            0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88,
            0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11
        ]);
        let mut parser = ParserImpl::new(data);
        let result = parser.parse_felt252();
        assert!(
            result ==
            0x00112233445566778899aabbccddeeffffeeddccbbaa998877665544332211,
            "Failed to parse felt252. Got: {:?}, Expected: {:?}",
            result,
            0x00112233445566778899aabbccddeeffffeeddccbbaa998877665544332211
        );
    }

    #[test]
    fn test_hash_state() {
        let mut hash_state = HashStateImpl::new();
        hash_state.push_u8(0x42);

        // Test Push u8
        assert!(
            hash_state.buffer.at(0).unwrap() == 0x42, "Failed to push u8"
        );

        hash_state.push_u32(0x12345678);

        // Test Push u32
        assert!(
            hash_state.buffer.at(1).unwrap() == 0x12, "Failed to push u32"
        );
        assert!(
            hash_state.buffer.at(2).unwrap() == 0x34, "Failed to push u32"
        );
        assert!(
            hash_state.buffer.at(3).unwrap() == 0x56, "Failed to push u32"
        );
        assert!(
            hash_state.buffer.at(4).unwrap() == 0x78, "Failed to push u32"
        );

        hash_state.push_u64(0x1122334455667788);

        // Test Push u64
        assert!(
            hash_state.buffer.at(5).unwrap() == 0x11, "Failed to push u64"
        );
        assert!(
            hash_state.buffer.at(6).unwrap() == 0x22, "Failed to push u64"
        );
        assert!(
            hash_state.buffer.at(7).unwrap() == 0x33, "Failed to push u64"
        );
        assert!(
            hash_state.buffer.at(8).unwrap() == 0x44, "Failed to push u64"
        );
        assert!(
            hash_state.buffer.at(9).unwrap() == 0x55, "Failed to push u64"
        );
        assert!(
            hash_state.buffer.at(10).unwrap() == 0x66, "Failed to push u64"
        );
        assert!(
            hash_state.buffer.at(11).unwrap() == 0x77, "Failed to push u64"
        );
        assert!(
            hash_state.buffer.at(12).unwrap() == 0x88, "Failed to push u64"
        );

        hash_state.push_u128(0x112233445566778899aabbccddeeff00);

        // Test Push u128
        assert!(
            hash_state.buffer.at(13).unwrap() == 0x11, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(14).unwrap() == 0x22, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(15).unwrap() == 0x33, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(16).unwrap() == 0x44, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(17).unwrap() == 0x55, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(18).unwrap() == 0x66, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(19).unwrap() == 0x77, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(20).unwrap() == 0x88, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(21).unwrap() == 0x99, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(22).unwrap() == 0xaa, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(23).unwrap() == 0xbb, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(24).unwrap() == 0xcc, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(25).unwrap() == 0xdd, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(26).unwrap() == 0xee, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(27).unwrap() == 0xff, "Failed to push u128"
        );
        assert!(
            hash_state.buffer.at(28).unwrap() == 0x00, "Failed to push u128"
        );


        hash_state.push_bytes_32(u256 {
            high: 0x112233445566778899aabbccddeeff00,
            low: 0x112233445566778899aabbccddeeff00
        });

        // Test Push bytes32
        assert!(
            hash_state.buffer.at(29).unwrap() == 0x11, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(30).unwrap() == 0x22, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(31).unwrap() == 0x33, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(32).unwrap() == 0x44, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(33).unwrap() == 0x55, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(34).unwrap() == 0x66, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(35).unwrap() == 0x77, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(36).unwrap() == 0x88, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(37).unwrap() == 0x99, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(38).unwrap() == 0xaa, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(39).unwrap() == 0xbb, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(40).unwrap() == 0xcc, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(41).unwrap() == 0xdd, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(42).unwrap() == 0xee, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(43).unwrap() == 0xff, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(44).unwrap() == 0x00, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(45).unwrap() == 0x11, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(46).unwrap() == 0x22, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(47).unwrap() == 0x33, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(48).unwrap() == 0x44, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(49).unwrap() == 0x55, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(50).unwrap() == 0x66, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(51).unwrap() == 0x77, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(52).unwrap() == 0x88, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(53).unwrap() == 0x99, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(54).unwrap() == 0xaa, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(55).unwrap() == 0xbb, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(56).unwrap() == 0xcc, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(57).unwrap() == 0xdd, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(58).unwrap() == 0xee, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(59).unwrap() == 0xff, "Failed to push bytes32"
        );
        assert!(
            hash_state.buffer.at(60).unwrap() == 0x00, "Failed to push bytes32"
        );

        hash_state.push_u32_rev(0x12345678);

        // Test Push u32 rev (just to test that rev works)
        assert!(
            hash_state.buffer.at(61).unwrap() == 0x78, "Failed to push u32 rev"
        );
        assert!(
            hash_state.buffer.at(62).unwrap() == 0x56, "Failed to push u32 rev"
        );
        assert!(
            hash_state.buffer.at(63).unwrap() == 0x34, "Failed to push u32 rev"
        );
        assert!(
            hash_state.buffer.at(64).unwrap() == 0x12, "Failed to push u32 rev"
        );
    }

    #[test]
    fn test_hash_sha256() {
        let mut hash_state = HashStateImpl::new();
        hash_state.push_u32(0x12345678);
        let hash = hash_state.finalize();
        assert!(
            hash == 0xb2ed992186a5cb19f6668aade821f502c1d00970dfd0e35128d51bac4649916c,
            "Failed to hash sha256"
        );
    }

    #[test]
    fn test_parse_update_message() {
        let data = create_byte_array(array![
            0x01, 0xf9, 0x79, 0x36, 0x47, 0x59, 0x84, 0xc2, 0xd7, 
            0xf2, 0x26, 0x27, 0xb3, 0x23, 0xac, 0x66, 0x30, 0xd0, 
            0xc0, 0xc1, 0x77, 0x98, 0x89, 0x2c, 0x14, 0x89, 0x18, 
            0x6c, 0x4d, 0xb0, 0x3a, 0xd0, 0x3a, 0x00, 0x00, 0x00, 
            0x00, 0x00, 0x00, 0x0e, 0x5d, 0x7d, 0xe6, 0x5d, 0x32, 
            0x4b, 0x5f, 0x00, 0x00, 0x17, 0x35, 0x6e, 0xb3, 0xed, 
            0xa8, 0xfb, 0xff, 0x19, 0x46, 0x01, 0xe3, 0xb4, 0x5e, 
            0xd2, 0xdc, 0xf2, 0x0b, 0x0c, 0x80, 0x7e, 0x04, 0x88, 
            0x01, 0xdd, 0x82, 0x20, 0x49, 0x1e, 0x59, 0xe5, 0xff, 
            0x38, 0x5c, 0x5a, 0x89, 0x62, 0x8b, 0x81, 0x83, 0xfd, 
            0xe8, 0xfd, 0xa7, 0x05, 0xc8, 0x43, 0xe9, 0xa9, 0xf4, 
            0x28, 0xd2, 0x0f, 0x6e, 0x9f, 0x25, 0x33, 0xb7, 0x41, 
            0x10, 0xfc, 0x25, 0x88, 0xb2, 0x00, 0x00, 0x00, 0x00, 
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
            0x67, 0x10, 0x1f, 0x5a
        ]);
        let mut parser = ParserImpl::new(data);

        let discriminator = parser.parse_u8();

        println!("Discriminator: {:?}", discriminator);

        let result = parse_update_message(ref parser);
        println!("Parsed Message: {:?}", result);
        assert!(
            result.aggregator_id == 0xf97936475984c2d7f22627b323ac6630d0c0c17798892c1489186c4db03ad0,
            "Failed to parse aggregator_id"
        );
    }


    #[test]
    fn test_hash_update_message() {
        let data = create_byte_array(array![
            0x01, 0xf9, 0x79, 0x36, 0x47, 0x59, 0x84, 0xc2, 0xd7, 
            0xf2, 0x26, 0x27, 0xb3, 0x23, 0xac, 0x66, 0x30, 0xd0, 
            0xc0, 0xc1, 0x77, 0x98, 0x89, 0x2c, 0x14, 0x89, 0x18, 
            0x6c, 0x4d, 0xb0, 0x3a, 0xd0, 0x3a, 0x00, 0x00, 0x00, 
            0x00, 0x00, 0x00, 0x0e, 0x51, 0x13, 0x54, 0xd2, 0xb3, 
            0xcf, 0xe7, 0x00, 0x00, 0xec, 0x72, 0xfa, 0x08, 0x59, 
            0x1f, 0xcb, 0x7e, 0xe1, 0xed, 0x9b, 0xeb, 0xa4, 0x69, 
            0x7b, 0xe8, 0x4b, 0x3d, 0x3a, 0x60, 0x82, 0x7d, 0x28, 
            0xf1, 0x62, 0xd9, 0x4c, 0xdb, 0x23, 0xfc, 0x9c, 0xc2, 
            0x58, 0x6a, 0xc1, 0xb7, 0xa4, 0x9c, 0x14, 0x4d, 0xb8, 
            0x0e, 0xe6, 0x7d, 0x32, 0x18, 0xef, 0xde, 0xb6, 0xa5, 
            0x97, 0x1c, 0x90, 0x27, 0x31, 0x6f, 0xee, 0x52, 0xc1, 
            0x0b, 0x49, 0x12, 0xd5, 0xcb, 0x00, 0x00, 0x00, 0x00, 
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
            0x67, 0x10, 0x8a, 0x8a        
        ]);


        let mut parser = ParserImpl::new(data);

        let discriminator = parser.parse_u8();

        println!("Discriminator: {:?}", discriminator);

        let result = parse_update_message(ref parser);
        println!("Parsed Message: {:?}", result);
        assert!(
            result.aggregator_id == 0xf97936475984c2d7f22627b323ac6630d0c0c17798892c1489186c4db03ad0,
            "Failed to parse aggregator_id"
        );

        let queue_id = u256 {
            high: 178783445323468125841319428710737118845,
            low: 74945712573840511956318748399253522258
        };
        let latest_hash = u256 {
            high: 0,
            low: 0
        };
        let max_variance: u64 = 5000000000;
        let min_responses: u32 = 1;
        let timestamp: u64 = result.timestamp;
        let feed_hash: u256 = u256 {
            high: 0x013b9b2fb2bdd9e3610df0d7f3e31870,
            low: 0xa1517a683efb0be2f77a8382b4085833,
        };
        let success_value: i128 = result.result;

        let mut hash_state = HashStateImpl::new();
        hash_state.push_u256(queue_id);
        hash_state.push_u256(feed_hash);
        hash_state.push_i128_rev(success_value);
        hash_state.push_u256(latest_hash);
        hash_state.push_u64_rev(max_variance);
        hash_state.push_u32_rev(min_responses);
        hash_state.push_u64_rev(timestamp);

        println!("queue_id: {:?}", queue_id);
        println!("feed_hash: {:?}", feed_hash);
        println!("success_value: {:?}", success_value);
        println!("latest_hash: {:?}", latest_hash);
        println!("max_variance: {:?}", max_variance);
        println!("min_responses: {:?}", min_responses);
        println!("timestamp: {:?}", timestamp);

        let hash = hash_state.finalize();
        println!("Hash: {:?}", hash);

        // recover address
        let signature = Signature {
            r: result.r,
            s: result.s,
            y_parity: result.v % 2 > 0
        };

        let address = ecrecover(hash, signature).unwrap();

        println!("Address: {:?}", address);
        let expected_address: felt252 = 0x4F451242291B2641A0A5EFB16FD66A1A41186BA6;

        assert(
            address == expected_address.try_into().unwrap(),
            'Failed to recover address'
        );

    }
}