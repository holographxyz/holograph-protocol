#!/bin/bash

# Capture all the arguments passed to the script
ARGS="$@"

# Function to print logs based on the --sig argument
print_logs() {
  forge script --rpc-url $RPC_URL -vv --via-ir --ffi scripts/foundry/LogModule.s.sol:LogModuleScript $ARGS
}

# Load environment variables from .env
source .env

# Execute the forge command with the passed arguments
forge script --rpc-url $RPC_URL --broadcast --verify -vv --via-ir scripts/foundry/LayerZeroModuleV2.s.sol:LayerZeroModuleV2Script $ARGS

# If the forge command succeeded, call the log function
if [ $? -eq 0 ]; then
  print_logs
else
  echo "\x1b[31mThe forge command failed, logs will not be printed.\x1b[0m"
fi
