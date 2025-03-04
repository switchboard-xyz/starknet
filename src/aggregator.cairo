use starknet::ContractAddress;
use starknet::get_block_timestamp;
use starknet::storage::{
    StoragePointerReadAccess, StoragePointerWriteAccess, Vec, MutableVecTrait, StoragePath, Mutable,
};
use core::dict::Felt252Dict;
use crate::sort::MergeSort;
// use core::num::traits::Sqrt; // unused while stdev is disabled

// An Oracle Update
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Update {
    pub oracle_id: u256,
    pub result: i128,
    pub timestamp: u64,
}

// The current result of a feed
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct CurrentResult {
    pub result: i128,
    pub min_timestamp: u64,
    pub max_timestamp: u64,
    pub min_result: i128,
    pub max_result: i128,
    pub stdev: u128,
    pub range: i128,
    pub mean: i128,
}

// Aggregator - a Switchboard feed 
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Aggregator {
    pub aggregator_id: felt252,
    pub authority: ContractAddress,
    pub name: felt252,
    pub queue_id: u256,
    pub tolerated_delta: u64,
    pub feed_hash: u256,
    pub created_at: u64,
    pub max_variance: u64,
    pub min_responses: u32,
    pub min_samples: u8,
    pub max_staleness: u64,
    pub current_result: CurrentResult,
    pub update_idx: u64,
}

// Create Aggregator Params
#[derive(Copy, Drop, Serde)]
pub struct CreateAggregatorParams {
    pub aggregator_id: felt252,
    pub authority: ContractAddress,
    pub name: felt252,
    pub queue_id: u256,
    pub tolerated_delta: u64,
    pub feed_hash: u256,
    pub max_variance: u64,
    pub min_responses: u32,
    pub min_samples: u8,
    pub max_staleness: u64,
}

// Set Aggregator Params
#[derive(Copy, Drop, Serde)]
pub struct UpdateAggregatorParams {
    pub aggregator_id: felt252,
    pub name: felt252,
    pub tolerated_delta: u64,
    pub feed_hash: u256,
    pub max_variance: u64,
    pub min_responses: u32,
    pub min_samples: u8,
    pub max_staleness: u64,
}

// Set Aggregator Authority Params
#[derive(Copy, Drop, Serde)]
pub struct SetAggregatorAuthorityParams {
    pub aggregator_id: felt252,
    pub authority: ContractAddress,
}

// Aggregator functions
#[generate_trait]
pub impl AggregatorImpl of AggregatorTrait {
    // Create a new aggregator
    fn new(params: CreateAggregatorParams) -> Aggregator {
        Aggregator {
            aggregator_id: params.aggregator_id,
            authority: params.authority,
            name: params.name,
            queue_id: params.queue_id,
            tolerated_delta: params.tolerated_delta,
            feed_hash: params.feed_hash,
            created_at: get_block_timestamp(),
            max_variance: params.max_variance,
            min_responses: params.min_responses,
            min_samples: params.min_samples,
            max_staleness: params.max_staleness,
            current_result: CurrentResult {
                result: 0,
                min_timestamp: 0,
                max_timestamp: 0,
                min_result: 0,
                max_result: 0,
                stdev: 0,
                range: 0,
                mean: 0,
            },
            update_idx: 0,
        }
    }

    // Update the aggregator
    fn update(ref self: Aggregator, params: UpdateAggregatorParams) {
        self.name = params.name;
        self.tolerated_delta = params.tolerated_delta;
        self.feed_hash = params.feed_hash;
        self.max_variance = params.max_variance;
        self.min_responses = params.min_responses;
        self.min_samples = params.min_samples;
        self.max_staleness = params.max_staleness;
    }

    // Set the aggregator authority
    fn set_authority(ref self: Aggregator, params: SetAggregatorAuthorityParams) {
        self.authority = params.authority;
    }
}

// Trait to make it easier to work with storage for updates (e.g. adding updates, getting valid updates, etc.)
#[generate_trait]
pub(crate) impl UpdateResults of UpdateResultsTrait {

