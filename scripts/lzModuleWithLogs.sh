#!/bin/bash

# Capture all the arguments passed to the script
ARGS="$@"

# Colors variables
YELLOW='\033[0;33m'
RESET='\033[0m'


# Function to print logs based on the --sig argument
print_logs() {
  # If --sig is equal to "mintAndBridgeOut(uint256,uint256)", print the mintAndBridgeOut logs
  if [[ $ARGS == *"mintAndBridgeOut(uint256,uint256)"* ]]; then
    printf "\n🕒 ${YELLOW}Waiting for LayerZero${RESET} to index the cross-chain message... 🕒\n\n"
  fi

  # Run the forge command with the passed arguments
  forge script --rpc-url $RPC_URL -vv --via-ir --ffi scripts/foundry/LogModule.s.sol:LogModuleScript $ARGS

  # Run the script to execute the job on the destination chain
  if [[ $ARGS == *"mintAndBridgeOut(uint256,uint256)"* ]]; then
    # Get the first argument from the ARGS variable
    SOURCE_CHAIN=$(echo $ARGS | cut -d' ' -f1)
    # Get the second argument from the ARGS variable
    DESTINATION_CHAIN=$(echo $ARGS | cut -d' ' -f2)
    forge script --rpc-url $RPC_URL -vv --via-ir --ffi scripts/foundry/LayerZeroModuleV2.s.sol:LayerZeroModuleV2Script $SOURCE_CHAIN $DESTINATION_CHAIN --sig "executeJobWithPrompt(uint256,uint256)"
  fi
}

# Load environment variables from .env
source .env

# Run the forge command with the passed arguments
forge script --rpc-url $RPC_URL --broadcast --verify -vv --via-ir scripts/foundry/LayerZeroModuleV2.s.sol:LayerZeroModuleV2Script $ARGS

# If the forge command succeeded, call the log function
if [ $? -eq 0 ]; then
  print_logs
else
  printf "\x1b[31mThe forge command failed...\x1b[0m"
fi
