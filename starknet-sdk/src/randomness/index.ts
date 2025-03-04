import type { CommonOptions, SwitchboardClient } from "..";
import {
  byteArrayFromHex,
  convertNumericToHex,
  hexToUint256,
  loadSolanaQueue,
  STARKNET_MAINNET_ADDRESS,
} from "..";

import { web3 } from "@coral-xyz/anchor";
import type { RandomnessRevealResponse } from "@switchboard-xyz/on-demand";
import { EVM, Gateway, Oracle } from "@switchboard-xyz/on-demand";
import type { Uint256 } from "starknet";
import type { ByteArray } from "starknet";

export interface RandomnessInitParams extends CommonOptions {
  randomnessId: string | Uint256;
  queueId: Uint256;
  authority: string;
  minSettlementDelay: number | bigint;
}

export interface SetRandomnessConfigsParams extends CommonOptions {
  minSettlementDelay: number | bigint;
}

export interface CommitRandomnessParams extends CommonOptions {
  oracleId?: string | Uint256;
  solanaRPCURL?: string;
}

export interface RevealRandomnessParams extends CommonOptions {
  gateway?: string;
  solanaRPCUrl?: string;
}

export interface RevealRandomnessResponse {
  randomnessUpdate: ByteArray;
  randomnessHex: string;
  responses: RandomnessRevealResponse;
}

export class Randomness {
  public id: Uint256;
  constructor(readonly client: SwitchboardClient, id: string | Uint256) {
    if (typeof id === "string") {
      this.id = hexToUint256(id);
    } else {
      this.id = id;
    }
  }

  public static async init(
    client: SwitchboardClient,
    params: RandomnessInitParams
  ): Promise<Randomness> {
    const state = await client.fetchState(params);
    const contract = state.contract;

    if (typeof params.randomnessId === "string") {
      params.randomnessId = hexToUint256(params.randomnessId);
    }
    const randomness_id = params.randomnessId;
    const tx = await contract.create_randomness({
      randomness_id,
      authority: params.authority,
      min_settlement_delay: params.minSettlementDelay,
      queue_id: params.queueId,
    });
    await client.providerOrAccount.waitForTransaction(tx.transaction_hash);
    return new Randomness(client, randomness_id);
  }

  public async commitRandomness(params: CommitRandomnessParams): Promise<void> {
    const state = await this.client.fetchState(params);
    const contract = state.contract;

    if (typeof params.oracleId === "string") {
      params.oracleId = hexToUint256(params.oracleId);
    }

    // get oracle
    const isMainnet = state.switchboardAddress === STARKNET_MAINNET_ADDRESS;
    const queue = await loadSolanaQueue(isMainnet);
    const oracleId =
      params.oracleId ??
      hexToUint256((await queue.fetchFreshOracle()).toBuffer().toString("hex"));
    const tx = await contract.commit_randomness({
      randomness_id: this.id,
      oracle_id: oracleId,
    });
    await contract.providerOrAccount.waitForTransaction(tx.transaction_hash);
  }

  public async setRandomnessConfigs(
    params: SetRandomnessConfigsParams
  ): Promise<void> {
    const state = await this.client.fetchState(params);
    const contract = state.contract;
    const tx = await contract.set_randomness_configs({
      randomness_id: this.id,
      min_settlement_delay: params.minSettlementDelay,
    });
    await contract.providerOrAccount.waitForTransaction(tx.transaction_hash);
  }

  public async resolveRandomness(
    params: RevealRandomnessParams
  ): Promise<RevealRandomnessResponse> {
    const state = await this.client.fetchState(params);
    const randomness = await this.loadData();
    const isMainnet = state.switchboardAddress === STARKNET_MAINNET_ADDRESS;
    const queue = await loadSolanaQueue(isMainnet, params.solanaRPCUrl);

    let gateway: Gateway;
    if (params.gateway) {
      gateway = new Gateway(queue.program, params.gateway);
    } else {
      const oracle = new Oracle(
        queue.program,
        new web3.PublicKey(
          convertNumericToPublicKey(randomness.result.oracle_id)
        )
      );
      const oracleData = await oracle.loadData();
      const gatewayUrl = String.fromCharCode(...oracleData.gatewayUri).replace(
        /\0+$/,
        ""
      );
      gateway = new Gateway(queue.program, gatewayUrl);
    }

    const gatewayRevealResponse = await gateway.fetchRandomnessReveal({
      randomnessId: convertNumericToHex(this.id),
      timestamp: Number(randomness.roll_timestamp.toString()),
      minStalenessSeconds: Number(randomness.min_settlement_delay),
    });

    // fix array type
    const randomnessArray: number[] = gatewayRevealResponse.value as any;
    const randomnessValue = Buffer.from(randomnessArray).toString("hex");

    const signatureBuffer = new Uint8Array(
      Buffer.from(gatewayRevealResponse.signature, "base64")
    );
    const r = Buffer.from(signatureBuffer.slice(0, 32)).toString("hex");
    const s = Buffer.from(signatureBuffer.slice(32, 64)).toString("hex");
    const v = gatewayRevealResponse.recovery_id;
    const message = EVM.message.createRandomnessRevealHexString({
      discriminator: 3 as any,
      randomnessId: convertNumericToHex(this.id),
      result: randomnessValue,
      r,
      s,
      v,
    });

    return {
      randomnessUpdate: byteArrayFromHex(message),
      randomnessHex: message,
      responses: gatewayRevealResponse,
    };
  }

  public async loadData() {
    const state = await this.client.fetchState();
    return state.contract.get_randomness(this.id);
  }
}

export function convertNumericToPublicKey(
  value: number | bigint | Uint256
): web3.PublicKey {
  if (typeof value === "number") {
    throw new Error("Cannot convert a number to a PublicKey");
  } else if (typeof value === "bigint") {
    return new web3.PublicKey(Buffer.from(value.toString(16), "hex"));
  } else {
    return new web3.PublicKey(Buffer.from(convertNumericToHex(value), "hex"));
  }
}
