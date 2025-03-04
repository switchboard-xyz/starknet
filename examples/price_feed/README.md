# Price Feed Example

This example demonstrates how to create a price feed using Switchboard On-Demand.

## Installation

To build and deploy this example, you will need [Scarb 2.8.x](https://docs.swmansion.com/scarb/download) and [Starkli](https://github.com/xJonathanLEI/starkli). It also uses bun [(bun.sh)](https://bun.sh/docs/installation) for executing typescript scripts. You can then install and build the project by running the following command:

```bash
scarb build
```

## Deploy the Aggregator

Here's an example of a deploy command for the aggregator:

```bash
# starkli deploy --strk <class hash> <switchboard address> <feed id>

## Example deploy command
starkli deploy --strk 0x03f0a0b1394ce9926e1f7a840dc2b5de7b1878e6c2983737cb32641b03ad2d88 0x02d880dd4a1fb6f61fc13b1ea767187b9b85f97460a2997abb537fb100cbc439 0x2ad43ca59bbc79845a2e518c5a72a47981a97772f1955792b6931153c20d16

## Get the deployment address from output:
# ...
# Contract deployment transaction: 0x07481bfd7f13c204b3d9bbbdcee90c65aca3f66ea9bf3950431ed2c549554855
# Contract deployed:
# 0x07695d263aee489963d819c8e21e77e5cbf21490072564f89ca78d07721e03f6
```

## Update the Aggregator with the Latest Price

First, make sure to set the following environment variables:

- `PRIVATE_KEY` environment variable to the private key of the Starknet account you want to use
- `STARKNET_RPC` to the Starknet RPC URL
- `EXAMPLE_ADDRESS` to the address of the deployed contract
- `STARKNET_ACCOUNT` the file path to the Starknet account configured
- `FEED_ID` the feed id of the aggregator

### Getting your keys

To get the private key for a keystore generated with starkli, run:

```bash
starkli signer keystore inspect-private
```

### Executing update script

To update the aggregator with the latest price, you can use the following command:

```bash
bun run scripts/update.ts
```

If the transaction lands successfully, then the data feed is updated with a fresh price.
