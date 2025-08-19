// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IFeeRouter.sol";
import "../src/interfaces/IAirlock.sol";

/**
 * @title FeeOperations
 * @notice Owner-only operations script for fee collection and cross-chain bridging
 * @dev Automated script for FeeRouter operations - replaces old keeper-based system
 *
 * Usage:
 *   1. Setup: Update FEE_ROUTER address with deployed contract
 *   2. Configure: Run setupTrustedAirlocks() to whitelist Doppler Airlocks
 *   3. Monitor: Use checkSystemStatus() to verify configuration
 *   4. Collect: Run collectFees() to collect from all known Airlocks
 *   5. Bridge: Run bridgeToEthereum() to send accumulated fees cross-chain
 *   6. Complete: Run fullFeeProcessing() for end-to-end automation
 *
 * @author Holograph Protocol
 */
contract FeeOperations is Script {
    /* -------------------------------------------------------------------------- */
    /*                                Addresses                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice FeeRouter contract address - UPDATE WITH ACTUAL DEPLOYMENT
    /// @dev This address must be updated after FeeRouter deployment
    /// TODO: Replace with actual deployed FeeRouter address
    IFeeRouter constant FEE_ROUTER = IFeeRouter(0x0000000000000000000000000000000000000000);

    // Base mainnet known token addresses for fee collection
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;

    /* -------------------------------------------------------------------------- */
    /*                             Main Operations                                */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Complete fee processing workflow (collect + bridge)
     * @dev Owner-only operation that executes full fee collection and bridging cycle
     */
    function fullFeeProcessing() external {
        console.log("=== Starting Full Fee Processing ===");
        _validateOwnership();

        vm.startBroadcast();

        // Step 1: Collect fees from all known Airlocks
        _collectAllFees();

        // Step 2: Bridge ETH to Ethereum for HLG conversion
        _bridgeETH();

        // Step 3: Bridge accumulated tokens
        _bridgeTokens();

        console.log("=== Fee Processing Complete ===");
        vm.stopBroadcast();
    }

    /**
     * @notice Collect fees from all configured Doppler Airlocks
     * @dev Owner-only function to collect integrator fees from completed auctions
     */
    function collectFees() external {
        console.log("=== Collecting Fees from Airlocks ===");
        _validateOwnership();

        vm.startBroadcast();
        _collectAllFees();
        vm.stopBroadcast();
    }

    /**
     * @notice Bridge accumulated funds to Ethereum for HLG operations
     * @dev Owner-only function for cross-chain fee bridging
     */
    function bridgeToEthereum() external {
        console.log("=== Bridging Fees to Ethereum ===");
        _validateOwnership();

        vm.startBroadcast();
        _bridgeETH();
        _bridgeTokens();
        vm.stopBroadcast();
    }

    /* -------------------------------------------------------------------------- */
    /*                            Setup & Configuration                          */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Initial setup - authorize known Doppler Airlocks
     * @dev Owner-only setup function to configure trusted Airlock contracts
     */
    function setupTrustedAirlocks() external {
        console.log("=== Setting up Trusted Airlocks ===");
        _validateOwnership();

        vm.startBroadcast();

        address[] memory airlocks = _getKnownAirlocks();
        for (uint256 i = 0; i < airlocks.length; i++) {
            if (airlocks[i] != address(0)) {
                try FEE_ROUTER.setTrustedAirlock(airlocks[i], true) {
                    console.log(">> Authorized Airlock:", airlocks[i]);
                } catch {
                    console.log("!! Failed to authorize Airlock:", airlocks[i]);
                }
            }
        }

        console.log("=== Airlock Setup Complete ===");
        vm.stopBroadcast();
    }

    /**
     * @notice Emergency treasury redirection (no pause functionality available)
     * @dev Owner-only emergency control via treasury address update
     * @param emergencyTreasury New treasury address to redirect fees
     */
    function emergencyRedirect(address emergencyTreasury) external {
        console.log("=== EMERGENCY: Redirecting Treasury ===");
        _validateOwnership();

        vm.startBroadcast();

        try FEE_ROUTER.setTreasury(emergencyTreasury) {
            console.log(">> Treasury redirected to:", emergencyTreasury);
            console.log("All new fees will go to emergency address");
        } catch {
            console.log("!! Failed to redirect treasury");
        }

        vm.stopBroadcast();
    }

    /* -------------------------------------------------------------------------- */
    /*                               Monitoring                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Monitor FeeRouter system status and balances
     * @dev View-only function for system monitoring and debugging
     */
    function checkSystemStatus() external view {
        console.log("=== FeeRouter System Status ===");
        console.log("FeeRouter Address:", address(FEE_ROUTER));

        // Get current balances
        (uint256 ethBalance, uint256 hlgBalance) = FEE_ROUTER.getBalances();
        console.log("ETH Balance:", ethBalance);
        console.log("HLG Balance:", hlgBalance);

        // Check fee configuration
        (uint256 protocolFee, uint256 treasuryFee) = FEE_ROUTER.calculateFeeSplit(1 ether);
        console.log("Protocol Fee (50%):", protocolFee);
        console.log("Treasury Fee (50%):", treasuryFee);

        // Check trusted Airlock status
        console.log("=== Trusted Airlock Status ===");
        address[] memory airlocks = _getKnownAirlocks();
        for (uint256 i = 0; i < airlocks.length; i++) {
            if (airlocks[i] != address(0)) {
                bool trusted = FEE_ROUTER.trustedAirlocks(airlocks[i]);
                console.log("Airlock:", airlocks[i], "Trusted:", trusted);
            }
        }

        console.log("=== Status Check Complete ===");
    }

    /**
     * @notice Check if minimum bridging thresholds are met
     * @dev View-only function to determine if bridging should be executed
     */
    function shouldBridge() external view returns (bool) {
        (uint256 ethBalance,) = FEE_ROUTER.getBalances();
        return ethBalance >= 0.01 ether; // MIN_BRIDGE_VALUE
    }

    /* -------------------------------------------------------------------------- */
    /*                              Internal Logic                               */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Collect fees from all known Doppler Airlocks
     * @dev Attempts collection from each Airlock with error handling
     */
    function _collectAllFees() internal {
        console.log("Collecting fees from Doppler Airlocks...");

        address[] memory airlocks = _getKnownAirlocks();
        uint256 successCount = 0;

        for (uint256 i = 0; i < airlocks.length; i++) {
            if (_collectFromAirlock(airlocks[i])) {
                successCount++;
            }
        }

        console.log("Fee collection completed. Success:", successCount, "of", airlocks.length);
    }

    /**
     * @notice Collect fees from a specific Doppler Airlock
     * @dev Attempts to collect both ETH and token fees with error handling
     * @param airlock Address of the Airlock contract
     * @return success Whether collection was successful
     */
    function _collectFromAirlock(address airlock) internal returns (bool success) {
        if (airlock == address(0)) return false;

        // Collect ETH fees
        try FEE_ROUTER.collectAirlockFees(airlock, address(0), 0.01 ether) {
            console.log(">> Collected ETH from:", airlock);
            success = true;
        } catch {
            console.log("?? No ETH fees available from:", airlock);
        }

        // Collect token fees
        address[] memory tokens = _getSupportedTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            try FEE_ROUTER.collectAirlockFees(airlock, tokens[i], _getMinAmount(tokens[i])) {
                console.log(">> Collected", _getTokenSymbol(tokens[i]), "from:", airlock);
                success = true;
            } catch {
                // Silent failure for tokens - most Airlocks won't have all tokens
            }
        }
    }

    /**
     * @notice Bridge accumulated ETH to Ethereum for HLG conversion
     * @dev Only bridges if balance exceeds minimum threshold
     */
    function _bridgeETH() internal {
        (uint256 balance,) = FEE_ROUTER.getBalances();

        if (balance >= 0.01 ether) {
            try FEE_ROUTER.bridge(200_000, 0) {
                console.log(">> Bridged ETH to Ethereum:", balance);
            } catch {
                console.log("!! ETH bridge failed - check configuration");
            }
        } else {
            console.log("?? ETH balance below bridging threshold:", balance);
        }
    }

    /**
     * @notice Bridge accumulated tokens to Ethereum
     * @dev Attempts bridging for all supported token types
     */
    function _bridgeTokens() internal {
        address[] memory tokens = _getSupportedTokens();

        for (uint256 i = 0; i < tokens.length; i++) {
            try FEE_ROUTER.bridgeToken(tokens[i], 200_000, 0) {
                console.log(">> Bridged", _getTokenSymbol(tokens[i]), "to Ethereum");
            } catch {
                // Silent failure - most tokens won't have balances to bridge
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              Configuration                                 */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Get list of known Doppler Airlock contracts
     * @dev Update this array as new Airlocks are deployed through Doppler
     * @return airlocks Array of Airlock contract addresses
     */
    function _getKnownAirlocks() internal pure returns (address[] memory) {
        // TODO: Update with actual deployed Doppler Airlock addresses
        address[] memory airlocks = new address[](1);

        // Placeholder - replace with real Doppler Airlock addresses
        airlocks[0] = 0x742D35cC6634C0532925a3b8D4014dd1C4D9dC07;

        // Add more as Airlocks are deployed:
        // airlocks[1] = 0x...;
        // airlocks[2] = 0x...;

        return airlocks;
    }

    /**
     * @notice Get list of supported tokens for fee collection
     * @dev Base mainnet token addresses
     * @return tokens Array of ERC20 token addresses
     */
    function _getSupportedTokens() internal pure returns (address[] memory) {
        address[] memory tokens = new address[](3);
        tokens[0] = USDC;
        tokens[1] = WETH;
        tokens[2] = DAI;
        return tokens;
    }

    /**
     * @notice Get minimum collection amount for specific tokens
     * @dev Prevents dust transactions and wasted gas
     * @param token Token address to check
     * @return Minimum amount in token's native decimals
     */
    function _getMinAmount(address token) internal pure returns (uint256) {
        if (token == USDC) return 100e6; // 100 USDC
        if (token == WETH) return 0.01 ether; // 0.01 WETH
        if (token == DAI) return 100e18; // 100 DAI
        return 1e18; // Default 1 token
    }

    /**
     * @notice Get token symbol for logging
     * @param token Token address
     * @return Symbol string for display
     */
    function _getTokenSymbol(address token) internal pure returns (string memory) {
        if (token == USDC) return "USDC";
        if (token == WETH) return "WETH";
        if (token == DAI) return "DAI";
        return "TOKEN";
    }

    /**
     * @notice Validate that caller will be contract owner
     * @dev Ensures only owner can execute operations
     */
    function _validateOwnership() internal view {
        require(address(FEE_ROUTER) != address(0), "FeeRouter address not configured - update with deployed address");

        console.log("Using FeeRouter at:", address(FEE_ROUTER));
        console.log("Operations will be executed by contract owner");

        // Note: Actual ownership validation happens in FeeRouter.onlyOwner modifier
    }
}