    // Add an update to results with the current update index
    fn add(mut self: StoragePath<Mutable<Vec<Update>>>, idx: u64, value: Update) -> (u64, bool) {
        let mut idx = idx;
        let mut exit = false;

        // Check if the update is older than the latest update
        for i in 0..self.len() {
            let update_i = self.at(i);
            if update_i.timestamp.read() > value.timestamp.into() {
                exit = true;
                break;
            } else if update_i.timestamp.read() == value.timestamp.into() && update_i.oracle_id.read() == value.oracle_id.into() {
                exit = true;
                break;
            }
        };

        // If the update is invalid, exit
        if exit {
            return (idx, false);
        }

        // If the updates array is not full, add the update
        if self.len() < 16 {
            if idx.into() < self.len() {
                // Overwrite at idx
                let mut override = self.at(idx.into());
                override.write(value);
            } else {
                // Append the value
                self.append().write(value);
            }
            idx = (idx + 1) % 16;
            return (idx, true);
        }

        // If the updates array is full, add the update at the correct index
        let mut curr = self.at(idx.into());
        curr.write(value);

        idx = (idx + 1) % 16;

        // Return the new index
        return (idx, true);
    }

    // Get the current result
    fn current_result(self: StoragePath<Mutable<Vec<Update>>>, valid_updates: Array<Update>) -> CurrentResult {
    
        // sort the results
        let results = MergeSort::sort(valid_updates.span());

        // get the median result
        let median = results.at(results.len() / 2);

        // calculate the stats
        let mut sum = 0;
        let mut min_result = results.at(0).result;
        let mut max_result = results.at(0).result;
        let mut min_timestamp = results.at(0).timestamp;
        let mut max_timestamp = results.at(0).timestamp;

        for i in 0..results.len() {
            let result = results.at(i).result;
            sum = sum + *result;
            if result < min_result {
                min_result = result;
            }
            if result > max_result {
                max_result = result;
            }
            if results.at(i).timestamp < min_timestamp {
                min_timestamp = results.at(i).timestamp;
            }
            if results.at(i).timestamp > max_timestamp {
                max_timestamp = results.at(i).timestamp;
            }
        };

        let mean = sum / results.len().into();

        // Temporarily disable stdev calculation - use one update with new oracle flow.
        // let mut sum_squared_diffs = 0;
        // for i in 0..results.len() {
        //     let diff = *results.at(i).result - mean;
        //     sum_squared_diffs = sum_squared_diffs + diff * diff;
        // };
        // let variance: u128 = (sum_squared_diffs / results.len().into()).try_into().unwrap();
        // let stdev: u128 = variance.sqrt().into();

        let range: i128 = *max_result - *min_result;

        let stdev = 0;

        CurrentResult {
            result: *median.result,
            min_timestamp: *min_timestamp,
            max_timestamp: *max_timestamp,
            min_result: *min_result,
            max_result: *max_result,
            stdev: stdev,
            range: range,
            mean: mean,
        }
    }

    // Pull valid updates for a set of results
    fn get_valid_updates(
        self: StoragePath<Mutable<Vec<Update>>>, 
        timestamp: u64,
        max_staleness_seconds: u64
    ) -> Array<Update> {
        let mut valid_updates = ArrayTrait::<Update>::new();
        let mut oracles_seen: Felt252Dict<bool> = Default::default();
        for i in 0..self.len() {
            let update_i = self.at(i);

            // there's a really low chance that 2 oracle id's match here on low bytes (without being the same oracle)
            // and it's not the biggest deal if a value gets ignored in that edge-case
            let seen = oracles_seen.get(update_i.oracle_id.read().low.into());
            if !seen {
                if update_i.timestamp.read() >= timestamp - max_staleness_seconds {
                    oracles_seen.insert(update_i.oracle_id.read().low.into(), true);
                    valid_updates.append(update_i.read());
                }
            }
        };

        return valid_updates;
    }
    
}

// for sorting updates
impl PartialOrdUpdate of PartialOrd<Update> {
    #[inline(always)]
    fn le(lhs: Update, rhs: Update) -> bool {
        !(rhs.result < lhs.result)
    }
    #[inline(always)]
    fn ge(lhs: Update, rhs: Update) -> bool {
        !(lhs.result < rhs.result)
    }
    #[inline(always)]
    fn lt(lhs: Update, rhs: Update) -> bool {
        lhs.result < rhs.result
    }
    #[inline(always)]
    fn gt(lhs: Update, rhs: Update) -> bool {
        rhs.result < lhs.result
    }
}