import { ethers } from 'ethers';

const abi = [
  {
    inputs: [
      {
        internalType: 'uint32',
        name: 'dstEid',
        type: 'uint32',
      },
    ],
    name: 'addressSizes',
    outputs: [
      {
        internalType: 'uint256',
        name: 'size',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
];

const provider = new ethers.providers.JsonRpcProvider(process.env.ETHEREUM_TESTNET_SEPOLIA_RPC_URL);

// The RecieveUln301 contract address
// The addresses for each network can be found here https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
const contractAddress = '0x5937A5fe272fbA38699A1b75B3439389EEFDb399';

// Define the testnet chains and their EIDs
const testnetChains = [
  { name: 'Binance Test Chain', eid: 10102 },
  { name: 'Fuji', eid: 10106 },
  { name: 'Aptos Testnet', eid: 10108 },
  { name: 'Fantom Testnet', eid: 10112 },
  { name: 'Dexalot Subnet Testnet', eid: 10118 },
  { name: 'Celo Alfajores Testnet', eid: 10125 },
  { name: 'Moonbeam Testnet', eid: 10126 },
  { name: 'Fusespark', eid: 10138 },
  { name: 'Gnosis Chiado Testnet', eid: 10145 },
  { name: 'Metis', eid: 10151 },
  { name: 'CoreDAO Testnet', eid: 10153 },
  { name: 'OKX Testnet', eid: 10155 },
  { name: 'Meter Testnet', eid: 10156 },
  { name: 'Linea Consensys zkEVM Testnet', eid: 10157 },
  { name: 'Canto Testnet', eid: 10159 },
  { name: 'Sepolia', eid: 10161 },
  { name: 'DOS Testnet', eid: 10162 },
  { name: 'Kava Testnet', eid: 10172 },
  { name: 'Tenet Testnet', eid: 10173 },
  { name: 'Blockgen Testnet', eid: 10177 },
  { name: 'Merit Circle Testnet', eid: 10178 },
  { name: 'Mantle Testnet', eid: 10181 },
  { name: 'Hubble Testnet', eid: 10182 },
  { name: 'Aavegotchi Testnet', eid: 10191 },
  { name: 'Viction Testnet', eid: 10196 },
  { name: 'Loot Testnet', eid: 10197 },
  { name: 'Telos EVM Testnet', eid: 10199 },
  { name: 'Orderly Sepolia Testnet', eid: 10200 },
  { name: 'Aurora Testnet', eid: 10201 },
  { name: 'opBNB Testnet', eid: 10202 },
  { name: 'Lif3 Testnet', eid: 10205 },
  { name: 'Astar EVM Testnet', eid: 10210 },
  { name: 'Conflux Testnet', eid: 10211 },
  { name: 'Scroll Sepolia Testnet', eid: 10214 },
  { name: 'Horizen EON Testnet', eid: 10215 },
  { name: 'XPLA Testnet', eid: 10216 },
  { name: 'Holesky', eid: 10217 },
  { name: 'Injective EVM Devnet (inEVM)', eid: 10218 },
  { name: 'Idex Testnet', eid: 10219 },
  { name: 'zKatana Astar zkEVM Testnet', eid: 10220 },
  { name: 'Manta Pacific Testnet', eid: 10221 },
  { name: 'Frame Testnet', eid: 10222 },
  { name: 'Public Goods Network Testnet', eid: 10223 },
  { name: 'PolygonCDK Testnet', eid: 10224 },
  { name: 'ShimmerEVM Testnet', eid: 10230 },
  { name: 'Arbitrum Sepolia Testnet', eid: 10231 },
  { name: 'Optimism Sepolia', eid: 10232 },
  { name: 'Rarible Testnet', eid: 10235 },
  { name: 'Tiltyard Testnet', eid: 10238 },
  { name: 'Etherlink Testnet', eid: 10239 },
  { name: 'Japan Open Chain Testnet', eid: 10242 },
  { name: 'Blast Testnet', eid: 10243 },
  { name: 'Base Sepolia', eid: 10245 },
  { name: 'Mantle Sepolia', eid: 10246 },
  { name: 'Polygon zkEVM Sepolia', eid: 10247 },
  { name: 'Zora Sepolia', eid: 10249 },
  { name: 'XAI Testnet', eid: 10251 },
  { name: 'Tangible Testnet', eid: 10252 },
  { name: 'Fraxtal Testnet', eid: 10255 },
  { name: 'Berachain Testnet', eid: 10256 },
  { name: 'Sei Testnet', eid: 10258 },
  { name: 'Mode Testnet', eid: 10260 },
  { name: 'Unreal Testnet', eid: 10262 },
  { name: 'Masa Testnet', eid: 10263 },
  { name: 'Merlin Testnet', eid: 10264 },
  { name: 'Homeverse Testnet', eid: 10265 },
  { name: 'zKatana Astar zkEVM Testnet', eid: 10266 },
  { name: 'Amoy Testnet', eid: 10267 },
  { name: 'Xlayer Testnet', eid: 10269 },
  { name: 'Form Testnet', eid: 10270 },
  { name: 'Mantasep Testnet', eid: 10272 },
  { name: 'Taiko Testnet', eid: 10274 },
  { name: 'Zircuit Testnet', eid: 10275 },
  { name: 'Camp Testnet', eid: 10276 },
  { name: 'Olive Testnet', eid: 10277 },
  { name: 'Bob Testnet', eid: 10279 },
  { name: 'Cyber Testnet', eid: 10280 },
  { name: 'Botanix Testnet', eid: 10281 },
  { name: 'Ebi Testnet', eid: 10284 },
  { name: 'Besu1 Testnet', eid: 10288 },
  { name: 'Bouncebit Testnet', eid: 10289 },
  { name: 'Morph Testnet', eid: 10290 },
  { name: 'Tron Testnet', eid: 10420 },
];

async function main() {
  const contract = new ethers.Contract(contractAddress, abi, provider);
  const supportedChains = [];
  const unsupportedChains = [];

  for (const chain of testnetChains) {
    try {
      const size = await contract.addressSizes(chain.eid);
      const isSupported = !size.isZero();
      if (isSupported) {
        supportedChains.push(`${chain.name} (EID: ${chain.eid}): Address size has been set`);
      } else {
        unsupportedChains.push(`${chain.name} (EID: ${chain.eid}): Address size has not been set`);
      }
    } catch (error) {
      console.error(`Error fetching data for ${chain.name} (EID: ${chain.eid}):`, error);
    }
  }

  console.log('Supported Chains:');
  supportedChains.forEach((message) => console.log(message));

  console.log('\n-----------------------------------\n');

  console.log('Unsupported Chains:');
  unsupportedChains.forEach((message) => console.log(message));
}

main().catch(console.error);
