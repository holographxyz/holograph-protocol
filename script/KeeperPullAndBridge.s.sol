// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/interfaces/IFeeRouter.sol";
import "../src/interfaces/IAirlock.sol";

/**
 * @title KeeperPullAndBridge
 * @notice Foundry script for keeper automation of fee collection and bridging
 * @dev This script should be run by keeper bots to:
 *      1. Pull accumulated fees from Doppler Airlock contracts
 *      2. Bridge ETH and tokens from Base to Ethereum
 *      3. Process fees through the single-slice model
 *
 * Usage:
 *   forge script script/KeeperPullAndBridge.s.sol \
 *     --rpc-url $BASE_RPC --broadcast --legacy \
 *     --gas-price 100000000 --private-key $KEEPER_PK
 */
contract KeeperPullAndBridge is Script {
    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    // TODO: Replace with actual deployed addresses
    IFeeRouter constant FEE_ROUTER = IFeeRouter(0x742D35cC6634C0532925a3b8D4014dd1C4D9dC07);

    // Common Airlock addresses - update with actual deployments
    address constant AIRLOCK_1 = 0x1111111111111111111111111111111111111111;
    address constant AIRLOCK_2 = 0x2222222222222222222222222222222222222222;

    // Common ERC-20 tokens on Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;

    /* -------------------------------------------------------------------------- */
    /*                                    Main                                    */
    /* -------------------------------------------------------------------------- */

    function run() external {
        vm.startBroadcast();

        console.log("Starting keeper automation...");

        // Step 1: Pull fees from known Airlock contracts
        _pullKnownFees();

        // Step 2: Bridge accumulated ETH
        _bridgeETH();

        // Step 3: Bridge accumulated tokens
        _bridgeTokens();

        console.log("Keeper automation completed");

        vm.stopBroadcast();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Logic                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Pull fees from known Airlock contracts
     * @dev Add more airlocks and tokens as needed
     */
    function _pullKnownFees() internal {
        console.log("Pulling fees from Airlock contracts...");

        // Example: Pull USDC fees from Airlock 1
        try FEE_ROUTER.pullAndSlice(AIRLOCK_1, USDC, 100e6) {
            // 100 USDC
            console.log("Pulled USDC from Airlock 1");
        } catch {
            console.log("No USDC fees in Airlock 1 or pull failed");
        }

        // Example: Pull WETH fees from Airlock 1
        try FEE_ROUTER.pullAndSlice(AIRLOCK_1, WETH, 0.1 ether) {
            console.log("Pulled WETH from Airlock 1");
        } catch {
            console.log("No WETH fees in Airlock 1 or pull failed");
        }

        // Example: Pull ETH fees from Airlock 2
        try FEE_ROUTER.pullAndSlice(AIRLOCK_2, address(0), 0.05 ether) {
            console.log("Pulled ETH from Airlock 2");
        } catch {
            console.log("No ETH fees in Airlock 2 or pull failed");
        }

        // Add more airlock pulls as needed...
    }

    /**
     * @notice Bridge accumulated ETH to Ethereum
     */
    function _bridgeETH() internal {
        console.log("Bridging ETH to Ethereum...");

        uint256 ethBalance = address(FEE_ROUTER).balance;
        console.log("FeeRouter ETH balance:", ethBalance);

        if (ethBalance >= 0.01 ether) {
            // MIN_BRIDGE_VALUE check
            try
                FEE_ROUTER.bridge(
                    200_000, // minGas for lzReceive on Ethereum
                    0 // minHlg (no slippage protection for now)
                )
            {
                console.log("ETH bridged successfully");
            } catch {
                console.log("ETH bridge failed - insufficient gas or other error");
            }
        } else {
            console.log("ETH balance below minimum bridge threshold");
        }
    }

    /**
     * @notice Bridge accumulated ERC-20 tokens to Ethereum
     */
    function _bridgeTokens() internal {
        console.log("Bridging tokens to Ethereum...");

        // Bridge USDC
        _bridgeSpecificToken(USDC, "USDC");

        // Bridge WETH
        _bridgeSpecificToken(WETH, "WETH");

        // Bridge DAI
        _bridgeSpecificToken(DAI, "DAI");
    }

    /**
     * @notice Bridge a specific token if balance is sufficient
     */
    function _bridgeSpecificToken(address token, string memory symbol) internal {
        try vm.envUint("SKIP_TOKEN_BRIDGE") returns (uint256 skip) {
            if (skip == 1) {
                console.log("Skipping token bridge for", symbol);
                return;
            }
        } catch {}

        // Note: In a real deployment, you'd need to check token balance
        // This is a simplified example
        console.log("Attempting to bridge", symbol);

        try
            FEE_ROUTER.bridgeToken(
                token,
                200_000, // minGas for lzReceive on Ethereum
                0 // minHlg (no slippage protection for now)
            )
        {
            console.log(symbol, "bridged successfully");
        } catch {
            console.log(symbol, "bridge failed - insufficient balance or error");
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Utility Views                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Check FeeRouter balances (useful for debugging)
     */
    function checkBalances() external view {
        console.log("=== FeeRouter Balances ===");
        console.log("ETH:", address(FEE_ROUTER).balance);

        // Note: For ERC-20 balances, you'd need to call the token contracts
        // This is left as an exercise for actual implementation
    }

    /**
     * @notice Emergency pause function (governance use)
     */
    function emergencyPause() external {
        console.log("EMERGENCY: Pausing FeeRouter");
        vm.startBroadcast();
        FEE_ROUTER.pause();
        vm.stopBroadcast();
    }

    /**
     * @notice Resume operations (governance use)
     */
    function unpause() external {
        console.log("Unpausing FeeRouter");
        vm.startBroadcast();
        FEE_ROUTER.unpause();
        vm.stopBroadcast();
    }
}
