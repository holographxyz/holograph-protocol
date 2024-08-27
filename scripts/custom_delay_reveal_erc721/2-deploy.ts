import yargs from 'yargs/yargs';
import { Signer, ethers } from 'ethers';
import { hideBin } from 'yargs/helpers';
import { LedgerSigner } from '@anders-t/ethers-ledger';
import { JsonRpcProvider } from '@ethersproject/providers';
import { getNetworkByChainId } from '@holographxyz/networks';

import { deployHolographableContract, readCsvFile } from './utils';
import { CustomERC721Initializer, DeploymentConfig, DeploymentConfigSettings, Hex } from './types';
import { customErc721Bytecode } from './custom-erc721-bytecode';
import { FileColumnsType, parseFileContent, parsedEnv } from './validations';
import { destructSignature, flattenObject, getFactoryAddress, getRegistryAddress, parseBytes } from '../utils/utils';

require('dotenv').config();

/**
 * Check out the README file
 */

async function main() {
  const args = yargs(hideBin(process.argv))
    .options({
      file: {
        type: 'string',
        description: 'reveal csv file',
        alias: 'file',
      },
    })
    .parseSync();

  const { file } = args as { file: string };

  /*
   * STEP 1: LOAD SENSITIVE INFORMATION SAFELY
   */

  const privateKey = parsedEnv.PRIVATE_KEY;
  const salt = parsedEnv.CUSTOM_ERC721_SALT as Hex; // Salt is used for deterministic address generation
  const providerURL = parsedEnv.CUSTOM_ERC721_PROVIDER_URL;
  const isHardwareWalletEnabled = parsedEnv.HARDWARE_WALLET_ENABLED;
  const holographEnv = parsedEnv.HOLOGRAPH_ENVIRONMENT;

  const provider: JsonRpcProvider = new JsonRpcProvider(providerURL);

  let deployer: Signer;
  if (isHardwareWalletEnabled) {
    deployer = new LedgerSigner(provider, "44'/60'/0'/0/0");
  } else {
    deployer = new ethers.Wallet(privateKey, provider);
  }

  const deployerAddress: Hex = (await deployer.getAddress()) as Hex;
  const chainId: number = await provider.getNetwork().then((network: any) => network.chainId);
  const factoryProxyAddress: Hex = await getFactoryAddress(provider, holographEnv);
  const registryProxyAddress: Hex = await getRegistryAddress(provider, holographEnv);

  /*
   * STEP 2: SET THE STATIC VALUES
   */

  const contractName = 'CustomERC721';
  const contractSymbol = 'C721';

  const customERC721Initializer: CustomERC721Initializer = {
    startDate: 1718822400, // Epoch time for June 3, 2024,
    initialMaxSupply: 4173120, // Total number of ten-minute intervals until Oct 8, 2103
    mintInterval: 600, // Duration of each interval
    initialOwner: deployerAddress,
    initialMinter: deployerAddress,
    fundsRecipient: deployerAddress,
    contractURI: 'https://example.com/metadata.json',
    salesConfiguration: {
      publicSalePrice: 100,
      maxSalePurchasePerAddress: 0, // no limit
    },
    lazyMintsConfigurations: [],
  };

  /*
   * STEP 3: READ CSV FILE
   */

  const csvData = await readCsvFile(file);

  const parsedRows: FileColumnsType[] = await parseFileContent(csvData);

  console.log(`Generating lazy mint configuration...`);
  for (let parsedRow of parsedRows) {
    if (!parsedRow.EncryptedURI || !parsedRow.ProvenanceHash) {
      throw new Error(
        `Encrypted URI or Provenance Hash missing! Please ensure that you have run the encrypt script first to generate these values.`
      );
    }

    // Encode _data parameter
    const data = ethers.utils.defaultAbiCoder.encode(
      ['bytes', 'bytes32'],
      [ethers.utils.toUtf8Bytes(parsedRow.EncryptedURI), parsedRow.ProvenanceHash]
    ) as Hex;

    customERC721Initializer.lazyMintsConfigurations.push({
      amount: parsedRow.Range,
      baseURIForTokens: parsedRow['PlaceholderURI Path'],
      data,
    });
  }

  /*
   * STEP 4: PREPARING TO DEPLOY CONTRACT
   */

  console.log(`Preparing to deploy contract...`);

  const customERC721InitCode: Hex = ethers.utils.defaultAbiCoder.encode(
    ['tuple(uint40,uint32,uint24,address,address,address,string,tuple(uint104,uint24),tuple(uint256,string,bytes)[])'],
    [flattenObject(customERC721Initializer)]
  ) as Hex;

  const initCodeEncoded: Hex = ethers.utils.defaultAbiCoder.encode(
    ['bytes32', 'address', 'bytes'],
    [parseBytes('CustomERC721'), registryProxyAddress, customERC721InitCode]
  ) as Hex;

  const encodedInitParameters: Hex = ethers.utils.defaultAbiCoder.encode(
    ['string', 'string', 'uint16', 'uint256', 'bool', 'bytes'],
    [
      contractName,
      contractSymbol,
      0, // contractBps
      BigInt(`0x${'00'.repeat(32)}`), // eventConfig
      false, // skipInit
      initCodeEncoded,
    ]
  ) as Hex;

  const deploymentConfig: DeploymentConfig = {
    contractType: parseBytes('HolographERC721'),
    chainType: getNetworkByChainId(chainId).holographId,
    byteCode: customErc721Bytecode,
    initCode: encodedInitParameters,
    salt,
  };

  // NOTE: keccak256(encodePacked())
  const deploymentConfigHash: Hex = ethers.utils.solidityKeccak256(
    ['bytes32', 'uint32', 'bytes32', 'bytes32', 'bytes32', 'address'],
    [
      deploymentConfig.contractType,
      deploymentConfig.chainType,
      deploymentConfig.salt,
      ethers.utils.keccak256(deploymentConfig.byteCode),
      ethers.utils.keccak256(deploymentConfig.initCode),
      deployerAddress,
    ]
  ) as Hex;

  const signedMessage: Hex = (await deployer.signMessage(deploymentConfigHash!)) as Hex;
  const signature = destructSignature(signedMessage);

  const fullDeploymentConfig: DeploymentConfigSettings = {
    config: deploymentConfig,
    signature: {
      r: signature.r,
      s: signature.s,
      v: Number.parseInt(signature.v, 16),
    },
    signer: deployerAddress,
  };

  /*
   * STEP 5: DEPLOY THE CONTRACT
   */

  console.log(`Starting deploy...`);

  const contractAddress = await deployHolographableContract(deployer, factoryProxyAddress, fullDeploymentConfig);

  console.log(`Contract has been deployed to address ${contractAddress}`);

  console.log(`Exiting script ✅\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
