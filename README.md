# Holograph Bridge Protocol

```
                         ┌───────────┐
                         │ HOLOGRAPH │
                         └───────────┘
╔═════════════════════════════════════════════════════════════╗
║                                                             ║
║                            / ^ \                            ║
║                            ~~*~~            ¸               ║
║                         [ '<>:<>' ]         │░░░            ║
║               ╔╗           _/"\_           ╔╣               ║
║             ┌─╬╬─┐          """          ┌─╬╬─┐             ║
║          ┌─┬┘ ╠╣ └┬─┐       \_/       ┌─┬┘ ╠╣ └┬─┐          ║
║       ┌─┬┘ │  ╠╣  │ └┬─┐           ┌─┬┘ │  ╠╣  │ └┬─┐       ║
║    ┌─┬┘ │  │  ╠╣  │  │ └┬─┐     ┌─┬┘ │  │  ╠╣  │  │ └┬─┐    ║
║ ┌─┬┘ │  │  │  ╠╣  │  │  │ └┬┐ ┌┬┘ │  │  │  ╠╣  │  │  │ └┬─┐ ║
╠┬┘ │  │  │  │  ╠╣  │  │  │  │└¤┘│  │  │  │  ╠╣  │  │  │  │ └┬╣
║│  │  │  │  │  ╠╣  │  │  │  │   │  │  │  │  ╠╣  │  │  │  │  │║
╠╩══╩══╩══╩══╩══╬╬══╩══╩══╩══╩═══╩══╩══╩══╩══╬╬══╩══╩══╩══╩══╩╣
╠┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╣
║               ╠╣                           ╠╣               ║
║               ╠╣                           ╠╣               ║
║    ,          ╠╣     ,        ,'      *    ╠╣               ║
║~~~~~^~~~~~~~~┌╬╬┐~~~^~~~~~~~~^^~~~~~~~~^~~┌╬╬┐~~~~~~~^~~~~~~║
╚══════════════╩╩╩╩═════════════════════════╩╩╩╩══════════════╝
     - one protocol, one bridge = infinite possibilities -
```
## Purpose

To be shared with Coinfund as a preliminary technical review. Internal scripts have been removed.

## Codebase

This archive contains a stripped down version of our repo with the following contents.

1. `contracts`: Solidity contracts
2. `deployments`: references to our rinkeby and mumbai deployed contracts
3. `test`: test suit
4. `test_results.txt`: output from `yarn test`
5. `test_results_transactions.txt`: output from running two `ganache` instances.


## Main Contracts

1. Holographer.sol
2. HolographerERC721.sol
3. HolographRegistry.sol

## Contract Links

1. ERC721
   1. Rinkeby: https://rinkeby.etherscan.io/address/0xAA7a6a0422b2539DDB3aCBBFA8bDa5b42e8111D7
   2. Mumbai: https://mumbai.polygonscan.com/address/0xAA7a6a0422b2539DDB3aCBBFA8bDa5b42e8111D7
2. Holograph
   1. Rinkeby: https://rinkeby.etherscan.io/address/0xD11a467dF6C80835A1223473aB9A48bF72eFCF4D
   2. Mumbai https://mumbai.polygonscan.com/address/0xD11a467dF6C80835A1223473aB9A48bF72eFCF4D
3. Bridge
   1. Rinkeby: https://rinkeby.etherscan.io/address/0x6CF6D895129A8bD730cD88EfF08BbFDfCf33c163
   2. Mumbai: https://mumbai.polygonscan.com/address/0x6CF6D895129A8bD730cD88EfF08BbFDfCf33c163
