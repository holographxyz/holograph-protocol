#!bin/bash

source .env

cast send $ERC721_ADDRES --private-key $ERC721_OWNER --rpc-url $OPTIMISM_TESTNET_SEPOLIA_RPC_URL "cxipMint(uint256,uint8,string)" 0 2 "https://www.alter-a.com/wp-content/uploads/2019/07/Test-Logo-Small-Black-transparent-1.png" 