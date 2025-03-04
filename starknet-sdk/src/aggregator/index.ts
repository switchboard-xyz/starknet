import type { CommonOptions, SnakeToCamel, SwitchboardClient } from "..";
import {
  byteArrayFromHex,
  convertNumericToHex,
  hexToUint256,
  loadSolanaQueue,
  randomId,
  STARKNET_MAINNET_ADDRESS,
  trimHexPrefix,
} from "..";

import { bs58, CrossbarClient, OracleJob } from "@switchboard-xyz/common";
import type { FeedEvalResponse } from "@switchboard-xyz/on-demand";
import { EVM } from "@switchboard-xyz/on-demand";
import type { BigNumberish, ByteArray, Uint256 } from "starknet";
import { CallData, num, shortString } from "starknet";

export type AggregatorSetAuthorityParams =
  SnakeToCamel<StarknetAggregatorSetAuthorityParams>;

export interface AggregatorInitParams extends CommonOptions {
  aggregatorId?: string;
  authority: string;
  name: string;
  toleratedDelta: number | bigint;
  maxStaleness: number | bigint;
  feedHash: string;
  maxVariance: number | bigint;
  minResponses: number | bigint;
  minSamples: number | bigint;
}

export interface AggregatorSetConfigsParams extends CommonOptions {
  aggregatorId: string;
  name: string;
  toleratedDelta: number | bigint;
  feedHash: string;
  maxVariance: number | bigint;
  minResponses: number | bigint;
  minSamples: number | bigint;
  maxStaleness: number | bigint;
}

export interface StarknetAggregatorInitParams extends CommonOptions {
  aggregator_id: BigNumberish;
  authority: string;
  name: BigNumberish;
  queue_id: number | bigint | Uint256;
  tolerated_delta: number | bigint;
  max_staleness: number | bigint;
  feed_hash: number | bigint | Uint256;
  max_variance: number | bigint;
  min_responses: number | bigint;
  min_samples: number | bigint;
}

export interface StarknetAggregatorSetAuthorityParams extends CommonOptions {
  aggregator_id: BigNumberish;
  authority: string;
}

export interface StarknetAggregatorSetConfigsParams extends CommonOptions {
  aggregator_id: BigNumberish;
  name: BigNumberish;
  tolerated_delta: number | bigint;
  feed_hash: number | bigint | Uint256;
  max_variance: number | bigint;
  min_responses: number | bigint;
  min_samples: number | bigint;
  max_staleness: number | bigint;
}

export interface AggregatorConfigs {
  feedHash: string;
  maxVariance: number;
  minResponses: number;
  minSampleSize: number;
}

export interface AggregatorFetchUpdateParams extends CommonOptions {
  gateway?: string;
  solanaRPCUrl?: string;
  crossbarUrl?: string;
  crossbarClient?: CrossbarClient;
  jobs?: OracleJob[];

  // If passed in, Aptos Aggregator load can be skipped
  feedConfigs?: AggregatorConfigs;
}

export interface FetchUpdateResponse {
  updates: ByteArray[];
  updatesHex: string[];
  responses: FeedEvalResponse[];
  failures: string[];
}

export interface CurrentResult {
  result: unknown;
  min_timestamp: number | bigint;
  max_timestamp: number | bigint;
  min_result: unknown;
  max_result: unknown;
  stdev: number | bigint;
  range: unknown;
  mean: unknown;
}

export interface AggregatorData {
  aggregator_id: BigNumberish;
  authority: string;
  name: BigNumberish;
  queue_id: number | bigint | Uint256;
  tolerated_delta: number | bigint;
  max_staleness: number | bigint;
  feed_hash: number | bigint | Uint256;
  max_variance: number | bigint;
  min_responses: number | bigint;
  min_samples: number | bigint;
  current_result: CurrentResult;
  update_idx: number | bigint;
}

export interface ReturnCurrentResult {
  result: number;
  minTimestamp: number;
  maxTimestamp: number;
  minResult: number;
  maxResult: number;
  stdev: number;
  range: number;
  mean: number;
}

export interface AggregatorReturnData {
  aggregatorId: string;
  authority: string;
  name: string;
  queueId: string;
  toleratedDelta: number;
  maxStaleness: number;
  feedHash: string;
  maxVariance: number;
  minResponses: number;
  minSamples: number;
  currentResult: ReturnCurrentResult;
  updateIdx: number;
}

