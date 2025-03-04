#[allow(unused_imports)]
use starknet::{
    EthAddress,
    secp256_trait::{
        Secp256Trait, Secp256PointTrait, recover_public_key, is_signature_entry_valid, Signature
    },
    secp256k1::Secp256k1Point, SyscallResult, SyscallResultTrait
};
use core::byte_array::{ByteArray};
use starknet::eth_signature::public_key_point_to_eth_address;
use crate::message::{ParserTrait};

pub fn ecrecover(
    msg_hash: u256, 
    signature: Signature
) -> Result<EthAddress, felt252> {
    if !is_signature_entry_valid::<Secp256k1Point>(signature.r) {
        return Result::Err('Signature out of range');
    }
    if !is_signature_entry_valid::<Secp256k1Point>(signature.s) {
        return Result::Err('Signature out of range');
    }

    let public_key_point = recover_public_key::<Secp256k1Point>(:msg_hash, :signature).unwrap();
    let calculated_eth_address = public_key_point_to_eth_address(:public_key_point);
    Result::Ok(calculated_eth_address)
}

pub fn eth_address_from_public_key(
    public_key_bytes: ByteArray,
) -> Result<EthAddress, felt252> {

    let mut parser = ParserTrait::new(public_key_bytes);
    
    // skip the first byte
    parser.next(1);

    // get the next 32 bytes - x coordinate
    let x = parser.parse_u256();

    // get the following 32 bytes - y coordinate
    let y = parser.parse_u256();


    // Now you can use (x, y) in your existing flow
    let mut serialized_coordinates = array![];
    (x, y).serialize(ref serialized_coordinates);
    let mut serialized_coordinates = serialized_coordinates.span();
    let point = Serde::<Secp256k1Point>::deserialize(ref serialized_coordinates);
    if point.is_none() {
        return Result::Err('Invalid public key');
    }

    // Convert the point to an EthAddress
    Result::Ok(public_key_point_to_eth_address(point.unwrap()))
}