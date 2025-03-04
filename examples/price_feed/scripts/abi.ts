export const ABI = [
  {
    type: "impl",
    name: "BtcFeedContract",
    interface_name: "btc_feed::IBtcFeedContract",
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
    type: "interface",
    name: "btc_feed::IBtcFeedContract",
    items: [
      {
        type: "function",
        name: "update",
        inputs: [
          {
            name: "update_data",
            type: "core::byte_array::ByteArray",
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
    inputs: [
      {
        name: "switchboard_address",
        type: "core::starknet::contract_address::ContractAddress",
      },
      {
        name: "btc_feed_id",
        type: "core::felt252",
      },
    ],
  },
  {
    type: "event",
    name: "btc_feed::example_contract::Event",
    kind: "enum",
    variants: [],
  },
] as const;
