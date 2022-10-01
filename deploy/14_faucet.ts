declare var global: any
import { DeployFunction } from '@holographxyz/hardhat-deploy-holographed/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import Web3 from 'web3'
import networks from '../config/networks'
import {
  generateInitCode,
  genesisDeriveFutureAddress, hreSplit,
  zeroAddress
} from '../scripts/utils/helpers'
import { HolographFactory } from '../typechain-types/HolographFactory'
import { HolographFactoryProxy } from '../typechain-types/HolographFactoryProxy'
import { HolographRegistry } from '../typechain-types/HolographRegistry'
import { HolographRegistryProxy } from '../typechain-types/HolographRegistryProxy'
import { SampleERC20 } from '../typechain-types/SampleERC20'

const func: DeployFunction = async function (hre1: HardhatRuntimeEnvironment) {

  // Boilerplate

  let { hre, hre2 } = await hreSplit(hre1, global.__companionNetwork)
  const accounts = await hre.ethers.getSigners()
  const deployer = accounts[0]

  const network = networks[hre.networkName]

  const web3 = new Web3()

  const error = function (err: string) {
    hre.deployments.log(err)
    process.exit()
  }

  const salt = hre.deploymentSalt

  const holographFactoryProxy = await hre.ethers.getContract<HolographFactoryProxy>('HolographFactoryProxy')
  const holographFactory = await hre.ethers.getContract<HolographFactory>('HolographFactory')
  holographFactory.attach(holographFactoryProxy.address)

  const holographRegistryProxy = await hre.ethers.getContract<HolographRegistryProxy>('HolographRegistryProxy')
  const holographRegistry = await hre.ethers.getContract<HolographRegistry>('HolographRegistry')
  holographRegistry.attach(holographRegistryProxy.address)

  const chainId = '0x' + network.holographId.toString(16).padStart(8, '0')

  // Get SampleERC20 Contract

  let sampleErc20Address = await (await hre.ethers.getContract<SampleERC20>('SampleERC20')).address
  if (sampleErc20Address == zeroAddress()) throw 'SampleERC20 is not deployed' // TODO ¯\_(ツ)_/¯
  hre.deployments.log('reusing "SampleERC20" at:', sampleErc20Address)

  // Deploy Faucet Contract

  const futureFaucetAddress = await genesisDeriveFutureAddress(
    hre,
    salt,
    'Faucet',
    generateInitCode(['address', 'address'], [deployer.address, sampleErc20Address])
  )
  hre.deployments.log('the future "Faucet" address is', futureFaucetAddress)

  const faucetHash = '0x' + web3.utils.asciiToHex('Faucet').substring(2).padStart(64, '0')
  if ((await holographRegistry.getContractTypeAddress(faucetHash)) != futureFaucetAddress) {
    const faucetTx = await holographRegistry
      .setContractTypeAddress(faucetHash, futureFaucetAddress, {
        nonce: await hre.ethers.provider.getTransactionCount(deployer.address),
      })
      .catch(error)
    hre.deployments.log('Transaction hash:', faucetTx.hash)
    await faucetTx.wait()
    hre.deployments.log(`Registered "Faucet" to: ${await holographRegistry.getContractTypeAddress(faucetHash)}`)
  } else {
    hre.deployments.log('"Faucet" is already registered')
  }

}

export default func
func.tags = ['Faucet']
func.dependencies = [
  'SampleERC20',
]
