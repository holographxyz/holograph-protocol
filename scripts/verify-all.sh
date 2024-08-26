#!/bin/bash

# List of networks
networks=(
    "arbitrumTestnetSepolia"
    "avalancheTestnet"
    "baseTestnetSepolia"
    "binanceSmartChainTestnet"
    "ethereumTestnetSepolia"
    "lineaTestnetGoerli"
    "mantleTestnet"
    "optimismTestnetSepolia"
    "polygonTestnet"
    "zoraTestnetSepolia"
)

# Loop through each network and run the command
for network in "${networks[@]}"; do
    echo "Running command for network: $network"
    npx hardhat deploy --network "$network" --tags Verify --no-compile
done
