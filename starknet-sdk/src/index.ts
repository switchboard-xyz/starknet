import { ABI as switchboardABI } from "./abi";

import { TTLCache } from "@brokerloop/ttlcache";
import type { Queue as SolanaQueue } from "@switchboard-xyz/on-demand";
import {
  getDefaultQueue,
  getDefaultDevnetQueue,
  ON_DEMAND_DEVNET_GUARDIAN_QUEUE as SWITCHBOARD_DEVNET_GUARDIAN_QUEUE,
  ON_DEMAND_DEVNET_QUEUE as SWITCHBOARD_DEVNET_QUEUE,
  ON_DEMAND_MAINNET_GUARDIAN_QUEUE as SWITCHBOARD_MAINNET_GUARDIAN_QUEUE,
  ON_DEMAND_MAINNET_QUEUE as SWITCHBOARD_MAINNET_QUEUE,
} from "@switchboard-xyz/on-demand";
import type {
  AccountInterface,
  BigNumberish,
  ByteArray,
  ProviderInterface,
  Uint256,
} from "starknet";
import { cairo, Contract, num, uint256 } from "starknet";

export * from "./aggregator";
export * from "./randomness";
export * from "./queue";

// 5 min solana queue cache - reloads the sol program every 5 minutes max
export const solanaQueueCache = new TTLCache<string, SolanaQueue>({
  ttl: 1000 * 60 * 5,
});

// Switchboard Contract Addresses
export const STARKNET_MAINNET_ADDRESS: string =
  "0x068cc3c8e1d1ae4683ee7844454a11bc32ae0aa6188f268d73f7fff8004be68d";
export const STARKNET_TESTNET_ADDRESS: string =
  "0x02d880dd4a1fb6f61fc13b1ea767187b9b85f97460a2997abb537fb100cbc439";

// Switchboard Oracle Queue Addresses
export const STARKNET_MAINNET_QUEUE = bufferToUint256(
  SWITCHBOARD_MAINNET_QUEUE.toBuffer()
);
export const STARKNET_TESTNET_QUEUE = bufferToUint256(
  SWITCHBOARD_DEVNET_QUEUE.toBuffer()
);

// Switchboard Guardian Queue Addresses
export const STARKNET_MAINNET_GUARDIAN_QUEUE = bufferToUint256(
  SWITCHBOARD_MAINNET_GUARDIAN_QUEUE.toBuffer()
);
export const STARKNET_TESTNET_GUARDIAN_QUEUE = bufferToUint256(
  SWITCHBOARD_DEVNET_GUARDIAN_QUEUE.toBuffer()
);

// Get the default Solana queue
export async function loadSolanaQueue(
  mainnet: boolean,
  solanaRPC?: string
): Promise<SolanaQueue> {
  const queueKey = mainnet
    ? SWITCHBOARD_MAINNET_QUEUE.toBase58()
    : SWITCHBOARD_DEVNET_QUEUE.toBase58();
  const cachedQueue = solanaQueueCache.get(queueKey);
  if (cachedQueue) {
    return cachedQueue;
  } else {
    const queue = mainnet
      ? await getDefaultQueue(solanaRPC)
      : await getDefaultDevnetQueue(solanaRPC);
    solanaQueueCache.set(queueKey, queue);
    return queue;
  }
}

/**
 * Get the Switchboard contract instance (typed)
 * @param switchboardAddress The address of the Switchboard contract
 * @param accountOrProvider The account to use for the contract
 * @returns The Switchboard contract instance
 */
export async function getSwitchboardContract(
  switchboardAddress: string,
  accountOrProvider: ProviderInterface | AccountInterface
) {
  return new Contract(
    switchboardABI,
    switchboardAddress,
    accountOrProvider
  ).typedv2(switchboardABI);
}

/**
 * Convert a buffer to a cairo uint256
 * @param buf The buffer to convert
 * @returns the cairo uint256
 */
export function bufferToUint256(buf: Buffer): Uint256 {
  return hexToUint256(buf.toString("hex"));
}

/**
 * Conver a hex string to a cairo uint256
 * @param hex The hex string to convert
 * @returns the cairo uint256
 */
export function hexToUint256(hex: string): Uint256 {
  return cairo.uint256(num.hexToDecimalString(hex));
}

// The current state of the Switchboard client
export interface State {
  switchboardAddress: string;
  oracleQueue: Uint256;
  guardianQueue: Uint256;
  contract: Awaited<ReturnType<typeof getSwitchboardContract>>;
}

/**
 * Load the state of the Switchboard client
 * @param providerOrAccount The provider or account to use
 * @returns The state of the Switchboard client
 */
