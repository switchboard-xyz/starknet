use core::starknet::EthAddress;
use starknet::get_block_timestamp;
use starknet::storage::{
    StoragePointerReadAccess, StoragePointerWriteAccess, Vec, MutableVecTrait, StoragePath, Mutable,
};
use core::dict::Felt252Dict;

// Oracle
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Oracle {
    // The oracle authority
    pub authority: EthAddress,
    // The oracle ID
    pub oracle_id: u256,
    // The queue ID
    pub queue_id: u256,
    // The mrEnclave of the oracle
    pub mr_enclave: u256,
    // The expiration time of the oracle
    pub expiration_time: u64,
    // The fees owed by the oracle
    pub fees_owed: u64,
}

// Attestation
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Attestation {
    // The authority that the message is from
    pub oracle_authority: EthAddress,
    // The attestee
    pub oracle_id: u256,
    // The ID of the queue that the message is for - hexified queue pubkey from SOL
    pub queue_id: u256,
    // The mrEnclave of the oracle
    pub mr_enclave: u256,
    // The timestamp of the message
    pub timestamp: u64,
}

pub impl AttestationDefaultImpl of Default<Attestation> {
    fn default() -> Attestation {
        Attestation {
            oracle_authority: 0x0000000000000000000000000000000000000000_u256.try_into().unwrap(),
            oracle_id: 0,
            queue_id: 0,
            mr_enclave: 0,
            timestamp: 0,
        }
    }
}


// Trait to make it easier to work with Attestations in storage
#[generate_trait]
pub(crate) impl AttestationImpl of AttestationTrait {

    // Add an Attestation to the AttestationResults - return true if it forms a valid quorum
    fn add(
        mut self: StoragePath<Mutable<Vec<Attestation>>>,
        new_attestation: Attestation, 
        min_attestations: u64,
        tolerated_timestamp_delta: u64,
    ) -> bool {

        // check if the new attestation is valid
        let new_update_valid = new_attestation.timestamp > get_block_timestamp() - tolerated_timestamp_delta;
        if !new_update_valid {
            return false;
        }
    
        // loop through the attestations in the vec, check that each is valid
        // if we see an attestation from the same oracle as new_attestation, we replace it
        // if we see an invalid attestation, we remove it
        // then at the end count the number of valid attestations
        let mut valid_updates = ArrayTrait::<Attestation>::new();
        let mut oracles_seen: Felt252Dict<bool> = Default::default();

        let mut added = false;
        let mut insert_index = 0;
        let mut oldest_timestamp = get_block_timestamp();
        let authority = new_attestation.oracle_authority;

        for i in 0..self.len() {
            let attestation = self.at(i);
            if attestation.timestamp.read() < oldest_timestamp {
                oldest_timestamp = attestation.timestamp.read();
                insert_index = i;
            }

            if attestation.oracle_id.read() == new_attestation.oracle_id {
                // replace the attestation
                oracles_seen.insert(new_attestation.oracle_id.low.into(), true);
                let mut override = self.at(i);
                override.write(new_attestation);
                added = true;
            } else if attestation.timestamp.read() > get_block_timestamp() - tolerated_timestamp_delta && attestation.oracle_authority.read() == authority {
                // keep the attestation if it matches the authority and is within the timestamp delta
                valid_updates.append(attestation.read());
                oracles_seen.insert(attestation.oracle_id.low.read().into(), true);
            } else if attestation.timestamp.read() > get_block_timestamp() - tolerated_timestamp_delta {
                // remove the attestation
                let mut override = self.at(i);
                let default: Attestation = Default::default();
                override.write(default);
            }
        };

        // if we haven't added the new attestation, add it
        if !added && !oracles_seen.get(new_attestation.oracle_id.low.into()) {
            valid_updates.append(new_attestation);
            oracles_seen.insert(new_attestation.oracle_id.low.into(), true);
            self.append().write(new_attestation);
        }

        return valid_updates.len().into() >= min_attestations;
    }

    // Clear the Attestation Results Vector
    fn clear(mut self: StoragePath<Mutable<Vec<Attestation>>>) {
        for i in 0..self.len() {
            let mut attestation = self.at(i);
            let default: Attestation = Default::default();
            attestation.write(default);
        }
    }

}