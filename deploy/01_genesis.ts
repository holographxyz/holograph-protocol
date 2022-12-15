declare var global: any;
import { Contract } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction, Deployment } from '@holographxyz/hardhat-deploy-holographed/types';
import { LeanHardhatRuntimeEnvironment, hreSplit, txParams } from '../scripts/utils/helpers';
import { SuperColdStorageSigner } from 'super-cold-storage-signer';

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

  let holographGenesisContract: Contract | null = await hre.ethers.getContractOrNull('HolographGenesis');
  let holographGenesisDeployment: Deployment | null = null;
  if (holographGenesisContract == null) {
    try {
      holographGenesisDeployment = await hre.deployments.get('HolographGenesis');
    } catch (ex: any) {
      // we do nothing
    }
  }
  if (
    holographGenesisContract != null &&
    holographGenesisContract.address == '0x0C8aF56F7650a6E3685188d212044338c21d3F73'
  ) {
    let deployedCode: string = await hre.ethers.provider.send('eth_getCode', [
      holographGenesisContract.address,
      'latest',
    ]);
    if (deployedCode == '0x' || deployedCode == '') {
      // no deployed code found, we will need to deploy
      if (hre.networkName == 'localhost') {
        // deploy HolographGenesis on localhost
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f909a68080830f42408080b90956608060405234801561001057600080fd5b50',
            '3260009081526020819052604090819020805460ff19166001179055517f51a7',
            'f65c6325882f237d4aeb43228179cfad48b868511d508e24b4437a8191379061',
            '0089906020808252818101527f54686520667574757265206f66204e46547320',
            '697320486f6c6f67726170682e604082015260600190565b60405180910390a1',
            '6108b6806100a06000396000f3fe608060405234801561001057600080fd5b50',
            '600436106100415760003560e01c806351724d9e14610046578063a07d731614',
            '61005b578063dc7faa071461006e575b600080fd5b6100596100543660046106',
            '91565b6100bb565b005b61005961006936600461075f565b6104ae565b6100a7',
            '61007c36600461079b565b73ffffffffffffffffffffffffffffffffffffffff',
            '1660009081526020819052604090205460ff1690565b60405190151581526020',
            '0160405180910390f35b3360009081526020819052604090205460ff16610139',
            '576040517f08c379a00000000000000000000000000000000000000000000000',
            '0000000000815260206004820181905260248201527f484f4c4f47524150483a',
            '206465706c6f796572206e6f7420617070726f76656460448201526064015b60',
            '405180910390fd5b4684146101a2576040517f08c379a0000000000000000000',
            '00000000000000000000000000000000000000815260206004820152601d6024',
            '8201527f484f4c4f47524150483a20696e636f727265637420636861696e2069',
            '640000006044820152606401610130565b604080517fffffffffffffffffffff',
            'ffffffffffffffffffff0000000000000000000000003360601b166020820152',
            '7fffffffffffffffffffffffff00000000000000000000000000000000000000',
            '0085166034820152600091016040516020818303038152906040526102159061',
            '07b6565b8351602080860191909120604080517fff0000000000000000000000',
            '0000000000000000000000000000000000000000818501523060601b7fffffff',
            'ffffffffffffffffffffffffffffffffff000000000000000000000000166021',
            '8201526035810185905260558082019390935281518082039093018352607501',
            '905280519101209091506102a48161057d565b1561030b576040517f08c379a0',
            '0000000000000000000000000000000000000000000000000000000081526020',
            '6004820152601b60248201527f484f4c4f47524150483a20616c726561647920',
            '6465706c6f79656400000000006044820152606401610130565b818451602086',
            '016000f590506103208161057d565b610386576040517f08c379a00000000000',
            '0000000000000000000000000000000000000000000000815260206004820152',
            '601c60248201527f484f4c4f47524150483a206465706c6f796d656e74206661',
            '696c6564000000006044820152606401610130565b6040517f4ddf47d4000000',
            '000000000000000000000000000000000000000000000000008082529073ffff',
            'ffffffffffffffffffffffffffffffffffff831690634ddf47d4906103da9087',
            '906004016107fb565b6020604051808303816000875af11580156103f9573d60',
            '00803e3d6000fd5b505050506040513d601f19601f8201168201806040525081',
            '019061041d9190610867565b7fffffffff000000000000000000000000000000',
            '0000000000000000000000000016146104a6576040517f08c379a00000000000',
            '0000000000000000000000000000000000000000000000815260206004820181',
            '905260248201527f484f4c4f47524150483a20696e697469616c697a6174696f',
            '6e206661696c65646044820152606401610130565b505050505050565b336000',
            '9081526020819052604090205460ff16610527576040517f08c379a000000000',
            '0000000000000000000000000000000000000000000000008152602060048201',
            '81905260248201527f484f4c4f47524150483a206465706c6f796572206e6f74',
            '20617070726f7665646044820152606401610130565b73ffffffffffffffffff',
            'ffffffffffffffffffffff91909116600090815260208190526040902080547f',
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00',
            '16911515919091179055565b6000813f80158015906105b057507fc5d2460186',
            'f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a4708114155b93',
            '92505050565b7f4e487b71000000000000000000000000000000000000000000',
            '00000000000000600052604160045260246000fd5b600082601f8301126105f7',
            '57600080fd5b813567ffffffffffffffff80821115610612576106126105b756',
            '5b604051601f83017fffffffffffffffffffffffffffffffffffffffffffffff',
            'ffffffffffffffffe0908116603f011681019082821181831017156106585761',
            '06586105b7565b8160405283815286602085880101111561067157600080fd5b',
            '836020870160208301376000602085830101528094505050505092915050565b',
            '600080600080608085870312156106a757600080fd5b8435935060208501357f',
            'ffffffffffffffffffffffff0000000000000000000000000000000000000000',
            '811681146106de57600080fd5b9250604085013567ffffffffffffffff808211',
            '156106fb57600080fd5b610707888389016105e6565b93506060870135915080',
            '82111561071d57600080fd5b5061072a878288016105e6565b91505092959194',
            '509250565b803573ffffffffffffffffffffffffffffffffffffffff81168114',
            '61075a57600080fd5b919050565b6000806040838503121561077257600080fd',
            '5b61077b83610736565b91506020830135801515811461079057600080fd5b80',
            '9150509250929050565b6000602082840312156107ad57600080fd5b6105b082',
            '610736565b805160208083015191908110156107f5577fffffffffffffffffff',
            'ffffffffffffffffffffffffffffffffffffffffffffff8160200360031b1b82',
            '1691505b50919050565b600060208083528351808285015260005b8181101561',
            '08285785810183015185820160400152820161080c565b506000604082860101',
            '5260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            'ffffffe0601f8301168501019250505092915050565b60006020828403121561',
            '087957600080fd5b81517fffffffff0000000000000000000000000000000000',
            '0000000000000000000000811681146105b057600080fdfea164736f6c634300',
            '0811000a820a97a05441d75c9e483a2b899c0af2760724f08f19330feddf1d74',
            '8e46b5f610319e41a0101b596fb6b807fa07393b1eb8f59c927f258e19ae5014',
            '3ece6337ac93c58f22',
          ].join('')
        );
        // enable 0xC0FFEE78121f208475ABDd2cf0853a7afED64749 on localhost
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a70180830186a0940c8af56f7650a6e3685188d212044338c21d3f7380b844',
            'a07d7316000000000000000000000000c0ffee78121f208475abdd2cf0853a7a',
            'fed6474900000000000000000000000000000000000000000000000000000000',
            '00000001820a98a0b368d7739967c121cba8f37dfe889d8abc92c00fc9911266',
            '2a3a317965b37ecca07a4339634975930a18521ffe3d2eb2913cd9bb08858c72',
            'a558d9df7429a937c8',
          ].join('')
        );
        // enable 0xdf5295149F367b1FBFD595bdA578BAd22e59f504 on localhost
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a70280830186a0940c8af56f7650a6e3685188d212044338c21d3f7380b844',
            'a07d7316000000000000000000000000df5295149f367b1fbfd595bda578bad2',
            '2e59f50400000000000000000000000000000000000000000000000000000000',
            '00000001820a98a0f0e433a1a287674ce73e27843cd73dd4ee59e862bf675a51',
            '381a4172796ee98aa03382f39928b8be21ce8e2583428d5b920e83936c3255c5',
            'a77910b91fe796f0d8',
          ].join('')
        );
        // enable 0xd078E391cBAEAa6C5785124a7207ff57d64604b7 on localhost
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a70380830186a0940c8af56f7650a6e3685188d212044338c21d3f7380b844',
            'a07d7316000000000000000000000000d078e391cbaeaa6c5785124a7207ff57',
            'd64604b700000000000000000000000000000000000000000000000000000000',
            '00000001820a98a0ee563a7a4ea3c8cc81250c00dfc839bfe76c41e42e6c7f9c',
            'dda08f5556d21103a05b0c66a1c57fcd151abd3955b74cb8835d5ac2fd054584',
            '3e6c78d663e7d60f63',
          ].join('')
        );
      } else if (hre.networkName == 'localhost2') {
        // deploy HolographGenesis on localhost2
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f909a68080830f42408080b90956608060405234801561001057600080fd5b50',
            '3260009081526020819052604090819020805460ff19166001179055517f51a7',
            'f65c6325882f237d4aeb43228179cfad48b868511d508e24b4437a8191379061',
            '0089906020808252818101527f54686520667574757265206f66204e46547320',
            '697320486f6c6f67726170682e604082015260600190565b60405180910390a1',
            '6108b6806100a06000396000f3fe608060405234801561001057600080fd5b50',
            '600436106100415760003560e01c806351724d9e14610046578063a07d731614',
            '61005b578063dc7faa071461006e575b600080fd5b6100596100543660046106',
            '91565b6100bb565b005b61005961006936600461075f565b6104ae565b6100a7',
            '61007c36600461079b565b73ffffffffffffffffffffffffffffffffffffffff',
            '1660009081526020819052604090205460ff1690565b60405190151581526020',
            '0160405180910390f35b3360009081526020819052604090205460ff16610139',
            '576040517f08c379a00000000000000000000000000000000000000000000000',
            '0000000000815260206004820181905260248201527f484f4c4f47524150483a',
            '206465706c6f796572206e6f7420617070726f76656460448201526064015b60',
            '405180910390fd5b4684146101a2576040517f08c379a0000000000000000000',
            '00000000000000000000000000000000000000815260206004820152601d6024',
            '8201527f484f4c4f47524150483a20696e636f727265637420636861696e2069',
            '640000006044820152606401610130565b604080517fffffffffffffffffffff',
            'ffffffffffffffffffff0000000000000000000000003360601b166020820152',
            '7fffffffffffffffffffffffff00000000000000000000000000000000000000',
            '0085166034820152600091016040516020818303038152906040526102159061',
            '07b6565b8351602080860191909120604080517fff0000000000000000000000',
            '0000000000000000000000000000000000000000818501523060601b7fffffff',
            'ffffffffffffffffffffffffffffffffff000000000000000000000000166021',
            '8201526035810185905260558082019390935281518082039093018352607501',
            '905280519101209091506102a48161057d565b1561030b576040517f08c379a0',
            '0000000000000000000000000000000000000000000000000000000081526020',
            '6004820152601b60248201527f484f4c4f47524150483a20616c726561647920',
            '6465706c6f79656400000000006044820152606401610130565b818451602086',
            '016000f590506103208161057d565b610386576040517f08c379a00000000000',
            '0000000000000000000000000000000000000000000000815260206004820152',
            '601c60248201527f484f4c4f47524150483a206465706c6f796d656e74206661',
            '696c6564000000006044820152606401610130565b6040517f4ddf47d4000000',
            '000000000000000000000000000000000000000000000000008082529073ffff',
            'ffffffffffffffffffffffffffffffffffff831690634ddf47d4906103da9087',
            '906004016107fb565b6020604051808303816000875af11580156103f9573d60',
            '00803e3d6000fd5b505050506040513d601f19601f8201168201806040525081',
            '019061041d9190610867565b7fffffffff000000000000000000000000000000',
            '0000000000000000000000000016146104a6576040517f08c379a00000000000',
            '0000000000000000000000000000000000000000000000815260206004820181',
            '905260248201527f484f4c4f47524150483a20696e697469616c697a6174696f',
            '6e206661696c65646044820152606401610130565b505050505050565b336000',
            '9081526020819052604090205460ff16610527576040517f08c379a000000000',
            '0000000000000000000000000000000000000000000000008152602060048201',
            '81905260248201527f484f4c4f47524150483a206465706c6f796572206e6f74',
            '20617070726f7665646044820152606401610130565b73ffffffffffffffffff',
            'ffffffffffffffffffffff91909116600090815260208190526040902080547f',
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00',
            '16911515919091179055565b6000813f80158015906105b057507fc5d2460186',
            'f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a4708114155b93',
            '92505050565b7f4e487b71000000000000000000000000000000000000000000',
            '00000000000000600052604160045260246000fd5b600082601f8301126105f7',
            '57600080fd5b813567ffffffffffffffff80821115610612576106126105b756',
            '5b604051601f83017fffffffffffffffffffffffffffffffffffffffffffffff',
            'ffffffffffffffffe0908116603f011681019082821181831017156106585761',
            '06586105b7565b8160405283815286602085880101111561067157600080fd5b',
            '836020870160208301376000602085830101528094505050505092915050565b',
            '600080600080608085870312156106a757600080fd5b8435935060208501357f',
            'ffffffffffffffffffffffff0000000000000000000000000000000000000000',
            '811681146106de57600080fd5b9250604085013567ffffffffffffffff808211',
            '156106fb57600080fd5b610707888389016105e6565b93506060870135915080',
            '82111561071d57600080fd5b5061072a878288016105e6565b91505092959194',
            '509250565b803573ffffffffffffffffffffffffffffffffffffffff81168114',
            '61075a57600080fd5b919050565b6000806040838503121561077257600080fd',
            '5b61077b83610736565b91506020830135801515811461079057600080fd5b80',
            '9150509250929050565b6000602082840312156107ad57600080fd5b6105b082',
            '610736565b805160208083015191908110156107f5577fffffffffffffffffff',
            'ffffffffffffffffffffffffffffffffffffffffffffff8160200360031b1b82',
            '1691505b50919050565b600060208083528351808285015260005b8181101561',
            '08285785810183015185820160400152820161080c565b506000604082860101',
            '5260407fffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            'ffffffe0601f8301168501019250505092915050565b60006020828403121561',
            '087957600080fd5b81517fffffffff0000000000000000000000000000000000',
            '0000000000000000000000811681146105b057600080fdfea164736f6c634300',
            '0811000a820a9aa065edd5f689b14d3fcdc5808bc0e732055c70ccdd6f35430f',
            '6d6bb896058c69b6a02a3128da3839c946051c2991ad92b4ed4ef7b885c1a3c9',
            'efa6465bf438f49d1c',
          ].join('')
        );
        // enable 0xC0FFEE78121f208475ABDd2cf0853a7afED64749 on localhost2
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a70180830186a0940c8af56f7650a6e3685188d212044338c21d3f7380b844',
            'a07d7316000000000000000000000000c0ffee78121f208475abdd2cf0853a7a',
            'fed6474900000000000000000000000000000000000000000000000000000000',
            '00000001820a9aa0fdad2831e1ead5069c2c6e28e62afe0b1d563bc4242312bb',
            '555b0388003f89d8a01aa43771970f8bc0bf421a3bbbe76f43df751844cad394',
            'e80a8eb2d8b7cf1acc',
          ].join('')
        );
        // enable 0xdf5295149F367b1FBFD595bdA578BAd22e59f504 on localhost2
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a70280830186a0940c8af56f7650a6e3685188d212044338c21d3f7380b844',
            'a07d7316000000000000000000000000df5295149f367b1fbfd595bda578bad2',
            '2e59f50400000000000000000000000000000000000000000000000000000000',
            '00000001820a99a0da75a4092b76b4061ddaad5166e0630fe20881abadc46496',
            'c614d9a9bc6f40c7a0056fcda9c2608868b7aee809f24f017077a974000ea8fb',
            '002ccb3e8cf98d4749',
          ].join('')
        );
        // enable 0xd078E391cBAEAa6C5785124a7207ff57d64604b7 on localhost
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a70380830186a0940c8af56f7650a6e3685188d212044338c21d3f7380b844',
            'a07d7316000000000000000000000000d078e391cbaeaa6c5785124a7207ff57',
            'd64604b700000000000000000000000000000000000000000000000000000000',
            '00000001820a9aa0f60ec05b3d2d9c76ea11e75e86bb38c471e824ae286301ba',
            '47b9c49b3b68b925a03e1cdcd949dfea76435af19fce10dafddeddc6a91c4c0d',
            'e1e2dcbecc8238bc1b',
          ].join('')
        );
      }
    }
    let deployedCode: string = await hre.ethers.provider.send('eth_getCode', [
      holographGenesisContract.address,
      'latest',
    ]);
  }
  if (holographGenesisContract == null && holographGenesisDeployment == null) {
    let holographGenesis = await hre.deployments.deploy('HolographGenesis', {
      ...(await txParams({
        hre,
        from: deployer,
        to: '0x0000000000000000000000000000000000000000',
        gasLimit: await hre.ethers.provider.estimateGas(
          (await hre.ethers.getContractFactory('HolographGenesis')).getDeployTransaction()
        ),
      })),
      args: [],
      log: true,
      waitConfirmations: 1,
    });
  }
};

export default func;
func.tags = ['HolographGenesis'];
func.dependencies = [];