export async function loadState(
  providerOrAccount: ProviderInterface | AccountInterface,
  options?: CommonOptions
): Promise<State> {
  const isMainnet =
    (await providerOrAccount.getChainId()) === "0x534e5f4d41494e";
  const oracleQueueAddress = isMainnet
    ? STARKNET_MAINNET_QUEUE
    : STARKNET_TESTNET_QUEUE;
  const guardianQueueAddress = isMainnet
    ? STARKNET_MAINNET_GUARDIAN_QUEUE
    : STARKNET_TESTNET_GUARDIAN_QUEUE;
  const switchboardAddress = isMainnet
    ? STARKNET_MAINNET_ADDRESS
    : STARKNET_TESTNET_ADDRESS;

  const result = {
    switchboardAddress: options?.switchboardAddress ?? switchboardAddress,
    oracleQueue: options?.oracleQueue ?? oracleQueueAddress,
    guardianQueue: options?.guardianQueue ?? guardianQueueAddress,
    contract:
      options?.contract ??
      (await getSwitchboardContract(switchboardAddress, providerOrAccount)),
  };

  // connect the wallet or provider to the contract
  result.contract.connect(providerOrAccount);

  return result;
}

export type CommonOptions = Partial<State>;

/**
 * The Switchboard client
 * @dev This client is used to interact with the Switchboard contract
 * @dev If a provider without an account is passed, the client will be read-only
 */
export class SwitchboardClient {
  state: Promise<State>;

  /**
   * Create a new Switchboard client
   * @param providerOrAccount The provider or account to use
   */
  constructor(
    readonly providerOrAccount: ProviderInterface | AccountInterface
  ) {
    this.state = loadState(providerOrAccount);
  }

  /**
   * Fetch the current state of the Switchboard client
   * @param options Override the default state
   * @param retries Number of retries to fetch the state
   * @returns
   */
  async fetchState(
    options?: CommonOptions,
    retries: number = 3
  ): Promise<State> {
    try {
      if (options) {
        return await loadState(this.providerOrAccount, options);
      } else {
        return await this.state;
      }
    } catch {
      if (retries <= 0) {
        throw new Error(
          "Failed to fetch Switchboard state after multiple attempts"
        );
      }
      return this.fetchState(options, retries - 1);
    }
  }
}

export type SnakeToCamelCase<S extends string> =
  S extends `${infer T}_${infer U}${infer Rest}`
    ? `${T}${Uppercase<U>}${SnakeToCamelCase<Rest>}`
    : S;

export type SnakeToCamel<T> = {
  [K in keyof T as SnakeToCamelCase<string & K>]: T[K];
};

/**
 * Convert a string from camelCase to snake_case
 * @param str The string to convert
 * @returns The converted string
 */
export function camelToSnakeCase(str: string): string {
  return str.replace(/([A-Z])/g, (letter) => `_${letter.toLowerCase()}`);
}

/**
 * Generate a random 31 byte hex string (62 chars)
 * @returns The random hex string with 0x prefix
 */
export function randomId(): string {
  return `0x${[...Array(62)]
    .map(() => Math.floor(Math.random() * 16).toString(16))
    .join("")}`;
}

/**
 * Convert a number | bigint | Uint256 to a hex string
 * @param value The value to convert
 * @returns The hex string
 */
export function convertNumericToHex(value: number | bigint | Uint256): string {
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) {
      throw new Error("Number value is not a safe integer");
    }
    return value.toString(16);
  } else if (typeof value === "bigint") {
    return value.toString(16);
  } else if (typeof value === "object") {
    return uint256.uint256ToBN(value).toString(16);
  } else {
    throw new Error(`Unsupported type for conversion: ${typeof value}`);
  }
}

/**
 * Split a long string into 62 character strings
 * @param longStr The long string to split
 * @returns The split strings
 */
export function splitLongString(longStr: string): string[] {
  const regex = RegExp(`[^]{1,62}`, "g");
  return longStr.match(regex) || [];
}

/**
 * Create a Cairo ByteArray from a hex string
 * @param hex The hex string to convert
 * @returns The Cairo ByteArray
 */
export function byteArrayFromHex(hex: string): ByteArray {
  const slice = hex.slice(2);
  const shortStrings: string[] = splitLongString(slice);
  const remainder: string = shortStrings[shortStrings.length - 1];
  const encodedStrings: BigNumberish[] =
    shortStrings.map((str) => "0x" + str) || [];
  const [pendingWord, pendingWordLength] =
    remainder === undefined || remainder.length === 62
      ? ["0x00", 0]
      : [encodedStrings.pop()!, remainder.length];

  return {
    data: encodedStrings.length === 0 ? [] : encodedStrings,
    pending_word: pendingWord,
    pending_word_len: Math.round(pendingWordLength / 2),
  };
}

export function trimHexPrefix(hex: string): string {
  return hex.startsWith("0x") ? hex.slice(2) : hex;
}
