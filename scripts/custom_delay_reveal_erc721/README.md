# Custom ERC721 Contract 

This folder contains three scripts:

- `1-encrypt-batch-ranges.ts`
- `2-deploy.ts`
- `3-reveal.ts`

Below are the steps required to run the scripts successfully.

</br>

## Prerequisites

- Node.js and npm installed (v20.11.1)
- Typescript (ES2022)
- Wallet private key
- Network provider URL
- Optional: Hardware wallet (e.g., Ledger)
  
</br>

## Environment Variables

Ensure the following environment variables are set:
- `PRIVATE_KEY`: Wallet private key
- `CUSTOM_ERC721_SALT`: Salt for deterministic address generation (must be a 32-character hexadecimal string)
- `CUSTOM_ERC721_PROVIDER_URL`: Network provider URL
- `HARDWARE_WALLET_ENABLED`: (Optional)  Flag indicating whether a hardware wallet is enabled
- `HOLOGRAPH_ENVIRONMENT`: Holograph environment (localhost, develop, testnet, mainnet)

</br>

## Script 1: Encrypt Batch Ranges

This script reads the provided `.csv` file, validates it, and encrypts the `RevealURI Path` with the `Key` to generate the `EncryptedURI`. It also encodes the `RevealURI Path`, `Key`, and the chain ID to generate the `ProvenanceHash`.

### Steps

1. Create a `.csv` file with the following columns and use **","** as the separation character:

   | BatchId | Name | Range | PlaceholderURI Path | RevealURI Path | Key | ProvenanceHash | EncryptedURI | Should Decrypt |
   | ------- | ---- | ----- | ------------------- | -------------- | --- | --------------- | ------------ | -------------- |
   |         |      |       |                     |                |     |                 |              |                |

   Example:
   ```csv
   BatchId,Name,Range,PlaceholderURI Path,RevealURI Path,Key,ProvenanceHash,EncryptedURI,Should Decrypt
   1,Track 1,200,teste/metadata.json,real/metadata.json,0x1234,,,false
   2,Track 2,200,teste/metadata.json,real/metadata.json,0x1234,,,false
   3,Track 3,200,teste/metadata.json,real/metadata.json,0x1234,,,false

1. Run the script:

```sh
ts-node custom_delay_reveal_erc721/1-encrypt-batch-ranges.ts --file path-to-file.csv
```

3. After the script finishes the execution check the file again and make sure the `ProvenanceHash` and `EncryptedURI` are filled.

</br>

## Script 2: Contract Deploy

This script uses the updated file where `ProvenanceHash` and `EncryptedURI` are filled, along with some hardcoded static variables (that should be updated) to generate the init parameters to deploy the contract.


### Steps

1. **Load Sensitive Information Safely:**
   - Ensure that you have set the required environment variables mentioned above.

2. **Set the Static Values:**
   - Configure the static values for the custom ERC721 contract:
     - `contractName`: Name of the ERC721 contract
     - `contractSymbol`: Symbol of the ERC721 contract
     - `customERC721Initializer`: Initializer object containing various parameters for the ERC721 contract

3. **CSV File Read:**
   - Provide a CSV file with the required data for deployment.
   - Validate the CSV file header and content.
   - Generate the lazy minting configuration.

4. **Preparing to Deploy Contract:**
   - Encode contract initialization parameters.
   - Generate deployment configuration hash and sign it.

5. **Deploy the Contract:**
   - Execute the deployment process.
   - Upon successful deployment, the contract address will be displayed.

</br>

To run the script, use the following command in your terminal:

```sh
ts-node custom_delay_reveal_erc721/deploy.ts --file path-to-file.csv
```

</br>

## Script 3: Batch Reveal

This script reveals one or more batches.

### Steps

1. **Update the File:**
   - Update the "Should Decrypt" column of the file with the value "true" .
  
1. **Run the script to reveal a batch:**
```sh
ts-node custom_delay_reveal_erc721/reveal.ts --file path-to-file.csv
```