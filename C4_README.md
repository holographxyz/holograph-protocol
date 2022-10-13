# 🥳 Holograph Contest Details
- $75,000 USDC main award pot
- $0 USDC gas optimization award pot
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form]()
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts October 18, 2022 10:00 UTC
- Ends October 25, 2022 10:00 UTC

## 📃 Description

Holograph provides omnichain NFT infrastructure for the web3 ecosystem. Holograph Protocol enables the creation, deployment, minting, & bridging of omnichain NFTs with complete data integrity.

## 🧙 Setup Instructions and Codebase Overview:
- [Holograph Protocol Specification](https://docs.holograph.xyz/holograph-protocol/technical-specification)
- [Holograph Code Setup](./SETUP_README.md)
- [Holograph Contract Descriptions](./CONTRACT_DESCRIPTIONS.md)
- [Holograph Flows (Bridge / Operator / Pods)](./IMPORTANT_FLOWS.md)


## 🛫 Quick Start
```bash
yarn install
```
```bash
yarn build
```
Terminal 1
```bash
yarn ganache-x2
```
Terminal 2
```bash
yarn test
```


## 🔎 Contracts in Scope

| File                           | Description                                                                        | Lines Of Code |
|--------------------------------|------------------------------------------------------------------------------------|---------------|
| `HolographBridge.sol`          | primary use for FE user to make cross-chain beam request                           | 226           |
| `HolographOperator.sol`        | finalizes cross-chain beam                                                         | 434           |
| `HolographFactory.sol`         | combines deployment config and deploys holographable contracts                     | 135           |
| `module/LayerZeroModule.sol`   | controls the exit and entry points for bridging                                    | 228           |
| `enforcer/Holographer.sol`     | wrapper for custom user contract and standards enforcer contract                   | 83            |
| `enforcer/PA1D.sol`            | responds to royalty info for ERC721 contracts                                      | 367           |
| `enforcer/HolographERC721.sol` | ERC721 standards enforcer                                                          | 482           |
| `enforcer/HolographERC20.sol`  | ERC20 standards enforcer                                                           | 495           |
| `abstract/ERC721H.sol`         | helper contract to use as base when creating custom ERC721 holographable contracts | 82            |
| `abstract/ERC20H.sol`          | helper contract to use as base when creating custom ERC20 holographable contracts  | 82            |

## Directory Structure

<pre>
root

├── <a href="./config">config</a>: Network configuration files
├── <a href="./contracts">contracts</a>: Smart contracts that power the Holograph protocol
├── <a href="./deploy">deploy</a>: Deployment scripts for the smart contracts uses <a href="https://hardhat.org/">Hardhat</a> and <a href="https://github.com/wighawag/hardhat-deploy">Hardhat Deploy</a>
├── <a href="./deployments">deployments</a>: Deployment build files that include contract addresses on each network
├── <a href="./scripts">scripts</a>: Scripts and helper utilities
├── <a href="./src">src</a>: Source contracts that get dynamically transpiled down into the finalized output <a href="./contracts">contracts</a>
└── <a href="./test">test</a>: Hardhat tests for the smart contracts
</pre>
