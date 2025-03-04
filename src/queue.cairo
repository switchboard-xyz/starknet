use core::starknet::ContractAddress;

// Queue / Switchboard Subnet
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Queue {
    // The ID of the queue (hexified pubkey)
    pub queue_id: u256,
    // The queue authority
    pub authority: ContractAddress,
    // The queue name
    pub name: felt252,
    // The update fee
    pub fee: u256,
    // The fee recipient
    pub fee_recipient: ContractAddress,
    // The min number of attestations needed to form a valid attestations
    pub min_attestations: u64,
    // The tolerated timestamp delta for attestation messages
    pub tolerated_timestamp_delta: u64,
    // The max number of attestations that can be in the queue
    pub oracle_validity_length: u64,
    // The last time the queue oracles were overridden
    pub last_queue_override: u64,
    // The guardian queue 
    pub guardian_queue_id: u256,
}

// Create Queue Params
#[derive(Copy, Drop, Serde)]
pub struct CreateQueueParams {
    pub queue_id: u256,
    pub authority: ContractAddress,
    pub name: felt252,
    pub fee: u256,
    pub fee_recipient: ContractAddress,
    pub min_attestations: u64,
    pub tolerated_timestamp_delta: u64,
    pub oracle_validity_length: u64,
    pub guardian_queue_id: u256,
}

// Update Queue Params
#[derive(Copy, Drop, Serde)]
pub struct UpdateQueueParams {
    pub queue_id: u256,
    pub name: felt252,
    pub fee: u256,
    pub fee_recipient: ContractAddress,
    pub min_attestations: u64,
    pub tolerated_timestamp_delta: u64,
    pub oracle_validity_length: u64,
    pub guardian_queue_id: u256,
}

// Set Queue Authority Params
#[derive(Copy, Drop, Serde)]
pub struct SetQueueAuthorityParams {
    pub queue_id: u256,
    pub authority: ContractAddress,
}

#[generate_trait]
pub(crate) impl QueueImpl of QueueTrait {
    // Create a new queue
    fn new(params: CreateQueueParams) -> Queue {
        Queue {
            queue_id: params.queue_id,
            authority: params.authority,
            name: params.name,
            fee: params.fee,
            fee_recipient: params.fee_recipient,
            min_attestations: params.min_attestations,
            tolerated_timestamp_delta: params.tolerated_timestamp_delta,
            oracle_validity_length: params.oracle_validity_length,
            last_queue_override: 0,
            guardian_queue_id: params.guardian_queue_id,
        }
    }

    // Update a queue
    fn update(ref self: Queue, params: UpdateQueueParams) {
        self.name = params.name;
        self.fee = params.fee;
        self.fee_recipient = params.fee_recipient;
        self.min_attestations = params.min_attestations;
        self.tolerated_timestamp_delta = params.tolerated_timestamp_delta;
        self.oracle_validity_length = params.oracle_validity_length;
        self.guardian_queue_id = params.guardian_queue_id;
    }

    // Set the queue authority
    fn set_authority(ref self: Queue, params: SetQueueAuthorityParams) {
        self.authority = params.authority;
    }
}
