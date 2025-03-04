pub mod signature;
pub mod message;
pub mod aggregator;
pub mod randomness;
pub mod oracle;
pub mod queue;
pub mod sort;

use starknet::{ ContractAddress, ClassHash };
use core::byte_array::{ ByteArray };
use aggregator::{ Aggregator, AggregatorTrait, CurrentResult, Update, UpdateResultsTrait, CreateAggregatorParams, UpdateAggregatorParams, SetAggregatorAuthorityParams };
use queue::{ Queue, QueueTrait, CreateQueueParams, UpdateQueueParams, SetQueueAuthorityParams };
use oracle::{ Oracle, Attestation, AttestationTrait };
use randomness::{ Randomness, RandomnessTrait, CreateRandomnessParams, UpdateRandomnessParams, CommitRandomnessExternalParams, CommitRandomnessParams };
use signature::eth_address_from_public_key;

// Interface definition for the Switchboard contract
#[starknet::interface]
pub trait ISwitchboard<T> {
    // Switchboard Functions 
    fn latest_result(self: @T, aggregator_id: felt252) -> CurrentResult;
    fn update_feed_data(ref self: T, bytes: ByteArray);

    // Aggregator Functions
    fn get_aggregator(self: @T, aggregator_id: felt252) -> Aggregator;
    fn get_all_aggregators(self: @T) -> Span<Aggregator>;
    fn create_aggregator(ref self: T, params: CreateAggregatorParams);
    fn update_aggregator(ref self: T, params: UpdateAggregatorParams);
    fn set_aggregator_authority(ref self: T, params: SetAggregatorAuthorityParams);

    // Queue Functions
    fn get_queue(ref self: T, queue_id: u256) -> (Queue, Span<Oracle>);
    fn get_all_queues(self: @T) -> Span<(Queue, Span<Oracle>)>;
    fn create_queue(ref self: T, params: CreateQueueParams);
    fn update_queue(ref self: T, params: UpdateQueueParams);
    fn set_queue_authority(ref self: T, params: SetQueueAuthorityParams);
    fn override_queue_oracles(ref self: T, queue_id: u256, oracles: Span<Oracle>);

    // Randomness Functions
    fn get_randomness(self: @T, randomness_id: u256) -> Randomness;
    fn get_all_randomness(self: @T) -> Span<Randomness>;
    fn create_randomness(ref self: T, params: CreateRandomnessParams);
    fn update_randomness(ref self: T, params: UpdateRandomnessParams);
    fn commit_randomness(ref self: T, params: CommitRandomnessExternalParams);

    // Admin 
    fn upgrade_contract(ref self: T, new_class_hash: ClassHash);
    fn set_owner(ref self: T, owner: ContractAddress);
}

