import { Signer, ethers } from 'ethers';
import { LedgerSigner } from '@anders-t/ethers-ledger';
import { JsonRpcProvider } from '@ethersproject/providers';
import { getNetworkByChainId } from '@holographxyz/networks';

import { deployHolographableContract } from './utils';
import { destructSignature, flattenObject, getFactoryAddress, getRegistryAddress, parseBytes } from '../utils/utils';
import { CountdownERC721Initializer, DeploymentConfig, DeploymentConfigSettings, Hex } from './types';
import { countdownErc721ProxyBytecode } from './countdown-erc721.bytecodes';
import { parsedEnv } from './env.validation';

require('dotenv').config();

/**
 * Check out the README file
 */

async function main() {
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

  const contractName = 'CountdownTest001';
  const contractSymbol = 'CTO1';

  const customERC721Initializer: CountdownERC721Initializer = {
    description: '<ENTER MY DESCRIPTION>',
    imageURI: 'testURI', // Will not change, currently hardcoded
    animationURI: 'ar://animationUriHere',
    externalLink: 'https://your-nft-project.com', // Will not change, currently hardcoded
    encryptedMediaURI: 'ar://encryptedMediaUriHere', // Will not change, currently hardcoded
    startDate: 1714512791, // Epoch time for Tuesday, April 30, 2024 9:33:11 PM
    initialMaxSupply: 4173120, // Total number of ten-minute intervals until Oct 8, 2103
    mintInterval: 600, // Duration of each interval
    initialOwner: deployerAddress,
    initialMinter: deployerAddress,
    fundsRecipient: deployerAddress,
    contractURI: 'https://example.com/metadata.json', // Will not change, currently hardcoded
    salesConfiguration: {
      publicSalePrice: 10_000_000, // Set price in wei
      maxSalePurchasePerAddress: 0, // no limit
    },
  };

  /*
   * STEP 3: PREPARING TO DEPLOY CONTRACT
   */

  console.log(`Preparing to deploy contract...`);

  const countdownERC721InitCode: Hex = ethers.utils.defaultAbiCoder.encode(
    [
      'tuple(string,string,string,string,string,uint40,uint32,uint24,address,address,address,string,tuple(uint104,uint24))',
    ],
    [flattenObject(customERC721Initializer)]
  ) as Hex;

  const initCodeEncoded: Hex = ethers.utils.defaultAbiCoder.encode(
    ['bytes32', 'address', 'bytes'],
    [parseBytes('CountdownERC721'), registryProxyAddress, countdownERC721InitCode]
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
    byteCode: countdownErc721ProxyBytecode,
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
   * STEP 4: DEPLOY THE CONTRACT
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
