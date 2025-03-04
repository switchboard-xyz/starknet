<div align="center">
  <a href="#">
    <img src="https://github.com/switchboard-xyz/sbv2-core/raw/main/website/static/img/icons/switchboard/avatar.png" />
  </a>

  <h1>Switchboard On-Demand on Starknet</h1>

  <p>Switchboard is a multi-chain, permissionless oracle protocol allowing developers to fully control how data is relayed on-chain to their smart contracts.</p>

  <div>
    <a href="https://discord.gg/switchboardxyz">
      <img alt="Discord" src="https://img.shields.io/discord/841525135311634443?color=blueviolet&logo=discord&logoColor=white" />
    </a>
    <a href="https://twitter.com/switchboardxyz">
      <img alt="Twitter" src="https://img.shields.io/twitter/follow/switchboardxyz?label=Follow+Switchboard" />
    </a>
  </div>

  <h4>
    <strong>Documentation: </strong><a href="https://docs.switchboard.xyz">docs.switchboard.xyz</a>
  </h4>
</div>

## Active Deployments

The Switchboard On-Demand service is currently deployed on the following networks:

- Mainnet: [0x068cc3c8e1d1ae4683ee7844454a11bc32ae0aa6188f268d73f7fff8004be68d](https://starkscan.co/contract/0x068cc3c8e1d1ae4683ee7844454a11bc32ae0aa6188f268d73f7fff8004be68d)
- Testnet: [0x02d880dd4a1fb6f61fc13b1ea767187b9b85f97460a2997abb537fb100cbc439](https://sepolia.starkscan.co/contract/0x02d880dd4a1fb6f61fc13b1ea767187b9b85f97460a2997abb537fb100cbc439)

Check out the [example contract](./examples/price_feed/) to see how to create a price feed using Switchboard On-Demand.

## Typescript-SDK Installation

To use Switchboard On-Demand, add the following dependencies to your project:

### NPM

```bash
npm install @switchboard-xyz/starknet-sdk --save
```

### Bun

```bash
bun add @switchboard-xyz/starknet-sdk
```

### PNPM

```bash
pnpm add @switchboard-xyz/starknet-sdk
```

## Creating an Aggregator and Sending Transactions

Building a feed in Switchboard can be done using the Typescript SDK, or it can be done with the [Switchboard Web App](https://ondemand.switchboard.xyz/starknet/mainnet). Visit our [docs](https://docs.switchboard.xyz/docs) for more on designing and creating feeds.

### Building Feeds

```typescript
import {
  SwitchboardClient,
  Aggregator,
  STARKNET_TESTNET_QUEUE,
  STARKNET_MAINNET_QUEUE,
} from "@switchboard-xyz/starknet-sdk";

export async function create_feed() {
  // .. initialize wallet or starknet account ..
  const client = new SwitchboardClient(wallet_account);

  const params = {
    authority: wallet_account.address,
    name: "EXAMPLE/USD",
    queueId: STARKNET_TESTNET_QUEUE, // or STARKNET_MAINNET_QUEUE
    toleratedDelta: 100,
    maxStaleness: 100,
    feedHash,
    maxVariance: 5e9,
    minResponses: 1,
    minSamples: 1, // required to be 1 for Starknet
  };

  const aggregator = await Aggregator.init(client, params);

  console.log("Feed created!", await aggregator.loadData());

  return aggregator;
}

create_feed();
```

## Adding Switchboard to Cairo Code

To integrate Switchboard with Cairo, add the following dependencies to Cairo.toml:

```toml
switchboard = { git = "https://github.com/switchboard-xyz/starknet.git" }
```

## Example Cairo Code for Using Switchboard Values

In the module, use the latest result function to read the latest data for a feed.

```rust
#[starknet::interface]
pub trait IBtcFeedContract<T> {
    fn update(
        ref self: T, update_data: ByteArray
    );
}

#[starknet::contract]
mod example_contract {
    use core::{ByteArray, panic_with_felt252};
    use starknet::{ContractAddress, get_block_timestamp};

    // @dev Import the Switchboard dispatcher and the Switchboard dispatcher trait.
    use switchboard::{ISwitchboardDispatcher, ISwitchboardDispatcherTrait};

    // Storage for the Switchboard contract addresss, the BTC Feed ID, and the BTC price.
    #[storage]
    struct Storage {
        switchboard_address: ContractAddress, // <--- Switchboard contract address
        btc_feed_id: felt252, // <--- Feed ID
        btc_price: i128,
    }

    // Constructor to initialize the contract storage.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        switchboard_address: ContractAddress, >
        btc_feed_id: felt252
    ) {
        self.switchboard_address.write(switchboard_address);
        self.btc_feed_id.write(btc_feed_id);
    }

    #[abi(embed_v0)]
    impl BtcFeedContract of super::IBtcFeedContract<ContractState> {
        fn update(
            ref self: ContractState,
            update_data: ByteArray // <--- Update data to be passed to the Switchboard contract
        ) {
            let switchboard = ISwitchboardDispatcher { contract_address: self.switchboard_address.read() };

            // Update the price feed data
            switchboard.update_feed_data(update_data);

            // Read the fresh price feed
            let btc_price = switchboard.latest_result(self.btc_feed_id.read());

            // Check the age of the update - if it is older than 60 seconds, panic
            if (btc_price.max_timestamp < get_block_timestamp() - 60) {
                panic_with_felt252('Price feed is too old');
            }

            // write the price to storage
            self.btc_price.write(btc_price.result);
        }
    }
}
```

This implementation allows you to read and utilize Switchboard data feeds within Cairo. If you have any questions or need further assistance, please contact the Switchboard team.

**DISCLAIMER: ORACLE CODE AND CORE LOGIC ARE AUDITED - THE AUDIT FOR THIS ON-CHAIN ADAPTER IS PENDING**