export class Aggregator {
  public id: string;
  constructor(readonly sb: SwitchboardClient, id: string) {
    this.id = trimHexPrefix(id);
  }

  async fetchUpdate(
    options?: AggregatorFetchUpdateParams
  ): Promise<FetchUpdateResponse> {
    const crossbarClient = options?.crossbarUrl
      ? new CrossbarClient(options.crossbarUrl)
      : CrossbarClient.default();
    const state = await this.sb.fetchState();

    const data = await this.loadData();

    const isMainnet = state.switchboardAddress === STARKNET_MAINNET_ADDRESS;

    const queue = await loadSolanaQueue(isMainnet);

    // convert number | bigint | Uint256 to hex string
    const feedHash = data.feedHash;

    const feedConfigs = options?.feedConfigs ?? {
      feedHash,
      maxVariance: Number(data.maxVariance),
      minResponses: Number(data.minResponses),
      minSampleSize: Number(data.minSamples),
    };

    // fetch the jobs
    const jobs: OracleJob[] =
      options?.jobs ??
      (await crossbarClient
        .fetch(feedConfigs.feedHash)
        .then((res) => res.jobs.map((job) => OracleJob.fromObject(job))));

    // fetch the signatures
    const { responses, failures } = await queue.fetchSignatures({
      jobs,
      gateway: options?.gateway,

      // Make this more granular in the canonical fetch signatures (within @switchboard-xyz/on-demand)
      maxVariance: Math.floor(feedConfigs.maxVariance / 1e9),
      minResponses: feedConfigs.minResponses,
      numSignatures: feedConfigs.minSampleSize,

      // blockhash checks aren't yet available on starknet
      recentHash: bs58.encode(new Uint8Array(32)),
      useTimestamp: true,
    });

    // update strings to build the single update string
    const updates = [];

    // Sort the response by timestamp, ascending
    responses.sort((a, b) => (a.timestamp ?? 0) - (b.timestamp ?? 0));

    const feedId = this.id + "00"; // add a byte at the end to make it 32 bytes

    // add the responses
    for (const result of responses) {
      // Decode from Base64 to a Buffer
      const signatureBuffer = new Uint8Array(
        Buffer.from(result.signature, "base64")
      );

      // Assuming each component (r and s) is 32 bytes long
      const r = Buffer.from(signatureBuffer.slice(0, 32)).toString("hex");
      const s = Buffer.from(signatureBuffer.slice(32, 64)).toString("hex");
      const v = result.recovery_id;
      const timestamp = result.timestamp?.toString() ?? "0";
      const value = result.success_value.toString();
      const updateHexEncoded = EVM.message.createUpdateHexString({
        feedId,
        discriminator: 1,
        r,
        s,
        v,
        result: value,
        timestamp,
        blockNumber:
          "0x0000000000000000000000000000000000000000000000000000000000000000",
      });

      // add the update to the list
      updates.push(updateHexEncoded);
    }

    return {
      updates: updates.map((u) => byteArrayFromHex(u)),
      updatesHex: updates,
      responses,
      failures,
    };
  }

  /**
   * Crank an update on the aggregator
   */
  async submitUpdate(): Promise<{
    responses: FeedEvalResponse[];
    failures: string[];
  }> {
    const state = await this.sb.fetchState();
    const contract = state.contract;
    const { updates, responses, failures } = await this.fetchUpdate();
    const calldata = CallData.compile([...updates]);
    const update = await contract.update_feed_data(calldata);
    const receipt = await contract.providerOrAccount.waitForTransaction(
      update.transaction_hash
    );
    if (receipt.isError()) {
      throw new Error(
        `[Starknet Aggregator] Failed to submit update ${receipt.statusReceipt}`
      );
    }
    return { responses, failures };
  }

