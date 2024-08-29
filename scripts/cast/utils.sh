#!/bin/bash

source .env

# ---------------------------------------------------------------------------- #
#                              Set gas parameters                              #
# ---------------------------------------------------------------------------- #

# GasParameter ARBITRUM
# uint256 110000
# uint256 25
# uint256 160000
# uint256 25
# uint256 40000000000
# uint256 15000000

# cast send $LZ_MODULE_V2 --private-key $DEPLOYER "setGasParameters(uint32,(uint256,uint256,uint256,uint256,uint256,uint256))" 421614 '(110000,25,160000,25,40000000000,15000000)' --rpc-url $OPTIMISM_TESTNET_SEPOLIA_RPC_URL 

# ---------------------------------------------------------------------------- #
#                                 Utility calls                                #
# ---------------------------------------------------------------------------- #

cast call $OPERATOR_ADDRESS "getMessagingModule()" --rpc-url $OPTIMISM_TESTNET_SEPOLIA_RPC_URL
cast call $LZ_MODULE_V2 "getLZEndpoint()" --rpc-url $OPTIMISM_TESTNET_SEPOLIA_RPC_URL 
cast call $LZ_MODULE_V2 "admin()" --rpc-url $OPTIMISM_TESTNET_SEPOLIA_RPC_URL 
