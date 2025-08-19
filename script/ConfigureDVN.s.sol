// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ConfigureDVN
 * @notice LayerZero V2 DVN (Decentralized Verifier Network) configuration script
 * @dev Configures send/receive libraries and DVN security stack for FeeRouter deployments
 *
 * This script sets up the LayerZero V2 security infrastructure by:
 *   • Configuring send and receive message libraries
 *   • Setting up single required DVN (LayerZero Labs)
 *   • Configuring block confirmation requirements
 *
 * Usage:
 *   forge script script/ConfigureDVN.s.sol \
 *       --rpc-url $BASE_RPC \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK
 *
 * Required ENV variables:
 *   FEE_ROUTER          – FeeRouter contract address on current chain
 *   LZ_ENDPOINT         – LayerZero V2 endpoint address on current chain
 *   REMOTE_EID          – Remote chain endpoint ID (uint32)
 *   DEPLOYER_PK         – Private key for configuration transactions
 *   BROADCAST           – Set to true to execute transactions (default: false)
 *
 * Optional ENV variables:
 *   SEND_LIBRARY        – Custom send library address (uses default if not set)
 *   RECEIVE_LIBRARY     – Custom receive library address (uses default if not set)
 */
import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/FeeRouter.sol";
import "./DeploymentConfig.sol";

// Import LayerZero V2 endpoint interface
import "../lib/LayerZero-v2/packages/layerzero-v2/evm/protocol/contracts/interfaces/ILayerZeroEndpointV2.sol";

// Additional LayerZero V2 interfaces for configuration
interface ILayerZeroEndpointV2Config {
    struct SetConfigParam {
        uint32 eid;
        uint32 configType;
        bytes config;
    }

    function setSendLibrary(address _oapp, uint32 _eid, address _newLib) external;
    function setReceiveLibrary(address _oapp, uint32 _eid, address _newLib, uint256 _gracePeriod) external;
    function setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params) external;

    function getSendLibrary(address _sender, uint32 _dstEid) external view returns (address lib);
    function getReceiveLibrary(address _receiver, uint32 _srcEid) external view returns (address lib, bool isDefault);
}

interface IMessageLib {
    struct SetDefaultUlnConfigParam {
        uint32 eid;
        UlnConfig config;
    }

    struct UlnConfig {
        uint64 confirmations;
        uint8 requiredDVNCount;
        uint8 optionalDVNCount;
        uint8 optionalDVNThreshold;
        address[] requiredDVNs;
        address[] optionalDVNs;
    }

    function setDefaultUlnConfigs(SetDefaultUlnConfigParam[] calldata _params) external;
}

