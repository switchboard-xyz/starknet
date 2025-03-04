<div align="center">
  <a href="#">
    <img src="https://github.com/switchboard-xyz/sbv2-core/raw/main/website/static/img/icons/switchboard/avatar.png" />
  </a>

  <h1>Starknet On-Demand Integration</h1>

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
// TODO
```

## Updating Feeds

With Switchboard On-Demand, passing the ByteArray into the feed update method handles the update automatically. You can prepend this to your existing Starknet transaction and read fresh data from the feed.

```typescript
// TODO:
```

## Adding Switchboard to Cairo Code

To integrate Switchboard with Cairo, add the following dependencies to Cairo.toml:

Once dependencies are configured, updated aggregators can be referenced easily.

## Example Cairo Code for Using Switchboard Values

In the module, use the latest result function to read the latest data for a feed.

```cairo
// TODO:
```

This implementation allows you to read and utilize Switchboard data feeds within Cairo. If you have any questions or need further assistance, please contact the Switchboard team.

**DISCLAIMER: ORACLE CODE AND CORE LOGIC ARE AUDITED - THE AUDIT FOR THIS ON-CHAIN ADAPTER IS PENDING**
