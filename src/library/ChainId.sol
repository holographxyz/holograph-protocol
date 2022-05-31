/*HOLOGRAPH_LICENSE_HEADER*/

/*SOLIDITY_COMPILER_VERSION*/

library ChainId {
  function hlg2evm(uint32 hlgChainId) internal pure returns (uint256 evmChainId) {
    assembly {
      switch hlgChainId
      // eth
      case 1 {
        evmChainId := 1
      }
      // bsc
      case 2 {
        evmChainId := 56
      }
      // avalanche
      case 3 {
        evmChainId := 43114
      }
      // polygon
      case 4 {
        evmChainId := 137
      }
      // arbitrum
      case 6 {
        evmChainId := 42161
      }
      // optimism
      case 7 {
        evmChainId := 10
      }
      // fantom
      case 5 {
        evmChainId := 250
      }
      // rinkeby
      case 4000000001 {
        evmChainId := 4
      }
      // bsc testnet
      case 4000000002 {
        evmChainId := 97
      }
      // fuji
      case 4000000003 {
        evmChainId := 43113
      }
      // mumbai
      case 4000000004 {
        evmChainId := 80001
      }
      // arbitrum rinkeby
      case 4000000006 {
        evmChainId := 421611
      }
      // optimism kovan
      case 4000000007 {
        evmChainId := 69
      }
      // fantom testnet
      case 4000000005 {
        evmChainId := 4002
      }
      // local2
      case 4294967294 {
        evmChainId := 1338
      }
      // local
      case 4294967295 {
        evmChainId := 1339
      }
      default {
        evmChainId := 0
      }
    }
  }

  function evm2hlg(uint256 evmChainId) internal pure returns (uint32 hlgChainId) {
    assembly {
      switch evmChainId
      // eth
      case 1 {
        hlgChainId := 1
      }
      // bsc
      case 56 {
        hlgChainId := 2
      }
      // avalanche
      case 43114 {
        hlgChainId := 3
      }
      // polygon
      case 137 {
        hlgChainId := 4
      }
      // arbitrum
      case 42161 {
        hlgChainId := 6
      }
      // optimism
      case 10 {
        hlgChainId := 7
      }
      // fantom
      case 250 {
        hlgChainId := 5
      }
      // rinkeby
      case 4 {
        hlgChainId := 4000000001
      }
      // bsc testnet
      case 97 {
        hlgChainId := 4000000002
      }
      // fuji
      case 43113 {
        hlgChainId := 4000000003
      }
      // mumbai
      case 80001 {
        hlgChainId := 4000000004
      }
      // arbitrum rinkeby
      case 421611 {
        hlgChainId := 4000000006
      }
      // optimism kovan
      case 69 {
        hlgChainId := 4000000007
      }
      // fantom testnet
      case 4002 {
        hlgChainId := 4000000005
      }
      // local2
      case 1338 {
        hlgChainId := 4294967294
      }
      // local
      case 1339 {
        hlgChainId := 4294967295
      }
      default {
        hlgChainId := 0
      }
    }
  }

  function lz2hlg(uint16 lzChainId) internal pure returns (uint32 hlgChainId) {
    assembly {
      switch lzChainId
      // eth
      case 1 {
        hlgChainId := 1
      }
      // bsc
      case 2 {
        hlgChainId := 2
      }
      // avalanche
      case 6 {
        hlgChainId := 3
      }
      // polygon
      case 9 {
        hlgChainId := 4
      }
      // arbitrum
      case 10 {
        hlgChainId := 6
      }
      // optimism
      case 11 {
        hlgChainId := 7
      }
      // fantom
      case 12 {
        hlgChainId := 5
      }
      // rinkeby
      case 10001 {
        hlgChainId := 4000000001
      }
      // bsc testnet
      case 10002 {
        hlgChainId := 4000000002
      }
      // fuji
      case 10006 {
        hlgChainId := 4000000003
      }
      // mumbai
      case 10009 {
        hlgChainId := 4000000004
      }
      // arbitrum rinkeby
      case 10010 {
        hlgChainId := 4000000006
      }
      // optimism kovan
      case 10011 {
        hlgChainId := 4000000007
      }
      // fantom testnet
      case 10012 {
        hlgChainId := 4000000005
      }
      // local2
      case 65534 {
        hlgChainId := 4294967294
      }
      // local
      case 65535 {
        hlgChainId := 4294967295
      }
      default {
        hlgChainId := 0
      }
    }
  }

  function hlg2lz(uint32 hlgChainId) internal pure returns (uint16 lzChainId) {
    assembly {
      switch hlgChainId
      // eth
      case 1 {
        lzChainId := 1
      }
      // bsc
      case 2 {
        lzChainId := 2
      }
      // avalanche
      case 3 {
        lzChainId := 6
      }
      // polygon
      case 4 {
        lzChainId := 9
      }
      // fantom
      case 5 {
        lzChainId := 12
      }
      // arbitrum
      case 6 {
        lzChainId := 10
      }
      // optimism
      case 7 {
        lzChainId := 11
      }
      // rinkeby
      case 4000000001 {
        lzChainId := 10001
      }
      // bsc testnet
      case 4000000002 {
        lzChainId := 10002
      }
      // fuji
      case 4000000003 {
        lzChainId := 10006
      }
      // mumbai
      case 4000000004 {
        lzChainId := 10009
      }
      // fantom testnet
      case 4000000005 {
        lzChainId := 10012
      }
      // arbitrum rinkeby
      case 4000000006 {
        lzChainId := 10010
      }
      // optimism kovan
      case 4000000007 {
        lzChainId := 10011
      }
      // local2
      case 4294967294 {
        lzChainId := 65534
      }
      // local
      case 4294967295 {
        lzChainId := 65535
      }
      default {
        lzChainId := 0
      }
    }
  }

  function syn2hlg(uint32 synChainId) internal pure returns (uint32 hlgChainId) {
    return synChainId;
  }

  function hlg2syn(uint32 hlgChainId) internal pure returns (uint32 synChainId) {
    return hlgChainId;
  }
}
