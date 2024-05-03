# CountdownERC721 Contract 

This folder contains four scripts:

- `1-deploy.ts`
- `2-setOwner.ts`
- `3-mintTo.ts`
- `4-purchase.ts`

Below are the steps required to run the scripts successfully.


## Prerequisites

- Node.js and npm installed (v20.11.1)
- Typescript (ES2022)
- Wallet private key
- Network provider URL
- Optional: Hardware wallet (e.g., Ledger)


## Environment Variables

Ensure the following environment variables are set:
- `PRIVATE_KEY`: Wallet private key
- `CUSTOM_ERC721_SALT`: Salt for deterministic address generation (must be a 32-character hexadecimal string)
- `CUSTOM_ERC721_PROVIDER_URL`: Network provider URL
- `HARDWARE_WALLET_ENABLED`: (Optional)  Flag indicating whether a hardware wallet is enabled
- `HOLOGRAPH_ENVIRONMENT`: Holograph environment (develop, testnet, mainnet)


## Script 1: Contract Deploy

This script utilizes hardcoded values, which need to be updated, to generate the initialization parameters for deploying the contract.


### Steps

1. **Load Sensitive Information Safely:**
   - Ensure that you have set the required environment variables mentioned above.

2. **Set the Static Values:**
   - Configure the static values for the countdown ERC721 contract:
     - `contractName`: Name of the ERC721 contract
     - `contractSymbol`: Symbol of the ERC721 contract
     - `countdownERC721Initializer`: Initializer object containing various parameters for the ERC721 contract
       - `description`: Description of the contract
       - `imageURI`: Image URL for the NFT
       - `externalLink`
       - `encryptedMediaURI`
       - `startDate`: Start date in seconds from epoc
       - `initialMaxSupply`: Total Max Supply
       - `mintIntervals`: How much to reduce counter by for a mint
       - `contractURI`s
         - `publicSalePrice`: Note that `10_000_000 = $10` USD

3. **Preparing to Deploy Contract:**
   - Encode contract initialization parameters.
   - Generate deployment configuration hash and sign it.

4. **Deploy the Contract:**
   - Execute the deployment process.
   - Upon successful deployment, the contract address will be displayed.


To run the script, use the following command in your terminal:

```sh
ts-node ./scripts/countdown_erc721/1-deploy.ts
```

## Script 2: Set Owner [WIP]

This is a straightforward script that invokes the contract to update the owner using hardcoded values.

### Steps

1. **Set the static values:**
   - Configure the static values:
     - `contractAddress`: The CountdownERC721 address
     - `newOwner`: The wallet address of the new owner.
2. **Run the script update the owner:**

```sh
ts-node ./scripts/countdown_erc721/2-setOwner.ts 
```

## Script 3: Mint To

This is a straightforward script that invokes the contract `mintTo` function using hardcoded values as parameters.

### Steps

1. **Set the static values:**
   - Configure the static values:
     - `contractAddress`: The CountdownERC721 address
     - `recipient`: The wallet address of recipient.
     - `quantity`: The number of tokens to be minted.
  
2. **Run the script update the owner:**

```sh
ts-node ./scripts/countdown_erc721/3-mintTo.ts 
```

## Script 4: Purchase

This is a straightforward script that invokes the contract `purchase` function using hardcoded values as parameters.

### Steps

1. **Set the static values:**
   - Configure the static values:
     - `contractAddress`: The CountdownERC721 address
     - `quantity`: The number of tokens to be minted.
     - `price`: The public sale price in wei.
  
2. **Run the script update the owner:**

```sh
ts-node ./scripts/countdown_erc721/4-purchase.ts 
```

## Script 5: Set Metadata 

This is a straightforward script that invokes the contract `setMetadataParams` function using hardcoded values as parameters. This script also allows the execution to be made using a Safe wallet.

### Steps

1. **Set the static values:**
   - Configure the static values:
     - `contractAddress`: The CountdownERC721 address
     - `params`: The metadata params that are going to be updated.
     - `safeAddress`: (OPTIONAL) This is the Safe Wallet address, and should only be filled if the Safe wallet is going to be used.
  
2. **Run the script update the owner:**
   - To execute the script using a Safe Wallet pass the '--safe' param:
     ```sh
     ts-node ./scripts/countdown_erc721/4-purchase.ts --safe
     ```
   - To execute the script with a standard wallet just run:
     ```sh
     ts-node ./scripts/countdown_erc721/4-purchase.ts 
     ```
