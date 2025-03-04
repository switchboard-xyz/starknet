import type { CommonOptions, SnakeToCamel, SwitchboardClient } from "..";
import { hexToUint256, randomId, convertNumericToHex } from "..";

import type { BigNumberish, Uint256 } from "starknet";
import { cairo, num, uint256, shortString } from "starknet";

export type QueueInitParams = SnakeToCamel<StarknetQueueInitParams>;
export type QueueSetAuthorityParams =
  SnakeToCamel<StarknetQueueSetAuthorityParams>;
export type QueueSetConfigsParams = SnakeToCamel<StarknetQueueSetConfigsParams>;

export interface StarknetQueueInitParams extends CommonOptions {
  queue_id: Uint256;
  authority: string;
  name: BigNumberish;
  fee: number | bigint | Uint256;
  fee_recipient: string;
  min_attestations: number | bigint;
  tolerated_timestamp_delta: number | bigint;
  oracle_validity_length: number | bigint;
  guardian_queue_id: number | bigint | Uint256;
}

export interface StarknetQueueSetAuthorityParams extends CommonOptions {
  queue_id: number | bigint | Uint256;
  authority: string;
}

export interface StarknetQueueSetConfigsParams extends CommonOptions {
  queue_id: number | bigint | Uint256;
  name: BigNumberish;
  fee: number | bigint | Uint256;
  fee_recipient: string;
  min_attestations: number | bigint;
  tolerated_timestamp_delta: number | bigint;
  oracle_validity_length: number | bigint;
  guardian_queue_id: number | bigint | Uint256;
}

export interface OracleConfig extends CommonOptions {
  authority: string;
  oracle_id: number | bigint | Uint256;
  queue_id: number | bigint | Uint256;
  mr_enclave: number | bigint | Uint256;
  expiration_time: number | bigint;
  fees_owed: number | bigint;
}

export interface QueueOverrideOraclesParams extends CommonOptions {
  queueId: number | bigint | Uint256;
  oracles: Array<OracleConfig>;
}

export interface OracleData {
  authority: string;
  oracle_id: string;
  queue_id: string;
  mr_enclave: string;
  expiration_time: number;
  fees_owed: number;
}

export interface QueueData {
  queue_id: string;
  authority: string;
  name: string;
  fee: number;
  fee_recipient: string;
  min_attestations: number;
  tolerated_timestamp_delta: number;
  oracle_validity_length: number;
  guardian_queue_id: string;
  last_queue_override: number;
  oracles: OracleData[];
}

export class Queue {
  constructor(readonly client: SwitchboardClient, readonly id: Uint256) {}

  /**
   * Create a new Queue
   */
  public static async init(
    client: SwitchboardClient,
    params: QueueInitParams
  ): Promise<Queue> {
    try {
      const state = await client.fetchState(params);
      const contract = state.contract;
      const snakeParams = {
        queue_id: params.queueId,
        authority: params.authority,
        name: params.name,
        fee: params.fee,
        fee_recipient: params.feeRecipient,
        min_attestations: params.minAttestations,
        tolerated_timestamp_delta: params.toleratedTimestampDelta,
        oracle_validity_length: params.oracleValidityLength,
        guardian_queue_id: params.guardianQueueId,
      };
      const tx = await contract.create_queue(snakeParams);
      await contract.providerOrAccount.waitForTransaction(tx.transaction_hash);
      return new Queue(client, params.queueId);
    } catch (error) {
      throw new Error(`Error creating queue: ${error}`);
    }
  }

  /**
   * Set the authority of a Queue
   * @dev The authority is the address that can set the configs of the Queue
   * @dev This is an administrative function
   */
  public async setAuthority(params: QueueSetAuthorityParams): Promise<void> {
    try {
      const state = await this.client.fetchState(params);
      const contract = state.contract;
      const snakeParams = {
        queue_id: this.id,
        authority: params.authority,
      };
      const tx = await contract.set_queue_authority(snakeParams);
      await contract.providerOrAccount.waitForTransaction(tx.transaction_hash);
    } catch (error) {
      throw new Error(`Error setting queue authority: ${error}`);
    }
  }

