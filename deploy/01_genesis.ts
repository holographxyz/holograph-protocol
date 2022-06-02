declare var global: any;
import { Contract } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction, Deployment } from 'hardhat-deploy-holographed/types';
import { LeanHardhatRuntimeEnvironment, hreSplit } from '../scripts/utils/helpers';

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {
  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork);
  const { artifacts, deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let holographGenesisContract: Contract | null = await hre.ethers.getContractOrNull('HolographGenesis');
  let holographGenesisDeployment: Deployment | null = null;
  if (holographGenesisContract == null) {
    try {
      holographGenesisDeployment = await deployments.get('HolographGenesis');
    } catch (ex: any) {
      // we do nothing
    }
  }
  if (
    holographGenesisContract != null &&
    holographGenesisContract.address == '0x9f69aefbb4418a1b4642116b5c8c2b30896019a8'
  ) {
    let deployedCode: string = await hre.provider.send('eth_getCode', [holographGenesisContract.address]);
    if (deployedCode == '0x' || deployedCode == '') {
      // no deployed code found, we will need to deploy
      if (hre.networkName == 'localhost') {
        // deploy HolographGenesis on localhost
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f909ad8080830aae608080b9095d608060405234801561001057600080fd5b50',
            '3260009081526020819052604090819020805460ff19166001179055517f51a7',
            'f65c6325882f237d4aeb43228179cfad48b868511d508e24b4437a8191379061',
            '0089906020808252818101527f54686520667574757265206f66204e46547320',
            '697320486f6c6f67726170682e604082015260600190565b60405180910390a1',
            '6108bd806100a06000396000f3fe608060405234801561001057600080fd5b50',
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
            '019061041d919061086e565b7fffffffff000000000000000000000000000000',
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
            '08285785810183015185820160400152820161080c565b8181111561083a5760',
            '00604083870101525b50601f017fffffffffffffffffffffffffffffffffffff',
            'ffffffffffffffffffffffffffe016929092016040019392505050565b600060',
            '20828403121561088057600080fd5b81517fffffffff00000000000000000000',
            '000000000000000000000000000000000000811681146105b057600080fdfea1',
            '64736f6c634300080d000a820a97a0f3e330ca248c04b5d26167edd2c5038b39',
            '8fadaee31b34e4e4493ee3f6179b9ea01dee0bb2da2e9ce6a3ac21f2cb0b9c5d',
            'e5e12010ef3aaaa70bd9333a5cdcf27e',
          ].join('')
        );
        // enable deployer on localhost
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a6018082c350949f69aefbb4418a1b4642116b5c8c2b30896019a880b844a0',
            '7d7316000000000000000000000000df5295149f367b1fbfd595bda578bad22e',
            '59f5040000000000000000000000000000000000000000000000000000000000',
            '000001820a97a0ed915922250469c5f77eaef34df5d6810c23a194a1559c1d0b',
            'ccc74d7fcef81da029dfac51841f58930c64d19514d22816b864b88dd0458937',
            'a1ae6cd461d763dc',
          ].join('')
        );
        // enable testnet deployer on localhost
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a6028082c350949f69aefbb4418a1b4642116b5c8c2b30896019a880b844a0',
            '7d73160000000000000000000000009e22aa58bf2f5e60801b90fdd3b51b65d3',
            '8ea20b0000000000000000000000000000000000000000000000000000000000',
            '000001820a98a044e6c6e87b206fc294a2d971a98346ca1328c780596b91efb5',
            '2ea2e9387ff8c0a042e37064b2459414fb6d990c9397d5d9791ed706aa7520b3',
            '564839ba99358c83',
          ].join('')
        );
      } else if (hre.networkName == 'localhost2') {
        // deploy HolographGenesis on localhost2
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f909ad8080830aae608080b9095d608060405234801561001057600080fd5b50',
            '3260009081526020819052604090819020805460ff19166001179055517f51a7',
            'f65c6325882f237d4aeb43228179cfad48b868511d508e24b4437a8191379061',
            '0089906020808252818101527f54686520667574757265206f66204e46547320',
            '697320486f6c6f67726170682e604082015260600190565b60405180910390a1',
            '6108bd806100a06000396000f3fe608060405234801561001057600080fd5b50',
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
            '019061041d919061086e565b7fffffffff000000000000000000000000000000',
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
            '08285785810183015185820160400152820161080c565b8181111561083a5760',
            '00604083870101525b50601f017fffffffffffffffffffffffffffffffffffff',
            'ffffffffffffffffffffffffffe016929092016040019392505050565b600060',
            '20828403121561088057600080fd5b81517fffffffff00000000000000000000',
            '000000000000000000000000000000000000811681146105b057600080fdfea1',
            '64736f6c634300080d000a820a99a08171f54150d81230716b6ecf1bac659a25',
            '716068feb2a3e51308454748ef47b5a00a1ac7967e2f480e1e07661365a12ad1',
            '4a37df62a0303a62420f59f0dd408ca8',
          ].join('')
        );
        // enable deployer on localhost2
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a6018082c350949f69aefbb4418a1b4642116b5c8c2b30896019a880b844a0',
            '7d7316000000000000000000000000df5295149f367b1fbfd595bda578bad22e',
            '59f5040000000000000000000000000000000000000000000000000000000000',
            '000001820a9aa0b5c51112398948574b7d601af0037f1a4274fe32f9d66ba7d1',
            '0e38502e98e120a013a8ed83f7d8a8160e7e8cc0d0087ece239a18842c613fcc',
            'c6a473c44784280d',
          ].join('')
        );
        // enable testnet deployer on localhost2
        await hre.ethers.provider.sendTransaction(
          [
            '0x',
            'f8a6028082c350949f69aefbb4418a1b4642116b5c8c2b30896019a880b844a0',
            '7d73160000000000000000000000009e22aa58bf2f5e60801b90fdd3b51b65d3',
            '8ea20b0000000000000000000000000000000000000000000000000000000000',
            '000001820a99a0121645b6da705a49bc61e0c9c4b20a95487223e01bc5e722bb',
            '217974d08d7ac9a051ca41946667d51c3b17c2e3ad3661d73353d57e2ed6de9e',
            'f864200124de970f',
          ].join('')
        );
      }
    }
  }
  if (holographGenesisContract == null && holographGenesisDeployment == null) {
    let holographGenesis = await deploy('HolographGenesis', {
      from: deployer,
      args: [],
      log: true,
      waitConfirmations: 1,
      nonce: await hre.ethers.provider.getTransactionCount(deployer),
    });
  }
};

export default func;
func.tags = ['HolographGenesis'];
func.dependencies = [];
