#!bin/bash

source .env

OPSEPOLIA_V2ENDPOINT=0x6EDCE65403992e310A62460808c4b910D972f10f

echo "Setting the endpoint of the OptimismSePoliaV2 module to $OPSEPOLIA_V2ENDPOINT"
echo "Current endpoint:"
cast call $LZ_MODULE_V2 "getLZEndpoint()" --rpc-url $OPTIMISM_TESTNET_SEPOLIA_RPC_URL 
cast send $LZ_MODULE_V2 --private-key $DEPLOYER "setLZEndpoint(address)" $OPSEPOLIA_V2ENDPOINT --rpc-url $OPTIMISM_TESTNET_SEPOLIA_RPC_URL 

echo "New endpoint:"
cast call $LZ_MODULE_V2 "getLZEndpoint()" --rpc-url $OPTIMISM_TESTNET_SEPOLIA_RPC_URL 