  /**
   * Create a new Aggregator
   * @param sb The Switchboard client
   * @param params The Aggregator init params
   * @returns The new Aggregator if successful
   */
  static async init(
    sb: SwitchboardClient,
    params: AggregatorInitParams
  ): Promise<Aggregator> {
    try {
      const state = await sb.fetchState(params);
      const contract = state.contract;

      const aggregatorId = params.aggregatorId ?? randomId();
      const queueId = state.oracleQueue;

      const starknetParams: StarknetAggregatorInitParams = {
        aggregator_id: num.hexToDecimalString(aggregatorId),
        authority: params.authority,
        name: params.name,
        queue_id: queueId,
        tolerated_delta: params.toleratedDelta,
        max_staleness: params.maxStaleness,
        feed_hash: hexToUint256(params.feedHash),
        max_variance: params.maxVariance,
        min_responses: params.minResponses,
        min_samples: params.minSamples,
      };

      const tx = await contract.create_aggregator(starknetParams);
      const receipt = await contract.providerOrAccount.waitForTransaction(
        tx.transaction_hash
      );
      if (receipt.isError()) {
        throw new Error(
          `[Starknet Aggregator] Failed to create aggregator ${receipt.statusReceipt}`
        );
      }
      return new Aggregator(sb, aggregatorId);
    } catch (e) {
      throw new Error(
        `[Starknet Aggregator] Failed to create aggregator: ${e}`
      );
    }
  }

  async setAuthority(params: AggregatorSetAuthorityParams): Promise<void> {
    const state = await this.sb.fetchState(params);
    const contract = state.contract;

    const starknetParams: StarknetAggregatorSetAuthorityParams = {
      aggregator_id: num.hexToDecimalString(this.id),
      authority: params.authority,
    };

    const tx = await contract.set_authority(starknetParams);
    const receipt = await contract.providerOrAccount.waitForTransaction(
      tx.transaction_hash
    );
    if (receipt.isError()) {
      throw new Error(
        `[Starknet Aggregator] Failed to set authority ${receipt.statusReceipt}`
      );
    }
  }

  async setConfigs(params: AggregatorSetConfigsParams): Promise<void> {
    const state = await this.sb.fetchState(params);
    const contract = state.contract;

    const starknetParams: StarknetAggregatorSetConfigsParams = {
      aggregator_id: num.hexToDecimalString(this.id),
      name: params.name,
      tolerated_delta: params.toleratedDelta,
      feed_hash: hexToUint256(params.feedHash),
      max_variance: params.maxVariance,
      min_responses: params.minResponses,
      min_samples: params.minSamples,
      max_staleness: params.maxStaleness,
    };

    const tx = await contract.update_aggregator(starknetParams);
    const receipt = await contract.providerOrAccount.waitForTransaction(
      tx.transaction_hash
    );
    if (receipt.isError()) {
      throw new Error(
        `[Starknet Aggregator] Failed to set configs ${receipt.statusReceipt}`
      );
    }
  }

  async loadData(): Promise<AggregatorReturnData> {
    const state = await this.sb.fetchState();
    const contract = state.contract;
    return starknetAggregatorDataToReturnData(
      await contract.get_aggregator(num.hexToDecimalString(this.id))
    );
  }

  static async loadAllAggregators(
    sb: SwitchboardClient
  ): Promise<AggregatorReturnData[]> {
    const state = await sb.fetchState();
    const contract = state.contract;
    return contract.get_all_aggregators().then((aggregators) => {
      return aggregators.map(starknetAggregatorDataToReturnData);
    });
  }
}

function starknetAggregatorDataToReturnData(
  data: AggregatorData
): AggregatorReturnData {
  const feedHash = convertNumericToHex(data.feed_hash);
  return {
    aggregatorId: data.aggregator_id.toString(),
    authority: data.authority,
    name: shortString.decodeShortString(data.name.toString()),
    queueId: data.queue_id.toString(),
    toleratedDelta: Number(data.tolerated_delta),
    maxStaleness: Number(data.max_staleness),
    feedHash,
    maxVariance: Number(data.max_variance),
    minResponses: Number(data.min_responses),
    minSamples: Number(data.min_samples),
    currentResult: {
      result: Number(data.current_result.result),
      minTimestamp: Number(data.current_result.min_timestamp),
      maxTimestamp: Number(data.current_result.max_timestamp),
      minResult: Number(data.current_result.min_result),
      maxResult: Number(data.current_result.max_result),
      stdev: Number(data.current_result.stdev),
      range: Number(data.current_result.range),
      mean: Number(data.current_result.mean),
    },
    updateIdx: Number(data.update_idx),
  };
}
