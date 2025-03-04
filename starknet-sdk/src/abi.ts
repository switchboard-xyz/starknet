export const ABI = [
  {
    type: "impl",
    name: "SwitchboardImpl",
    interface_name: "switchboard::ISwitchboard",
  },
  {
    type: "struct",
    name: "switchboard::aggregator::CurrentResult",
    members: [
      {
        name: "result",
        type: "core::integer::i128",
      },
      {
        name: "min_timestamp",
        type: "core::integer::u64",
      },
      {
        name: "max_timestamp",
        type: "core::integer::u64",
      },
      {
        name: "min_result",
        type: "core::integer::i128",
      },
      {
        name: "max_result",
        type: "core::integer::i128",
      },
      {
        name: "stdev",
        type: "core::integer::u128",
      },
      {
        name: "range",
        type: "core::integer::i128",
      },
      {
        name: "mean",
        type: "core::integer::i128",
      },
    ],
  },
  {
    type: "struct",
    name: "core::byte_array::ByteArray",
    members: [
      {
        name: "data",
        type: "core::array::Array::<core::bytes_31::bytes31>",
      },
      {
        name: "pending_word",
        type: "core::felt252",
      },
      {
        name: "pending_word_len",
        type: "core::integer::u32",
      },
    ],
  },
  {
    type: "struct",
    name: "core::integer::u256",
    members: [
      {
        name: "low",
        type: "core::integer::u128",
      },
      {
        name: "high",
        type: "core::integer::u128",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::aggregator::Aggregator",
    members: [
      {
        name: "aggregator_id",
        type: "core::felt252",
      },
      {
        name: "authority",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "name",
        type: "core::felt252",
      },
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "tolerated_delta",
        type: "core::integer::u64",
      },
      {
        name: "feed_hash",
        type: "core::integer::u256",
      },
      {
        name: "created_at",
        type: "core::integer::u64",
      },
      {
        name: "max_variance",
        type: "core::integer::u64",
      },
      {
        name: "min_responses",
        type: "core::integer::u32",
      },
      {
        name: "min_samples",
        type: "core::integer::u8",
      },
      {
        name: "max_staleness",
        type: "core::integer::u64",
      },
      {
        name: "current_result",
        type: "switchboard::aggregator::CurrentResult",
      },
      {
        name: "update_idx",
        type: "core::integer::u64",
      },
    ],
  },
  {
    type: "struct",
    name: "core::array::Span::<switchboard::aggregator::Aggregator>",
    members: [
      {
        name: "snapshot",
        type: "@core::array::Array::<switchboard::aggregator::Aggregator>",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::aggregator::CreateAggregatorParams",
    members: [
      {
        name: "aggregator_id",
        type: "core::felt252",
      },
      {
        name: "authority",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "name",
        type: "core::felt252",
      },
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "tolerated_delta",
        type: "core::integer::u64",
      },
      {
        name: "feed_hash",
        type: "core::integer::u256",
      },
      {
        name: "max_variance",
        type: "core::integer::u64",
      },
      {
        name: "min_responses",
        type: "core::integer::u32",
      },
      {
        name: "min_samples",
        type: "core::integer::u8",
      },
      {
        name: "max_staleness",
        type: "core::integer::u64",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::aggregator::UpdateAggregatorParams",
    members: [
      {
        name: "aggregator_id",
        type: "core::felt252",
      },
      {
        name: "name",
        type: "core::felt252",
      },
      {
        name: "tolerated_delta",
        type: "core::integer::u64",
      },
      {
        name: "feed_hash",
        type: "core::integer::u256",
      },
      {
        name: "max_variance",
        type: "core::integer::u64",
      },
      {
        name: "min_responses",
        type: "core::integer::u32",
      },
      {
        name: "min_samples",
        type: "core::integer::u8",
      },
      {
        name: "max_staleness",
        type: "core::integer::u64",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::aggregator::SetAggregatorAuthorityParams",
    members: [
      {
        name: "aggregator_id",
        type: "core::felt252",
      },
      {
        name: "authority",
        type: "core::starknet::contract_address::ContractAddress",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::queue::Queue",
    members: [
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "authority",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "name",
        type: "core::felt252",
      },
      {
        name: "fee",
        type: "core::integer::u256",
      },
      {
        name: "fee_recipient",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "min_attestations",
        type: "core::integer::u64",
      },
      {
        name: "tolerated_timestamp_delta",
        type: "core::integer::u64",
      },
      {
        name: "oracle_validity_length",
        type: "core::integer::u64",
      },
      {
        name: "last_queue_override",
        type: "core::integer::u64",
      },
      {
        name: "guardian_queue_id",
        type: "core::integer::u256",
      },
    ],
  },
  {
    type: "struct",
    name: "core::starknet::eth_address::EthAddress",
    members: [
      {
        name: "address",
        type: "core::felt252",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::oracle::Oracle",
    members: [
      {
        name: "authority",
        type: "core::starknet::eth_address::EthAddress",
      },
      {
        name: "oracle_id",
        type: "core::integer::u256",
      },
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "mr_enclave",
        type: "core::integer::u256",
      },
      {
        name: "expiration_time",
        type: "core::integer::u64",
      },
      {
        name: "fees_owed",
        type: "core::integer::u64",
      },
    ],
  },
  {
    type: "struct",
    name: "core::array::Span::<switchboard::oracle::Oracle>",
    members: [
      {
        name: "snapshot",
        type: "@core::array::Array::<switchboard::oracle::Oracle>",
      },
    ],
  },
  {
    type: "struct",
    name: "core::array::Span::<(switchboard::queue::Queue, core::array::Span::<switchboard::oracle::Oracle>)>",
    members: [
      {
        name: "snapshot",
        type: "@core::array::Array::<(switchboard::queue::Queue, core::array::Span::<switchboard::oracle::Oracle>)>",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::queue::CreateQueueParams",
    members: [
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "authority",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "name",
        type: "core::felt252",
      },
      {
        name: "fee",
        type: "core::integer::u256",
      },
      {
        name: "fee_recipient",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "min_attestations",
        type: "core::integer::u64",
      },
      {
        name: "tolerated_timestamp_delta",
        type: "core::integer::u64",
      },
      {
        name: "oracle_validity_length",
        type: "core::integer::u64",
      },
      {
        name: "guardian_queue_id",
        type: "core::integer::u256",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::queue::UpdateQueueParams",
    members: [
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "name",
        type: "core::felt252",
      },
      {
        name: "fee",
        type: "core::integer::u256",
      },
      {
        name: "fee_recipient",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "min_attestations",
        type: "core::integer::u64",
      },
      {
        name: "tolerated_timestamp_delta",
        type: "core::integer::u64",
      },
      {
        name: "oracle_validity_length",
        type: "core::integer::u64",
      },
      {
        name: "guardian_queue_id",
        type: "core::integer::u256",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::queue::SetQueueAuthorityParams",
    members: [
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "authority",
        type: "core::starknet::contract_address::ContractAddress",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::randomness::RandomnessResult",
    members: [
      {
        name: "oracle_id",
        type: "core::integer::u256",
      },
      {
        name: "oracle_authority",
        type: "core::starknet::eth_address::EthAddress",
      },
      {
        name: "value",
        type: "core::integer::u256",
      },
      {
        name: "settled_at",
        type: "core::integer::u64",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::randomness::Randomness",
    members: [
      {
        name: "randomness_id",
        type: "core::integer::u256",
      },
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "created_at",
        type: "core::integer::u64",
      },
      {
        name: "authority",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "roll_timestamp",
        type: "core::integer::u256",
      },
      {
        name: "min_settlement_delay",
        type: "core::integer::u64",
      },
      {
        name: "result",
        type: "switchboard::randomness::RandomnessResult",
      },
    ],
  },
  {
    type: "struct",
    name: "core::array::Span::<switchboard::randomness::Randomness>",
    members: [
      {
        name: "snapshot",
        type: "@core::array::Array::<switchboard::randomness::Randomness>",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::randomness::CreateRandomnessParams",
    members: [
      {
        name: "randomness_id",
        type: "core::integer::u256",
      },
      {
        name: "queue_id",
        type: "core::integer::u256",
      },
      {
        name: "authority",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "min_settlement_delay",
        type: "core::integer::u64",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::randomness::UpdateRandomnessParams",
    members: [
      {
        name: "randomness_id",
        type: "core::integer::u256",
      },
      {
        name: "min_settlement_delay",
        type: "core::integer::u64",
      },
    ],
  },
  {
    type: "struct",
    name: "switchboard::randomness::CommitRandomnessExternalParams",
    members: [
      {
        name: "randomness_id",
        type: "core::integer::u256",
      },
      {
        name: "oracle_id",
        type: "core::integer::u256",
      },
    ],
  },
  {
    type: "interface",
    name: "switchboard::ISwitchboard",
    items: [
      {
        type: "function",
        name: "latest_result",
        inputs: [
          {
            name: "aggregator_id",
            type: "core::felt252",
          },
        ],
        outputs: [
          {
            type: "switchboard::aggregator::CurrentResult",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "update_feed_data",
        inputs: [
          {
            name: "bytes",
            type: "core::byte_array::ByteArray",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "get_aggregator",
        inputs: [
          {
            name: "aggregator_id",
            type: "core::felt252",
          },
        ],
        outputs: [
          {
            type: "switchboard::aggregator::Aggregator",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "get_all_aggregators",
        inputs: [],
        outputs: [
          {
            type: "core::array::Span::<switchboard::aggregator::Aggregator>",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "create_aggregator",
        inputs: [
          {
            name: "params",
            type: "switchboard::aggregator::CreateAggregatorParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "update_aggregator",
        inputs: [
          {
            name: "params",
            type: "switchboard::aggregator::UpdateAggregatorParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "set_aggregator_authority",
        inputs: [
          {
            name: "params",
            type: "switchboard::aggregator::SetAggregatorAuthorityParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "get_queue",
        inputs: [
          {
            name: "queue_id",
            type: "core::integer::u256",
          },
        ],
        outputs: [
          {
            type: "(switchboard::queue::Queue, core::array::Span::<switchboard::oracle::Oracle>)",
          },
        ],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "get_all_queues",
        inputs: [],
        outputs: [
          {
            type: "core::array::Span::<(switchboard::queue::Queue, core::array::Span::<switchboard::oracle::Oracle>)>",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "create_queue",
        inputs: [
          {
            name: "params",
            type: "switchboard::queue::CreateQueueParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "update_queue",
        inputs: [
          {
            name: "params",
            type: "switchboard::queue::UpdateQueueParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "set_queue_authority",
        inputs: [
          {
            name: "params",
            type: "switchboard::queue::SetQueueAuthorityParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "override_queue_oracles",
        inputs: [
          {
            name: "queue_id",
            type: "core::integer::u256",
          },
          {
            name: "oracles",
            type: "core::array::Span::<switchboard::oracle::Oracle>",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "get_randomness",
        inputs: [
          {
            name: "randomness_id",
            type: "core::integer::u256",
          },
        ],
        outputs: [
          {
            type: "switchboard::randomness::Randomness",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "get_all_randomness",
        inputs: [],
        outputs: [
          {
            type: "core::array::Span::<switchboard::randomness::Randomness>",
          },
        ],
        state_mutability: "view",
      },
      {
        type: "function",
        name: "create_randomness",
        inputs: [
          {
            name: "params",
            type: "switchboard::randomness::CreateRandomnessParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "update_randomness",
        inputs: [
          {
            name: "params",
            type: "switchboard::randomness::UpdateRandomnessParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "commit_randomness",
        inputs: [
          {
            name: "params",
            type: "switchboard::randomness::CommitRandomnessExternalParams",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "upgrade_contract",
        inputs: [
          {
            name: "new_class_hash",
            type: "core::starknet::class_hash::ClassHash",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
      {
        type: "function",
        name: "set_owner",
        inputs: [
          {
            name: "owner",
            type: "core::starknet::contract_address::ContractAddress",
          },
        ],
        outputs: [],
        state_mutability: "external",
      },
    ],
  },
  {
    type: "constructor",
    name: "constructor",
    inputs: [],
  },
  {
    type: "event",
    name: "switchboard::switchboard::OwnerUpdated",
    kind: "struct",
    members: [
      {
        name: "owner",
        type: "core::starknet::contract_address::ContractAddress",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::ContractUpgraded",
    kind: "struct",
    members: [
      {
        name: "new_class_hash",
        type: "core::starknet::class_hash::ClassHash",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::InvalidSecpSignature",
    kind: "struct",
    members: [
      {
        name: "message",
        type: "core::felt252",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::InvalidSecpAuthority",
    kind: "struct",
    members: [
      {
        name: "expected",
        type: "core::starknet::eth_address::EthAddress",
        kind: "data",
      },
      {
        name: "actual",
        type: "core::starknet::eth_address::EthAddress",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::InvalidQueue",
    kind: "struct",
    members: [
      {
        name: "queue_id",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "oracle_id",
        type: "core::integer::u256",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::OracleExpired",
    kind: "struct",
    members: [
      {
        name: "oracle_id",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "expiration_time",
        type: "core::integer::u64",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::NotEnoughResponses",
    kind: "struct",
    members: [
      {
        name: "aggregator_id",
        type: "core::felt252",
        kind: "data",
      },
      {
        name: "valid_responses",
        type: "core::integer::u32",
        kind: "data",
      },
      {
        name: "min_responses",
        type: "core::integer::u32",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::AddedUpdate",
    kind: "struct",
    members: [
      {
        name: "aggregator_id",
        type: "core::felt252",
        kind: "data",
      },
      {
        name: "oracle_id",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "timestamp",
        type: "core::integer::u64",
        kind: "data",
      },
      {
        name: "result",
        type: "core::integer::i128",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::QuorumNotReached",
    kind: "struct",
    members: [
      {
        name: "queue_id",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "oracle_id",
        type: "core::integer::u256",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::OracleAdded",
    kind: "struct",
    members: [
      {
        name: "queue_id",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "oracle_id",
        type: "core::integer::u256",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::InvalidSecpPublicKey",
    kind: "struct",
    members: [
      {
        name: "secp256k1_key",
        type: "core::byte_array::ByteArray",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::RandomnessAlreadySettled",
    kind: "struct",
    members: [
      {
        name: "randomness_id",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "settled_at",
        type: "core::integer::u64",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::RandomnessTooEarly",
    kind: "struct",
    members: [
      {
        name: "randomness_id",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "roll_timestamp",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "min_settlement_delay",
        type: "core::integer::u64",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::RandomnessResolved",
    kind: "struct",
    members: [
      {
        name: "randomness_id",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "value",
        type: "core::integer::u256",
        kind: "data",
      },
      {
        name: "settled_at",
        type: "core::integer::u64",
        kind: "data",
      },
    ],
  },
  {
    type: "event",
    name: "switchboard::switchboard::Event",
    kind: "enum",
    variants: [
      {
        name: "OwnerUpdated",
        type: "switchboard::switchboard::OwnerUpdated",
        kind: "nested",
      },
      {
        name: "ContractUpgraded",
        type: "switchboard::switchboard::ContractUpgraded",
        kind: "nested",
      },
      {
        name: "InvalidSecpSignature",
        type: "switchboard::switchboard::InvalidSecpSignature",
        kind: "nested",
      },
      {
        name: "InvalidSecpAuthority",
        type: "switchboard::switchboard::InvalidSecpAuthority",
        kind: "nested",
      },
      {
        name: "InvalidQueue",
        type: "switchboard::switchboard::InvalidQueue",
        kind: "nested",
      },
      {
        name: "OracleExpired",
        type: "switchboard::switchboard::OracleExpired",
        kind: "nested",
      },
      {
        name: "NotEnoughResponses",
        type: "switchboard::switchboard::NotEnoughResponses",
        kind: "nested",
      },
      {
        name: "AddedUpdate",
        type: "switchboard::switchboard::AddedUpdate",
        kind: "nested",
      },
      {
        name: "QuorumNotReached",
        type: "switchboard::switchboard::QuorumNotReached",
        kind: "nested",
      },
      {
        name: "OracleAdded",
        type: "switchboard::switchboard::OracleAdded",
        kind: "nested",
      },
      {
        name: "InvalidSecpPublicKey",
        type: "switchboard::switchboard::InvalidSecpPublicKey",
        kind: "nested",
      },
      {
        name: "RandomnessAlreadySettled",
        type: "switchboard::switchboard::RandomnessAlreadySettled",
        kind: "nested",
      },
      {
        name: "RandomnessTooEarly",
        type: "switchboard::switchboard::RandomnessTooEarly",
        kind: "nested",
      },
      {
        name: "RandomnessResolved",
        type: "switchboard::switchboard::RandomnessResolved",
        kind: "nested",
      },
    ],
  },
] as const;
