#!/bin/bash

# Default network is mainnet
network="mainnet"

# Check if the last argument is --testnet
if [[ "${@: -1}" == "--testnet" ]]; then
  network="testnet"
  # Remove the last argument (the --testnet flag) from the argument list
  set -- "${@:1:$#-1}"
fi

# Check if a txHash is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <txHash> [--testnet]"
  exit 1
fi

# Assign the txHash from the command-line argument
txHash=$1

# Set the URL based on the selected network (mainnet or testnet)
if [ "$network" == "testnet" ]; then
  url="https://scan-testnet.layerzero-api.com/v1/messages/tx/$txHash"
else
  url="https://scan.layerzero-api.com/v1/messages/tx/$txHash"
fi

# Make the API request using curl
response=$(curl -s "$url")

# Print the API response
echo "$response"
