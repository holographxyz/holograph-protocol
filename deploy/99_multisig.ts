declare var global: any;
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from '@holographxyz/hardhat-deploy-holographed/types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { SuperColdStorageSigner } from 'super-cold-storage-signer';
import { hreSplit, txParams } from '../scripts/utils/helpers';
import { NetworkType, networks } from '@holographxyz/networks';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const accounts = await hre.ethers.getSigners();
  let deployer: SignerWithAddress | SuperColdStorageSigner = accounts[0];

  if (global.__superColdStorage) {
    // address, domain, authorization, ca
    const coldStorage = global.__superColdStorage;
    deployer = new SuperColdStorageSigner(
      coldStorage.address,
      'https://' + coldStorage.domain,
      coldStorage.authorization,
      deployer.provider,
      coldStorage.ca
    );
  }

  const currentNetworkType: NetworkType = networks[hre.networkName].type;

  if (currentNetworkType == NetworkType.mainnet) {
    const multisigs: { [key: string]: string } = {
      avalanche: '0x569FcF96b09d228918721E33D46C6ca58302B247',
      polygon: '0xCD2Ec32814f28622533ffcc9131F0D7B2c2CF038',
      ethereum: '0x99102e9bf378AE777e16D5f1D2D8Ff89b066c5af',
    };
    if (!(hre.networkName in multisigs)) {
      throw new Error('no multisig setup');
    }
    const MULTI_SIG: string = multisigs[hre.networkName].toLowerCase();

    const switchToHolograph: string[] = [
      'HolographBridgeProxy',
      'HolographFactoryProxy',
      'HolographInterfaces',
      'HolographOperatorProxy',
      'HolographRegistryProxy',
      'HolographTreasuryProxy',
      'LayerZeroModule',
    ];

    const holograph = await hre.ethers.getContract('Holograph', deployer);

    let setHolographAdminTx = await holograph.setAdmin(MULTI_SIG, {
      ...(await txParams({
        hre,
        from: deployer,
        to: holograph,
        data: holograph.populateTransaction.setAdmin(MULTI_SIG),
      })),
    });
    hre.deployments.log(`Changing Holograph Admin tx ${setHolographAdminTx.hash}`);
    await setHolographAdminTx.wait();
    hre.deployments.log('Changed Holograph Admin');

    for (const contractName of switchToHolograph) {
      const contract = await hre.ethers.getContract(contractName, deployer);
      let setHolographAsAdminTx = await contract.setAdmin(holograph.address, {
        ...(await txParams({
          hre,
          from: deployer,
          to: contract,
          data: contract.populateTransaction.setAdmin(holograph.address),
        })),
      });
      hre.deployments.log(`Changing ${contractName} Admin to Holograph tx ${setHolographAsAdminTx.hash}`);
      await setHolographAsAdminTx.wait();
      hre.deployments.log(`Changed ${contractName} Admin to Holograph`);
    }
  }
};
export default func;
func.tags = ['MultiSig'];
func.dependencies = [
  'HolographGenesis',
  'DeploySources',
  'DeployERC20',
  'DeployERC721',
  'RegisterTemplates',
  'Holographer4verify',
];
