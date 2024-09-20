# LayerZeroModuleV2 Foundry Scripts

The `LayerZeroModuleV2` Foundry scripts facilitate the deployment of the new messaging module utilizing Layer Zero V2 and manage the various functionalities associated with this module. These scripts can be accessed using the following command:

```bash
pnpm forge:layerZeroModuleV2
```

## Use ledger to sign a script transactions
Here are the steps to use a ledger to sign a script transaction:
1. Set the `HARDWARE_WALLET` environment variable to the address of the hardware wallet you want to use. 
2. Plug in the ledger and open the relevant app.
3. Execute the script with an additional `--ledger` flag.

### Example
```bash
export HARDWARE_WALLET=0x1234567890123456789012345678901234567890
pnpm forge:layerZeroModuleV2 421614 --sig "executeJob(uint256)" --ledger
```

## Possible environment variables description

- `DEPLOYER`: Private key of the deployer.
- `HARDWARE_WALLET`: Override the deployer with a hardware wallet.
- `HOLOGRAPH_ENVIRONMENT`: Deployment environment (`mainnet`, `testnet`, `develop`).
- `DEPLOYMENT_SALT`: Unique salt for each deployment version (used in `holographGenesis.deploy`).
- `ERC721_OWNER`: Private key of the future owner of the NFT contract.
- `ERC721_CONTRACT`: Address of the NFT contract.
- `JOB_PAYLOAD`: Payload of the job to execute.

## Available Commands

### `pnpm forge:layerZeroModuleV2`

This command does not execute any functionality or transactions. Instead, it provides basic help on the available scripts and displays the detected environment variables that can be utilized by the scripts.

### Deploy the LayerZeroModuleV2

This command deploys the `LayerZeroModuleV2` contract on one or multiple chains. For each chain, the script performs the following steps:

1. **Deploy Implementation**: Deploys the `LayerZeroModuleV2` implementation using the `DEPLOYER` private key.
2. **Configure Parameters**: Builds the `gasParameters` and `peers` arrays for all 10 supported chains, automatically detecting whether the environment is a testnet or mainnet based environment.
3. **Deploy Proxy**: Deploys the `LayerZeroModuleProxyV2` proxy using the `HolographGenesis.deploy` function.
4. **Set Messaging Module**: Calls `holographOperator.setMessagingModule` to set the new messaging module.
5. **Update Chain Mapping**: For each of the 10 supported chains, calls `holographInterfaces.updateChainIdMap` to store the chain ID and Layer Zero endpoint ID mapping.

> [!WARNING]
> The `gasParameters` are hardcoded in the script and should be updated if necessary in `scripts/foundry/utils/ChainGasParameters.sol`.

#### Usage

**Script Parameters:**

- `chainIds` (uint256[]): Array of chain IDs on which to deploy.

**Examples:**

```bash
pnpm forge:layerZeroModuleV2 [1,10,56] --sig "deployLzModulesAndUpdateOperatorsMultiChain(uint256[])"
```

```bash
# With ledger
pnpm forge:layerZeroModuleV2 [1,10,56] --sig "deployLzModulesAndUpdateOperatorsMultiChain(uint256[])" --ledger
```

*This command deploys the `LayerZeroModuleV2` contract on Ethereum (1), Optimism (10), and Binance Smart Chain (56), and updates the operators on these chains.*

### Deploy an NFT (CxipERC721) Contract

This command deploys a `CxipERC721` NFT contract on a specified chain.

#### Usage

**Script Parameters:**

- `chainId` (uint256): ID of the chain on which to deploy the contract.

**Examples:**

```bash
pnpm forge:layerZeroModuleV2 11155420 --sig "deployHolographableCxipErc721Contract(uint256)"
```

```bash
# With ledger
pnpm forge:layerZeroModuleV2 11155420 --sig "deployHolographableCxipErc721Contract(uint256)" --ledger
```

*This command deploys the `CxipERC721` contract on Optimism (chain ID 11155420).*

### Mint and Bridge Out an NFT (CxipERC721) Token

This command mints an NFT on a source chain and bridges it to a destination chain.

> [!WARNING]
> At the end of this script, the user will be prompted to execute the job on the destination chain. However, this feature is **not yet implemented**.

#### Usage

**Script Parameters:**

- `fromChainId` (uint256): ID of the chain on which to mint the token.
- `toChainId` (uint256): ID of the chain to which the token will be bridged.

**Examples:**

```bash
pnpm forge:layerZeroModuleV2 11155111 421614 --sig "mintAndBridgeOut(uint256,uint256)"
```

```bash
# With ledger
pnpm forge:layerZeroModuleV2 11155111 421614 --sig "mintAndBridgeOut(uint256,uint256)" --ledger
```

*This command mints an NFT on chain ID 11155111 and bridges it to chain ID 421614.*

### Execute a Job on a Destination Chain

This command executes a predefined job on a specified destination chain.

#### Usage

**Script Parameters:**

- `chainId` (uint256): ID of the chain on which to execute the job.

**Examples:**

```bash
pnpm forge:layerZeroModuleV2 421614 --sig "executeJob(uint256)"
```
  
```bash
# With ledger
pnpm forge:layerZeroModuleV2 421614 --sig "executeJob(uint256)" --ledger
```


### Set LayerZeroModuleV2 Peers

This script sets the peers for the `LayerZeroModuleV2` contract on a specific chain. Peers are authorized addresses that can send messages to the `LayerZeroModuleV2` contract across all 10 supported chains.

#### Usage

**Script Parameters:**

- `chainId` (uint256): ID of the chain on which to set the peers.

**Examples:**

```bash
pnpm forge:layerZeroModuleV2 421614 --sig "setPeers(uint256)"
```
  
```bash
# With ledger
pnpm forge:layerZeroModuleV2 421614 --sig "setPeers(uint256)" --ledger
```

*This command sets the peers for the LayerZeroModuleV2 contract on chain ID 421614.*