  /**
   * Set the configs of a Queue
   * @dev This is an administrative function
   * @dev The authority can set the configs of the Queue
   */
  public async setConfigs(params: QueueSetConfigsParams): Promise<void> {
    try {
      const state = await this.client.fetchState(params);
      const contract = state.contract;
      const snakeParams = {
        queue_id: this.id,
        name: params.name,
        fee: params.fee,
        fee_recipient: params.feeRecipient,
        min_attestations: params.minAttestations,
        tolerated_timestamp_delta: params.toleratedTimestampDelta,
        oracle_validity_length: params.oracleValidityLength,
        guardian_queue_id: params.guardianQueueId,
      };
      const tx = await contract.set_configs(snakeParams);
      await contract.providerOrAccount.waitForTransaction(tx.transaction_hash);
    } catch (error) {
      throw new Error(`Error setting queue configs: ${error}`);
    }
  }

  /**
   * Override the oracles of a Queue
   * @dev This is an administrative function
   * @dev The authority can override the oracles of the Queue (though this will be disabled in the future)
   */
  public async overrideOracles(
    params: QueueOverrideOraclesParams
  ): Promise<void> {
    try {
      const state = await this.client.fetchState(params);
      const contract = state.contract;
      const queueId = params.queueId;
      const oracles: Array<OracleConfig> = params.oracles;
      const tx = await contract.override_queue_oracles(queueId, oracles);
      await contract.providerOrAccount.waitForTransaction(tx.transaction_hash);
    } catch (error) {
      throw new Error(`Error overriding queue oracles: ${error}`);
    }
  }

  /**
   * Get the state of a Queue
   */
  public async loadData(): Promise<QueueData> {
    const state = await this.client.fetchState();
    const queues = await state.contract.get_all_queues();

    const queueDatas = queues.map((q: any) => {
      const [sbQueue, sbOracles] = Object.values(q) as any;
      const oracles: OracleData[] = sbOracles.map((o: any) => {
        return {
          authority: convertNumericToHex(o.authority),
          oracle_id: convertNumericToHex(o.oracle_id),
          queue_id: convertNumericToHex(o.queue_id),
          mr_enclave: convertNumericToHex(o.mr_enclave),
          expiration_time: Number(o.expiration_time),
          fees_owed: Number(o.fees_owed),
        };
      });

      const queue: QueueData = {
        queue_id: convertNumericToHex(sbQueue.queue_id),
        authority: convertNumericToHex(sbQueue.authority),
        name: shortString.decodeShortString(sbQueue.name),
        fee: Number(sbQueue.fee),
        fee_recipient: convertNumericToHex(sbQueue.fee_recipient),
        min_attestations: Number(sbQueue.min_attestations),
        tolerated_timestamp_delta: Number(sbQueue.tolerated_timestamp_delta),
        oracle_validity_length: Number(sbQueue.oracle_validity_length),
        guardian_queue_id: convertNumericToHex(sbQueue.guardian_queue_id),
        last_queue_override: Number(sbQueue.last_queue_override),
        oracles,
      };

      return queue;
    });

    const queue = queueDatas.find(
      (q) => q.queue_id === convertNumericToHex(this.id)
    );

    return queue;
  }

  /**
   * Get all queues
   */
  public async getAllQueues(): Promise<QueueData[]> {
    const state = await this.client.fetchState();
    const queues = await state.contract.get_all_queues();

    const queueDatas = queues.map((q: any) => {
      const [sbQueue, sbOracles] = Object.values(q) as any;
      const oracles: OracleData[] = sbOracles.map((o: any) => {
        return {
          authority: convertNumericToHex(o.authority),
          oracle_id: convertNumericToHex(o.oracle_id),
          queue_id: convertNumericToHex(o.queue_id),
          mr_enclave: convertNumericToHex(o.mr_enclave),
          expiration_time: Number(o.expiration_time),
          fees_owed: Number(o.fees_owed),
        };
      });

      const queue: QueueData = {
        queue_id: convertNumericToHex(sbQueue.queue_id),
        authority: convertNumericToHex(sbQueue.authority),
        name: shortString.decodeShortString(sbQueue.name),
        fee: Number(sbQueue.fee),
        fee_recipient: convertNumericToHex(sbQueue.fee_recipient),
        min_attestations: Number(sbQueue.min_attestations),
        tolerated_timestamp_delta: Number(sbQueue.tolerated_timestamp_delta),
        oracle_validity_length: Number(sbQueue.oracle_validity_length),
        guardian_queue_id: convertNumericToHex(sbQueue.guardian_queue_id),
        last_queue_override: Number(sbQueue.last_queue_override),
        oracles,
      };

      return queue;
    });

    return queueDatas;
  }
}
