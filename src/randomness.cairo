use core::starknet::{get_block_timestamp, ContractAddress, EthAddress};

// Randomness
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Randomness {
    // The ID of the randomness message
    pub randomness_id: u256,
    // The ID of the queue that the message is for - hexified queue pubkey from SOL
    pub queue_id: u256,
    // Time when the message was created
    pub created_at: u64,
    // The authority that the message is from
    pub authority: ContractAddress,
    // The block number of the message
    pub roll_timestamp: u256,
    // The minimum settlement delay
    pub min_settlement_delay: u64,
    // The result of the randomness message
    pub result: RandomnessResult,
}

// RandomnessResult
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct RandomnessResult {
    // The oracle id
    pub oracle_id: u256,
    // The authority of the oracle that provided the randomness
    pub oracle_authority: EthAddress,
    // The value of the randomness
    pub value: u256,
    // The time the randomness was settled
    pub settled_at: u64,
}

pub impl DefaultRandomnessResult of Default<RandomnessResult> {
    fn default() -> RandomnessResult {
        RandomnessResult {
            oracle_id: 0,
            oracle_authority: 0x0000000000000000000000000000000000000000_u256.try_into().unwrap(),
            value: 0,
            settled_at: 0,
        }
    }
}

// Create Randomness Params
#[derive(Copy, Drop, Serde)]
pub struct CreateRandomnessParams {
    pub randomness_id: u256,
    pub queue_id: u256,
    pub authority: ContractAddress,
    pub min_settlement_delay: u64,
}

// Update Randomness Params
#[derive(Copy, Drop, Serde)]
pub struct UpdateRandomnessParams {
    pub randomness_id: u256,
    pub min_settlement_delay: u64,
}

// Commit Randomness External Params
#[derive(Copy, Drop, Serde)]
pub struct CommitRandomnessExternalParams {
    pub randomness_id: u256,
    pub oracle_id: u256,
}

// Commit Randomness Params
#[derive(Copy, Drop, Serde)]
pub struct CommitRandomnessParams {
    pub randomness_id: u256,
    pub oracle_id: u256,
    pub oracle_authority: EthAddress,
}

#[generate_trait]
pub(crate) impl RandomnessImpl of RandomnessTrait {

    // Create a new randomness message
    fn new(params: CreateRandomnessParams) -> Randomness {
        Randomness {
            randomness_id: params.randomness_id,
            queue_id: params.queue_id,
            created_at: get_block_timestamp(),
            authority: params.authority,
            roll_timestamp: 0,
            min_settlement_delay: params.min_settlement_delay,
            result: RandomnessResult {
                oracle_id: 0,
                oracle_authority: 0x0000000000000000000000000000000000000000_u256.try_into().unwrap(),
                value: 0,
                settled_at: 0,
            },
        }
    }
    
    // Commit a randomness message
    fn commit(ref self: Randomness, params: CommitRandomnessParams) {
        self.result.oracle_authority = params.oracle_authority;
        self.result.oracle_id = params.oracle_id;
        self.roll_timestamp = get_block_timestamp().into();
    }

    // Update a randomness message
    fn update(ref self: Randomness, params: UpdateRandomnessParams) {
        self.min_settlement_delay = params.min_settlement_delay;
    }

    // Set the authority of a randomness message
    fn set_authority(ref self: Randomness, authority: ContractAddress) {
        self.authority = authority;
    }
}