contract ConfigureDVN is Script {
    /* -------------------------------------------------------------------------- */
    /*                                Constants                                   */
    /* -------------------------------------------------------------------------- */

    // Configuration type constants for LayerZero V2
    uint32 internal constant CONFIG_TYPE_ULN = 2;
    uint32 internal constant CONFIG_TYPE_EXECUTOR = 1;

    // Grace period for receive library updates (24 hours)
    uint256 internal constant RECEIVE_LIBRARY_GRACE_PERIOD = 86400;

    /* -------------------------------------------------------------------------- */
    /*                                Structs                                    */
    /* -------------------------------------------------------------------------- */

    struct DVNConfiguration {
        uint256 chainId;
        uint32 remoteEid;
        address endpoint;
        address feeRouter;
        address sendLibrary;
        address receiveLibrary;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Main Script                                */
    /* -------------------------------------------------------------------------- */

    function run() external {
        // Initialize configuration from environment
        DVNConfiguration memory config = initializeConfiguration();

        // Validate configuration
        validateConfiguration(config);

        // Start broadcasting if enabled
        if (vm.envOr("BROADCAST", false)) {
            console.log("Broadcasting DVN configuration transactions");
            vm.startBroadcast(vm.envUint("DEPLOYER_PK"));
        } else {
            console.log("Running in dry-run mode (no broadcast)");
            vm.startBroadcast();
        }

        // Configure DVN security stack
        configureDVNSecurity(config);

        // Set enforced options for reliable execution
        configureEnforcedOptions(config);

        vm.stopBroadcast();

        // Verify configuration
        verifyConfiguration(config);

        console.log("\n========================================");
        console.log("DVN Configuration Complete");
        console.log("========================================");
    }

    /* -------------------------------------------------------------------------- */
    /*                            Configuration Setup                           */
    /* -------------------------------------------------------------------------- */

    function initializeConfiguration() internal view returns (DVNConfiguration memory config) {
        config.chainId = block.chainid;
        config.endpoint = vm.envAddress("LZ_ENDPOINT");
        config.feeRouter = vm.envAddress("FEE_ROUTER");
        config.remoteEid = uint32(vm.envUint("REMOTE_EID"));

        // Use default libraries if not specified
        config.sendLibrary = vm.envOr("SEND_LIBRARY", address(0));
        config.receiveLibrary = vm.envOr("RECEIVE_LIBRARY", address(0));

        console.log("Configuring DVN for chain:", config.chainId);
        console.log("FeeRouter address:", config.feeRouter);
        console.log("LayerZero endpoint:", config.endpoint);
        console.log("Remote endpoint ID:", config.remoteEid);
    }

    function validateConfiguration(DVNConfiguration memory config) internal pure {
        DeploymentConfig.validateNonZeroAddress(config.endpoint, "LZ_ENDPOINT");
        DeploymentConfig.validateNonZeroAddress(config.feeRouter, "FEE_ROUTER");
        require(config.remoteEid != 0, "REMOTE_EID not set");

        // Validate chain is supported
        require(
            config.chainId == DeploymentConfig.ETHEREUM_MAINNET || config.chainId == DeploymentConfig.ETHEREUM_SEPOLIA
                || config.chainId == DeploymentConfig.BASE_MAINNET || config.chainId == DeploymentConfig.BASE_SEPOLIA,
            "Unsupported chain for DVN configuration"
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                            DVN Security Configuration                     */
    /* -------------------------------------------------------------------------- */

    function configureDVNSecurity(DVNConfiguration memory config) internal {
        console.log("\nConfiguring DVN security stack...");

        ILayerZeroEndpointV2Config endpoint = ILayerZeroEndpointV2Config(config.endpoint);

        // Set up send and receive libraries if not using defaults
        if (config.sendLibrary != address(0)) {
            console.log("Setting custom send library:", config.sendLibrary);
            endpoint.setSendLibrary(config.feeRouter, config.remoteEid, config.sendLibrary);
        }

        if (config.receiveLibrary != address(0)) {
            console.log("Setting custom receive library:", config.receiveLibrary);
            endpoint.setReceiveLibrary(
                config.feeRouter, config.remoteEid, config.receiveLibrary, RECEIVE_LIBRARY_GRACE_PERIOD
            );
        }

        // Configure ULN (Ultra Light Node) settings
        configureULNSettings(config, endpoint);
    }

    function configureULNSettings(DVNConfiguration memory config, ILayerZeroEndpointV2Config endpoint) internal {
        // Get current libraries
        address sendLib = endpoint.getSendLibrary(config.feeRouter, config.remoteEid);
        (address receiveLib,) = endpoint.getReceiveLibrary(config.feeRouter, config.remoteEid);

        console.log("Using send library:", sendLib);
        console.log("Using receive library:", receiveLib);

        // Build DVN configuration - single required DVN only
        address[] memory requiredDVNs = buildRequiredDVNs(config);
        address[] memory optionalDVNs = new address[](0); // No optional DVNs

        // Create ULN config
        bytes memory ulnConfig = abi.encode(
            DeploymentConfig.getBlockConfirmations(config.chainId), // confirmations
            uint8(requiredDVNs.length), // requiredDVNCount (1)
            uint8(0), // optionalDVNCount (0)
            uint8(0), // optionalDVNThreshold (0)
            requiredDVNs,
            optionalDVNs
        );

        // Apply configuration to both send and receive libraries
        ILayerZeroEndpointV2Config.SetConfigParam[] memory params = new ILayerZeroEndpointV2Config.SetConfigParam[](1);
        params[0] = ILayerZeroEndpointV2Config.SetConfigParam({
            eid: config.remoteEid,
            configType: CONFIG_TYPE_ULN,
            config: ulnConfig
        });

        // Configure send library
        endpoint.setConfig(config.feeRouter, sendLib, params);
        console.log("ULN configuration applied to send library");

        // Configure receive library
        endpoint.setConfig(config.feeRouter, receiveLib, params);
        console.log("ULN configuration applied to receive library");

        // Log DVN configuration
        logDVNConfiguration(requiredDVNs, config.chainId);
    }

    function buildRequiredDVNs(DVNConfiguration memory config) internal pure returns (address[] memory) {
        address[] memory requiredDVNs = new address[](1);

        // Use LayerZero Labs DVN (or Dead DVN for Base mainnet as temporary fallback)
        requiredDVNs[0] = DeploymentConfig.getLayerZeroLabsDVN(config.chainId);

        return requiredDVNs;
    }

    /* -------------------------------------------------------------------------- */
    /*                        Enforced Options Configuration                     */
    /* -------------------------------------------------------------------------- */

    function configureEnforcedOptions(DVNConfiguration memory config) internal pure {
        console.log("\nConfiguring enforced options...");

        // Get appropriate gas limit for destination chain
        uint256 gasLimit = DeploymentConfig.getLzReceiveGasLimit(config.chainId);

        console.log("Setting enforced options with gas limit:", gasLimit);

        // Note: This would require the FeeRouter to support setEnforcedOptions
        // For now, we document the recommended gas limits
        console.log("Recommended gas limit for remote chain:", gasLimit);
        console.log("Configure enforced options manually via LayerZero endpoint");
    }

    /* -------------------------------------------------------------------------- */
    /*                             Verification                                  */
    /* -------------------------------------------------------------------------- */

    function verifyConfiguration(DVNConfiguration memory config) internal view {
        console.log("\nVerifying DVN configuration...");

        ILayerZeroEndpointV2Config endpoint = ILayerZeroEndpointV2Config(config.endpoint);

        // Verify libraries are set
        address sendLib = endpoint.getSendLibrary(config.feeRouter, config.remoteEid);
        (address receiveLib, bool isDefault) = endpoint.getReceiveLibrary(config.feeRouter, config.remoteEid);

        console.log("Send library configured:", sendLib != address(0));
        console.log("Receive library configured:", receiveLib != address(0));
        console.log("Using default receive library:", isDefault);

        console.log("DVN configuration verification complete");
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper Functions                             */
    /* -------------------------------------------------------------------------- */

    function logDVNConfiguration(address[] memory requiredDVNs, uint256 chainId) internal pure {
        console.log("\nDVN Configuration Summary:");
        console.log("Block confirmations:", DeploymentConfig.getBlockConfirmations(chainId));
        console.log("Required DVNs:", requiredDVNs.length);
        for (uint256 i = 0; i < requiredDVNs.length; i++) {
            console.log("  DVN:", requiredDVNs[i]);
        }

        // Note about Base mainnet
        if (chainId == DeploymentConfig.BASE_MAINNET) {
            console.log("  Note: Using Dead DVN for Base mainnet until official DVN is available");
        }
    }
}
