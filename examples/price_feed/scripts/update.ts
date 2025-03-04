import {
  ProviderInterface,
  AccountInterface,
  Contract,
  RpcProvider,
  Account,
  constants,
  CallData,
} from "starknet";
import { ABI } from "./abi";
import { readFileSync } from "fs";
import { SwitchboardClient, Aggregator } from "@switchboard-xyz/starknet-sdk";

/**
 * Get the example contract instance (typed)
 * @param exampleAddress The address of the example contract
 * @param accountOrProvider The account to use for the contract
 * @returns The example contract instance
 */
async function getBtcFeedContract(
  exampleAddress: string,
  accountOrProvider: ProviderInterface | AccountInterface
) {
  return new Contract(ABI, exampleAddress, accountOrProvider).typedv2(ABI);
}

/**
 * Get the connection to the Starknet RPC
 * @param rpc The RPC URL
 * @returns The Starknet provider
 */
function connectToStarknet(rpc: string) {
  return new RpcProvider({
    nodeUrl: rpc,
  });
}

/**
 * Get the Starknet account
 * @param provider The Starknet provider
 * @returns The Starknet account
 */
function getWallet(provider: RpcProvider): Account {
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("PRIVATE_KEY not set");
  }

  const starknetAccountPath = process.env.STARKNET_ACCOUNT;
  if (!starknetAccountPath) {
    throw new Error("STARKNET_ACCOUNT not set");
  }

  // get the account address from the file at process.env.STARKNET_ACCOUNT
  const resultJSON = JSON.parse(readFileSync(starknetAccountPath).toString());
  const address = resultJSON.deployment.address;
  console.log(address);

  return new Account(
    provider,
    address,
    privateKey,
    undefined,
    constants.TRANSACTION_VERSION.V3
  );
}

function trimHexPrefix(hex: string) {
  return hex.startsWith("0x") ? hex.slice(2) : hex;
}

async function main() {
  const rpc = process.env.STARKNET_RPC;
  if (!rpc) {
    throw new Error("STARKNET_RPC not set");
  }
  const provider = connectToStarknet(rpc);
  const account = getWallet(provider);

  const exampleAddress = process.env.EXAMPLE_ADDRESS;
  if (!exampleAddress) {
    throw new Error("EXAMPLE_ADDRESS not set");
  }

  const feedId = process.env.FEED_ID;
  if (!feedId) {
    throw new Error("FEED_ID not set");
  }

  const contract = await getBtcFeedContract(exampleAddress, account);

  // @ts-ignore - circular type in kenobi types for some reason
  const sbc = new SwitchboardClient(account);

  // Connect to the aggregator
  const aggregator = new Aggregator(sbc, trimHexPrefix(feedId));

  // Fetch the update
  const { updates, responses } = await aggregator.fetchUpdate();

  console.log({ updates, responses });

  // Run the update
  const tx = await contract.update(CallData.compile(updates));
  console.log("Transaction hash:", tx.transaction_hash);
  await account.waitForTransaction(tx.transaction_hash);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