// Switchboard Contract
#[starknet::contract]
mod switchboard {
    use starknet::event::EventEmitter;
    use core::starknet::{
        ContractAddress, EthAddress, get_caller_address, ClassHash, SyscallResultTrait, get_block_timestamp, contract_address_const,
        storage::{ StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map, Vec, VecTrait, MutableVecTrait },
        syscalls::replace_class_syscall,
    };
    use super::{
        message::{
            parse_message,
            ToHashPayloadUpdateMessage, 
            ToHashPayloadAttestationMessage,  
            ToHashPayloadRandomnessMessage,
            Verifiable, 
            Message,
            UpdateMessage,
            AttestationMessage,
            RandomnessMessage,
        },
        Aggregator, AggregatorTrait, CurrentResult, Update, UpdateResultsTrait, CreateAggregatorParams,
        UpdateAggregatorParams, SetAggregatorAuthorityParams,
        Queue, QueueTrait, CreateQueueParams, UpdateQueueParams, SetQueueAuthorityParams,
        Oracle, Attestation, AttestationTrait,
        Randomness, RandomnessTrait, CreateRandomnessParams, UpdateRandomnessParams, CommitRandomnessExternalParams, CommitRandomnessParams,
        eth_address_from_public_key,
    };
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    // Event definitions

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct OwnerUpdated {
        pub owner: ContractAddress,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct ContractUpgraded {
        pub new_class_hash: ClassHash,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct InvalidSecpSignature {
        pub message: felt252,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct InvalidSecpAuthority {
        pub expected: EthAddress,
        pub actual: EthAddress,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct InvalidQueue {
        pub queue_id: u256,
        pub oracle_id: u256,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct OracleExpired {
        pub oracle_id: u256,
        pub expiration_time: u64,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct NotEnoughResponses {
        pub aggregator_id: felt252,
        pub valid_responses: u32,
        pub min_responses: u32,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct AddedUpdate {
        pub aggregator_id: felt252,
        pub oracle_id: u256,
        pub timestamp: u64,
        pub result: i128,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct QuorumNotReached {
        pub queue_id: u256,
        pub oracle_id: u256,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct OracleAdded {
        pub queue_id: u256,
        pub oracle_id: u256,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct InvalidSecpPublicKey {
        pub secp256k1_key: ByteArray,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct RandomnessAlreadySettled {
        pub randomness_id: u256,
        pub settled_at: u64,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct RandomnessTooEarly {
        pub randomness_id: u256,
        pub roll_timestamp: u256,
        pub min_settlement_delay: u64,
    }

    #[derive(Drop, Clone, Debug, PartialEq, Serde, starknet::Event)]
    pub struct RandomnessResolved {
        pub randomness_id: u256,
        pub value: u256,
        pub settled_at: u64,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnerUpdated: OwnerUpdated,
        ContractUpgraded: ContractUpgraded,
        InvalidSecpSignature: InvalidSecpSignature,
        InvalidSecpAuthority: InvalidSecpAuthority,
        InvalidQueue: InvalidQueue,
        OracleExpired: OracleExpired,
        NotEnoughResponses: NotEnoughResponses,
        AddedUpdate: AddedUpdate,
        QuorumNotReached: QuorumNotReached,
        OracleAdded: OracleAdded,
        InvalidSecpPublicKey: InvalidSecpPublicKey,
        RandomnessAlreadySettled: RandomnessAlreadySettled,
        RandomnessTooEarly: RandomnessTooEarly,
        RandomnessResolved: RandomnessResolved,
    }
    
    // Switchboard State
    #[storage]
    pub struct Storage {
        pub(crate) owner: ContractAddress,

        // Aggregator Storage
        pub(crate) aggregator_ids: Vec<felt252>,
        pub(crate) aggregators: Map<felt252, Aggregator>, // Aggregator Id -> Aggregator
        pub(crate) update_results: Map<felt252, Vec<Update>>, // Aggregator Id -> Update Results

        // Queue Storage
        pub(crate) queue_ids: Vec<u256>,
        pub(crate) queues: Map<u256, Queue>, // Queue Id -> Queue
        pub(crate) queue_state: Map<u256, Vec<u256>>, // Queue Id -> Oracle Ids

        // Oracle Storage
        pub(crate) oracle_ids: Vec<u256>,
        pub(crate) oracles: Map<u256, Map<u256, Oracle>>, // Queue Id -> Oracle Id -> Oracle
        pub(crate) oracle_authorities: Map<u256, Map<EthAddress, u256>>, // Queue Id -> Oracle Authority -> Oracle Id
        pub(crate) oracle_attestations: Map<u256, Map<u256, Vec<Attestation>>>, // Queue Id -> Oracle Id -> Attestations

        // Randomness Storage
        pub(crate) randomness_ids: Vec<u256>,
        pub(crate) randomness: Map<u256, Randomness>, // Randomness Id -> Randomness
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.owner.write(get_caller_address());
    }

    #[abi(embed_v0)]
    pub impl SwitchboardImpl of super::ISwitchboard<ContractState> {

        // Switchboard Functions
        fn latest_result(self: @ContractState, aggregator_id: felt252) -> CurrentResult {
            let aggregator = self.aggregators.read(aggregator_id);
            aggregator.current_result
        }

        fn update_feed_data(ref self: ContractState, bytes: ByteArray) {
            let message = parse_message(bytes);
            match message {
                Message::UpdateMessage(message) => {
                    self.handle_update_message(message);
                },
                Message::AttestationMessage(message) => {
                    self.handle_attestation_message(message);
                },
                Message::RandomnessMessage(message) => {
                    self.handle_randomness_message(message);
                },
                _ => {
                    panic!("Invalid Message Discriminator");
                },
            }
        }

        // Aggregator Functions

        fn get_aggregator(self: @ContractState, aggregator_id: felt252) -> Aggregator {
            let aggregator = self.aggregators.read(aggregator_id);
            aggregator
        }

        fn get_all_aggregators(self: @ContractState) -> Span<Aggregator> {
            let mut aggregators: Array<Aggregator> = ArrayTrait::new();
            for i in 0..self.aggregator_ids.len() {
                aggregators.append(self.aggregators.read(self.aggregator_ids.at(i).read()));
            };
            aggregators.span()
        }

        fn create_aggregator(ref self: ContractState, params: CreateAggregatorParams) {
            let aggregator = AggregatorTrait::new(params);

            // check that the aggregator doesn't already exist
            assert(self.aggregators.read(params.aggregator_id).aggregator_id == Default::default(), 'Aggregator already exists');
            self.aggregators.write(params.aggregator_id, aggregator);
            self.aggregator_ids.append().write(params.aggregator_id);
        }

        fn update_aggregator(ref self: ContractState, params: UpdateAggregatorParams) {
            let mut aggregator = self.aggregators.read(params.aggregator_id);
            assert(aggregator.authority == get_caller_address(), 'Invalid Authority');
            aggregator.update(params);
            self.aggregators.write(params.aggregator_id, aggregator);
        }

        fn set_aggregator_authority(ref self: ContractState, params: SetAggregatorAuthorityParams) {
            let mut aggregator = self.aggregators.read(params.aggregator_id);
            assert(aggregator.authority == get_caller_address(), 'Invalid Authority');
            aggregator.set_authority(params);
            self.aggregators.write(params.aggregator_id, aggregator);
        }

        // Queue Functions

        fn get_queue(ref self: ContractState, queue_id: u256) -> (Queue, Span<Oracle>) {
            let queue = self.queues.read(queue_id);
            let oracle_ids = self.queue_state.entry(queue_id);
            let mut oracle_list: Array<Oracle> = ArrayTrait::new();
            for i in 0..oracle_ids.len() {
                if oracle_ids.at(i).read() == Default::default() {
                    continue;
                }
                oracle_list.append(self.oracles.entry(queue_id).read(oracle_ids.at(i).read()));
            };
            (queue, oracle_list.span())
        }

        fn get_all_queues(self: @ContractState) -> Span<(Queue, Span<Oracle>)> {
            let mut queues: Array<(Queue, Span<Oracle>)> = ArrayTrait::new();
            for i in 0..self.queue_ids.len() {
                let queue_id = self.queue_ids.at(i).read();
                let queue = self.queues.read(queue_id);
                let oracle_ids = self.queue_state.entry(queue_id);
                let mut oracle_list: Array<Oracle> = ArrayTrait::new();
                for j in 0..oracle_ids.len() {
                    if oracle_ids.at(j).read() == Default::default() {
                        continue;
                    }
                    oracle_list.append(self.oracles.entry(queue_id).read(oracle_ids.at(j).read()));
                };
                queues.append((queue, oracle_list.span()));
            };
            queues.span()
        }

        fn create_queue(ref self: ContractState, params: CreateQueueParams) {
            let queue = QueueTrait::new(params);
            // ensure the queue doesn't already exist
            assert(self.queues.read(params.queue_id).queue_id == Default::default(), 'Queue already exists');
            self.queues.write(params.queue_id, queue);
            self.queue_ids.append().write(params.queue_id);
        }

        fn update_queue(ref self: ContractState, params: UpdateQueueParams) {
            let mut queue = self.queues.read(params.queue_id);
            assert(queue.authority == get_caller_address(), 'Invalid Authority');
            queue.update(params);
            self.queues.write(params.queue_id, queue);
        }

        fn set_queue_authority(ref self: ContractState, params: SetQueueAuthorityParams) {
            let mut queue = self.queues.read(params.queue_id);
            assert(queue.authority == get_caller_address(), 'Invalid Authority');
            queue.set_authority(params);
            self.queues.write(params.queue_id, queue);
        }

        fn override_queue_oracles(ref self: ContractState, queue_id: u256, oracles: Span<Oracle>) {
            let queue = self.queues.read(queue_id);
            assert(queue.authority == get_caller_address(), 'Invalid Authority');

            // get the queue oracle state
            let mut oracle_ids = self.queue_state.entry(queue_id);

            // keep track if the current oracle list is greater than the new oracle list (true deletions in Vec aren't possible, so we default them)
            let remove_overflow = oracle_ids.len() > oracles.len().into();

            // add the oracles to the queue
            if oracle_ids.len() < oracles.len().into() {
                for i in 0..oracles.len() {
                    assert(oracles.at(i).queue_id == @queue_id, 'Oracle does not belong to queue');
                    let oracle = *oracles.at(i);
                    self.oracle_authorities.entry(queue_id).write(oracle.authority, oracle.oracle_id);
                    // if the index already exists in the oracle_ids, update the oracle
                    if i.into() < oracle_ids.len() {
                        let mut oracle_id = oracle_ids.at(i.into());
                        oracle_id.write(oracle.oracle_id);
                        let mut oracle_entry = self.oracles.entry(queue_id).entry(oracle.oracle_id);
                        oracle_entry.write(oracle);
                    } 
                    // if the index is new, append it to the end
                    else {
                        let oracle_entry = self.oracles.entry(queue_id).entry(oracle.oracle_id);
                        oracle_entry.write(oracle);
                        oracle_ids.append().write(oracle.oracle_id);
                    };
                };
            }

            // if there are leftover original oracles, default them
            if remove_overflow {
                for i in oracles.len().into()..oracle_ids.len() {
                    let mut oracle_id = oracle_ids.at(i);
                    oracle_id.write(Default::default());
                };
            }
        }

        // Randomness Functions

        fn get_randomness(self: @ContractState, randomness_id: u256) -> Randomness {
            let randomness = self.randomness.read(randomness_id);
            randomness
        }

        fn get_all_randomness(self: @ContractState) -> Span<Randomness> {
            let mut randomness: Array<Randomness> = ArrayTrait::new();
            for i in 0..self.randomness_ids.len() {
                randomness.append(self.randomness.read(self.randomness_ids.at(i).read()));
            };
            randomness.span()
        }

        fn create_randomness(ref self: ContractState, params: CreateRandomnessParams) {
            let mut randomness = RandomnessTrait::new(params);

            // set the specific authority that can resolve the randomness
            self.randomness.write(params.randomness_id, randomness);
            self.randomness_ids.append().write(params.randomness_id);
        }

        fn commit_randomness(ref self: ContractState, params: CommitRandomnessExternalParams) {
            let mut randomness = self.randomness.read(params.randomness_id);
            assert(randomness.authority == get_caller_address(), 'Invalid Authority');

            let oracle = self.oracles.entry(randomness.queue_id).read(params.oracle_id);
            let internal_params = CommitRandomnessParams {
                randomness_id: params.randomness_id,
                oracle_id: params.oracle_id,
                oracle_authority: oracle.authority,
            };
            randomness.commit(internal_params);
            self.randomness.write(params.randomness_id, randomness);
        }

        fn update_randomness(ref self: ContractState, params: UpdateRandomnessParams) {
            let mut randomness = self.randomness.read(params.randomness_id);
            assert(randomness.authority == get_caller_address(), 'Invalid Authority');
            randomness.update(params);
            self.randomness.write(params.randomness_id, randomness);
        }

        // Admin functions

        fn upgrade_contract(ref self: ContractState, new_class_hash: ClassHash) {
            assert(self.owner.read() == get_caller_address(), 'Invalid Authority');
            replace_class_syscall(new_class_hash).unwrap_syscall();
            self.emit(ContractUpgraded { new_class_hash });
        }

        fn set_owner(ref self: ContractState, owner: ContractAddress) {
            assert(self.owner.read() == get_caller_address(), 'Invalid Authority');
            self.owner.write(owner);
            self.emit(OwnerUpdated { owner });
        }
    }

     // Internal helper functions for handling messages
    #[generate_trait]
    impl HandleMessages of MessageHandlerTrait {
        

        // Handle update message
        fn handle_update_message(ref self: ContractState, message: UpdateMessage) {
            let mut aggregator = self.aggregators.read(message.aggregator_id);
            assert(message.timestamp != 0, 'Invalid Timestamp Zero');
            let payload = message.to_hash_payload(
                aggregator.queue_id,
                aggregator.feed_hash,
                aggregator.max_variance,
                aggregator.min_responses,
            );

            let oracle_signer_address = payload.recover_address();
            if oracle_signer_address.is_err() {
                self.emit(InvalidSecpSignature {
                    message: 'Update Recover Failure'
                });
                return;
            }
            
            let oracle_id = self.oracle_authorities.entry(aggregator.queue_id).read(oracle_signer_address.unwrap());
            let oracle = self.oracles.entry(aggregator.queue_id).read(oracle_id);
            
            // check that oracle is in the queue and is valid
            if oracle.oracle_id == Default::default() {
                self.emit(InvalidSecpSignature {
                    message: 'Oracle Not Found'
                });
                return;
            }

            if oracle.authority != oracle_signer_address.unwrap() {
                self.emit(InvalidSecpAuthority { expected: oracle.authority, actual: oracle_signer_address.unwrap() });
                return;
            }
            if oracle.queue_id != aggregator.queue_id {
                self.emit(InvalidQueue { queue_id: aggregator.queue_id, oracle_id: oracle_id });
                return;
            }
            if oracle.expiration_time < get_block_timestamp() {
                self.emit(OracleExpired { oracle_id: oracle_id, expiration_time: oracle.expiration_time });
                return;
            }

            // check that oracle is on the queue
            let mut is_on_queue = false;
            for i in 0..self.queue_state.entry(aggregator.queue_id).len() {
                if self.queue_state.entry(aggregator.queue_id).at(i).read() == oracle_id {
                    is_on_queue = true;
                    break;
                }
            };

            if !is_on_queue {
                self.emit(InvalidQueue { queue_id: aggregator.queue_id, oracle_id: oracle_id });
                return;
            }

            let mut update_results = self.update_results.entry(message.aggregator_id);
            let update = Update {
                oracle_id: oracle_id,
                result: message.result,
                timestamp: message.timestamp,
            };
            
            let (update_idx, added) = update_results.add(aggregator.update_idx, update);

            if added {

                // get the valid updates
                let valid_updates = update_results.get_valid_updates(
                    get_block_timestamp(), 
                    aggregator.max_staleness
                );

                if valid_updates.len() < aggregator.min_samples.into() {
                    self.emit(NotEnoughResponses { aggregator_id: message.aggregator_id, valid_responses: valid_updates.len().into(), min_responses: aggregator.min_samples.into() });
                    return;
                }

                aggregator.update_idx = update_idx;
                aggregator.current_result = update_results.current_result(valid_updates);

                // write the aggregator back to storage
                self.aggregators.write(message.aggregator_id, aggregator); 

                // handle payment
                let queue_data = self.queues.read(aggregator.queue_id);
                let fee = queue_data.fee;
                if fee > 0 {
                    handle_fee(
                        get_caller_address(), // transfer from the caller
                        self.owner.read(),    // transfer to the fee collector
                        contract_address_const::<0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d>(), // starknet STRK token
                        fee, // amount
                    );
                }

            } else {
                self.emit(AddedUpdate { aggregator_id: message.aggregator_id, oracle_id: oracle_id, timestamp: message.timestamp, result: message.result });
            }
        }

        // Handle attestation message
        fn handle_attestation_message(ref self: ContractState, message: AttestationMessage) {
            
            // grab queues
            let oracle_queue = self.queues.read(message.queue_id);
            let guardian_queue = self.queues.read(oracle_queue.guardian_queue_id);


            let guardian = self.oracles.entry(guardian_queue.guardian_queue_id).read(message.guardian_id);
            let payload = message.to_hash_payload();
            let guardian_signer_address = payload.recover_address();

            // check that the message is valid
            if guardian_signer_address.is_err() {
                // Todo: update this event to something better
                self.emit(InvalidSecpSignature {
                    message: 'Attestation Recover Failure'
                });
                return;
            }

            // check that oracle is on the queue and is valid
            if guardian.oracle_id == Default::default() {
                // Todo: update this event to something better
                self.emit(InvalidSecpSignature {
                    message: 'Guardian Not Found'
                });
                return;
            }

            // check that the guardian is the authority
            if guardian.authority == guardian_signer_address.unwrap() {
                self.emit(InvalidSecpAuthority { expected: guardian.authority, actual: guardian_signer_address.unwrap() });
                return;
            }

            // check that guardian is on the queue
            let mut is_on_queue = false;
            for i in 0..self.queue_state.entry(guardian_queue.queue_id).len() {
                if self.queue_state.entry(guardian_queue.queue_id).at(i).read() == guardian.oracle_id {
                    is_on_queue = true;
                    break;
                }
            };

            if !is_on_queue {
                self.emit(InvalidQueue { queue_id: guardian_queue.queue_id, oracle_id: guardian.oracle_id });
                return;
            }
            
            let oracle_authority = eth_address_from_public_key(message.secp256k1_key.clone()); // todo: clean up cloning
            if oracle_authority.is_err() {
                self.emit(InvalidSecpPublicKey { secp256k1_key: message.secp256k1_key });
                return;
            }
            let oracle_authority = oracle_authority.unwrap();

            // Now add attestation to the oracle
            let mut attestation_results = self.oracle_attestations.entry(message.queue_id).entry(message.oracle_id);
            let attestation = Attestation {
                oracle_authority: oracle_authority,
                oracle_id: message.guardian_id,
                queue_id: message.queue_id,
                mr_enclave: message.mr_enclave,
                timestamp: message.timestamp,
            };

            // add the attestation
            let valid_quorum = attestation_results.add(attestation, oracle_queue.min_attestations, oracle_queue.tolerated_timestamp_delta);
            if valid_quorum {

                // upsert the oracle in the oracle_authorities map
                let mut oracle_entry = self.oracles.entry(message.queue_id).entry(message.oracle_id);
                let existing_oracle = oracle_entry.read();

                // write the oracle to the oracle_authorities map
                self.oracle_authorities.entry(message.queue_id).write(oracle_authority, message.oracle_id);

                // create the oracle
                let oracle = Oracle {
                    authority: oracle_authority,
                    oracle_id: message.oracle_id,
                    queue_id: oracle_queue.queue_id,
                    mr_enclave: message.mr_enclave,
                    expiration_time: get_block_timestamp() + oracle_queue.oracle_validity_length,
                    fees_owed: existing_oracle.fees_owed,
                };

                // write the oracle back to storage
                oracle_entry.write(oracle);
                
                // consume the attestation_results
                attestation_results.clear();
                self.emit(OracleAdded { queue_id: message.queue_id, oracle_id: message.oracle_id });
                
            } else {
                self.emit(QuorumNotReached { queue_id: message.queue_id, oracle_id: message.oracle_id });
            }
        }

        // Handle randomness message
        fn handle_randomness_message(ref self: ContractState, message: RandomnessMessage) {
            let mut randomness = self.randomness.read(message.randomness_id);
            let payload = message.to_hash_payload(randomness.min_settlement_delay);
            let oracle_signer_address = payload.recover_address();
            if oracle_signer_address.is_err() {
                self.emit(InvalidSecpSignature {
                    message: 'Randomness Recover Failure'
                });
                return;
            }
            
            // check that the oracle is the authority
            if oracle_signer_address.unwrap() != randomness.result.oracle_authority {
                // emit InvalidAuthority log
                self.emit(InvalidSecpAuthority { expected: randomness.result.oracle_authority, actual: oracle_signer_address.unwrap() });
                return;
            }

            // check that the randomness is not already settled
            if randomness.result.settled_at != 0 {
                // emit RandomnessAlreadySettled log
                self.emit(RandomnessAlreadySettled { randomness_id: message.randomness_id, settled_at: randomness.result.settled_at });
                return;
            }

            // check that the randomness is not too early
            if get_block_timestamp().into() < randomness.roll_timestamp + randomness.min_settlement_delay.into() {
                // emit RandomnessTooEarly log
                self.emit(RandomnessTooEarly { randomness_id: message.randomness_id, roll_timestamp: randomness.roll_timestamp, min_settlement_delay: randomness.min_settlement_delay });
                return;
            }
            
            // write the result to the randomness
            let mut result = randomness.result;
            result.value = message.result;
            result.settled_at = get_block_timestamp();
            randomness.result = result;

            // write the randomness back to storage
            self.randomness.write(message.randomness_id, randomness);

            // emit RandomnessResolved log
            self.emit(RandomnessResolved { randomness_id: message.randomness_id, value: message.result, settled_at: get_block_timestamp() });
        }
    }

    // Helper function to handle fees for updates
    fn handle_fee(
        user: ContractAddress,
        fee_collector: ContractAddress,
        token: ContractAddress,
        fee: u256,
    ) -> bool {
        let erc20 = IERC20Dispatcher { contract_address: token };
        if erc20.balance_of(user) < fee {
            return false;
        }
        if erc20.allowance(user, fee_collector) < fee {
            return false;
        }
        if !erc20.transfer_from(user, fee_collector, fee) {
            return false;
        }
        true
    }
}
