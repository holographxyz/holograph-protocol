// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IFeeRouter.sol";
import "../src/interfaces/IAirlock.sol";

/**
 * @title KeeperPullAndBridge
 * @notice Automation script for fee collection and bridging operations
 * @dev Production-ready keeper bot for automated fee processing across chains
 *
 * Usage:
 *   1. Deploy: Update FEE_ROUTER address and known Airlock addresses
 *   2. Setup: Run setupTrustedAirlocks() once to whitelist Airlocks
 *   3. Monitor: Use checkBalances() to verify configuration
 *   4. Automate: Run run() periodically for fee collection and bridging
 *   5. Emergency: Use emergencyPause() to halt operations if needed
 *
 * @author Holograph Protocol
 */
contract KeeperPullAndBridge is Script {
    /* -------------------------------------------------------------------------- */
    /*                                Addresses                                   */
    /* -------------------------------------------------------------------------- */

    // TODO: Update with actual deployed addresses before production use
    // Set via environment variables: FEEROUTER_ADDRESS
    /// @notice FeeRouter contract address for fee processing
    IFeeRouter constant FEE_ROUTER = IFeeRouter(0x742D35cC6634C0532925a3b8D4014dd1C4D9dC07);

    // Base mainnet token addresses
    /// @notice USDC token address on Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /// @notice WETH token address on Base
    address constant WETH = 0x4200000000000000000000000000000000000006;

    /// @notice DAI token address on Base
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;

    /* -------------------------------------------------------------------------- */
    /*                                  Main                                      */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Main execution function for keeper automation
     * @dev Sequentially executes fee pulling, ETH bridging, and token bridging (≈500k–1M gas depending on workload)
     */
    function run() external {
        _validateSetup();

        vm.startBroadcast();

        console.log("Starting keeper run...");

        _pullFees();
        _bridgeETH();
        _bridgeTokens();

        console.log("Keeper run completed");
        vm.stopBroadcast();
    }

    /**
     * @notice Setup function for initial deployment - whitelist trusted Airlocks
     * @dev Owner-only function to configure trusted Airlock contracts
     */
    function setupTrustedAirlocks() external {
        vm.startBroadcast();

        console.log("Setting up trusted Airlocks...");

        address[] memory airlocks = _getKnownAirlocks();
        for (uint i = 0; i < airlocks.length; i++) {
            if (airlocks[i] != address(0)) {
                try FEE_ROUTER.setTrustedAirlock(airlocks[i], true) {
                    console.log("Whitelisted Airlock:", airlocks[i]);
                } catch {
                    console.log("Failed to whitelist Airlock:", airlocks[i]);
                }
            }
        }

        console.log("Trusted Airlock setup completed");
        vm.stopBroadcast();
    }

    /**
     * @notice Emergency function to pause FeeRouter operations
     * @dev Owner-only emergency control
     */
    function emergencyPause() external {
        vm.startBroadcast();
        console.log("EMERGENCY: Pausing FeeRouter operations");

        try FEE_ROUTER.pause() {
            console.log("FeeRouter successfully paused");
        } catch {
            console.log("Failed to pause FeeRouter - check permissions");
        }

        vm.stopBroadcast();
    }

    /* -------------------------------------------------------------------------- */
    /*                               Internal                                     */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Pull fees from all known Airlock contracts
     * @dev Iterates through configured Airlocks and attempts fee collection
     */
    function _pullFees() internal {
        console.log("Pulling fees from Airlock contracts...");

        // Add actual airlock addresses and amounts based on monitoring
        address[] memory airlocks = _getKnownAirlocks();

        for (uint i = 0; i < airlocks.length; i++) {
            _pullFromAirlock(airlocks[i]);
        }
    }

    /**
     * @notice Pull fees from a specific Airlock contract
     * @dev Attempts to pull both ETH and token fees with error handling
     * @param airlock Address of the Airlock contract to pull from
     */
    function _pullFromAirlock(address airlock) internal {
        // Pull ETH fees
        try FEE_ROUTER.collectAirlockFees(airlock, address(0), 0.01 ether) {
            console.log("Pulled ETH from airlock:", airlock);
        } catch {
            // Continue on failure
        }

        // Pull token fees
        address[] memory tokens = _getKnownTokens();
        for (uint i = 0; i < tokens.length; i++) {
            try FEE_ROUTER.collectAirlockFees(airlock, tokens[i], _getMinAmount(tokens[i])) {
                console.log("Pulled token from airlock:", tokens[i]);
            } catch {
                // Continue on failure
            }
        }
    }

    /**
     * @notice Bridge accumulated ETH to Ethereum for HLG conversion
     * @dev Only bridges if balance exceeds minimum threshold
     */
    function _bridgeETH() internal {
        uint256 balance = address(FEE_ROUTER).balance;
        if (balance >= 0.01 ether) {
            try FEE_ROUTER.bridge(200_000, 0) {
                console.log("Bridged ETH:", balance);
            } catch {
                console.log("ETH bridge failed");
            }
        }
    }

    /**
     * @notice Bridge accumulated tokens to Ethereum
     * @dev Attempts to bridge all configured token types
     */
    function _bridgeTokens() internal {
        address[] memory tokens = _getKnownTokens();

        for (uint i = 0; i < tokens.length; i++) {
            try FEE_ROUTER.bridgeERC20(tokens[i], 200_000, 0) {
                console.log("Bridged token:", tokens[i]);
            } catch {
                // Continue on failure
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Config                                    */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Get list of known Airlock contracts for fee collection
     * @dev Update this function with actual Airlock addresses from monitoring
     * @return airlocks Array of Airlock contract addresses
     */
    function _getKnownAirlocks() internal pure returns (address[] memory) {
        address[] memory airlocks = new address[](0);
        // TODO: Add actual airlock addresses from monitoring
        // Example:
        // airlocks = new address[](2);
        // airlocks[0] = 0x1234...;
        // airlocks[1] = 0x5678...;
        return airlocks;
    }

    /**
     * @notice Get list of supported tokens for fee collection
     * @dev Configured for Base mainnet token addresses
     * @return tokens Array of ERC-20 token addresses
     */
    function _getKnownTokens() internal pure returns (address[] memory) {
        address[] memory tokens = new address[](3);
        tokens[0] = USDC;
        tokens[1] = WETH;
        tokens[2] = DAI;
        return tokens;
    }

    /**
     * @notice Get minimum amount for pulling specific tokens
     * @dev Configured to avoid dust transactions and gas waste
     * @param token Token address to get minimum amount for
     * @return Minimum amount in token's native decimals
     */
    function _getMinAmount(address token) internal pure returns (uint256) {
        if (token == USDC) return 100e6; // 100 USDC
        if (token == WETH) return 0.01 ether;
        if (token == DAI) return 100e18; // 100 DAI
        return 1e18; // Default 1 token
    }

    /**
     * @notice Validate environment setup before execution
     * @dev Ensures required addresses are configured properly and Airlocks are whitelisted
     */
    function _validateSetup() internal view {
        require(address(FEE_ROUTER) != address(0), "FeeRouter address not set");

        // Check if we're using placeholder address (should be updated for production)
        if (address(FEE_ROUTER) == 0x742D35cC6634C0532925a3b8D4014dd1C4D9dC07) {
            console.log("WARNING: Using placeholder FeeRouter address");
        }

        // Validate that known Airlocks are whitelisted
        address[] memory airlocks = _getKnownAirlocks();
        for (uint i = 0; i < airlocks.length; i++) {
            if (airlocks[i] != address(0)) {
                if (!FEE_ROUTER.trustedAirlocks(airlocks[i])) {
                    console.log("WARNING: Airlock not whitelisted:", airlocks[i]);
                    console.log("Run setupTrustedAirlocks() first");
                }
            }
        }
    }

    /**
     * @notice Monitor function to check FeeRouter balances and trusted Airlocks
     * @dev Useful for debugging and monitoring keeper performance
     */
    function checkBalances() external view {
        console.log("=== FeeRouter Status Check ===");
        console.log("FeeRouter Address:", address(FEE_ROUTER));
        console.log("ETH Balance:", address(FEE_ROUTER).balance);

        // Check trusted Airlock status
        address[] memory airlocks = _getKnownAirlocks();
        console.log("=== Trusted Airlock Status ===");
        for (uint i = 0; i < airlocks.length; i++) {
            if (airlocks[i] != address(0)) {
                bool trusted = FEE_ROUTER.trustedAirlocks(airlocks[i]);
                console.log("Airlock:", airlocks[i], "Trusted:", trusted);
            }
        }

        // Check ERC-20 balances
        console.log("=== Token Balances ===");
        address[] memory tokens = _getKnownTokens();
        for (uint i = 0; i < tokens.length; i++) {
            // Note: Would need to add IERC20 interface calls for actual balance checks
            console.log("Token:", tokens[i]);
        }
    }
}
