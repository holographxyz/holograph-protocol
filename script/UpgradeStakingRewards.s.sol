// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title UpgradeStakingRewards
 * @notice Foundry script to upgrade StakingRewards implementation using UUPS proxy
 *
 * Usage examples:
 *   // Dry-run (fork)
 *   forge script script/UpgradeStakingRewards.s.sol --fork-url $ETH_RPC
 *
 *   // Broadcast (mainnet)
 *   forge script script/UpgradeStakingRewards.s.sol \
 *       --rpc-url $ETH_RPC \
 *       --broadcast \
 *       --private-key $DEPLOYER_PK
 */
import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/StakingRewards.sol";
import "./DeploymentBase.sol";
import "./DeploymentConfig.sol";

contract UpgradeStakingRewards is Script {
    error InvalidProxyAddress();
    error InvalidNewImplementation();
    error UpgradeUnauthorized();
    error ProxyNotFound();

    function run() external {
        // Initialize deployment configuration
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        console.log("Upgrader:", deployer);

        // NOTE: For multisig ownership scenarios, this script will fail at the owner check
        // unless the broadcaster is the current owner. Use a multisig transaction instead.

        // Get existing proxy address from environment or deployment file
        address stakingProxy = vm.envOr("STAKING_REWARDS_PROXY", address(0));

        if (stakingProxy == address(0)) {
            // Try to load from deployment file
            stakingProxy = _loadProxyFromDeployment();
            if (stakingProxy == address(0)) {
                revert ProxyNotFound();
            }
        }

        console.log("StakingRewards Proxy:", stakingProxy);

        // Verify current implementation
        address currentImpl = _getImplementation(stakingProxy);
        console.log("Current implementation:", currentImpl);

        // Safety checks
        if (stakingProxy == address(0)) revert InvalidProxyAddress();

        // Start broadcasting with the private key
        vm.startBroadcast(privateKey);

        // Deploy new implementation
        console.log("\nDeploying new StakingRewards implementation...");
        uint256 gasStart = gasleft();
        StakingRewards newImpl = new StakingRewards();
        uint256 gasUsed = gasStart - gasleft();

        console.log("New implementation deployed at:", address(newImpl));
        console.log("Gas used for deployment:", gasUsed);

        // Verify we have upgrade authority
        StakingRewards proxy = StakingRewards(payable(stakingProxy));
        try proxy.owner() returns (address owner) {
            if (owner != deployer) {
                console.log("ERROR: Deployer is not the owner of the proxy");
                console.log("Proxy owner:", owner);
                console.log("Deployer:", deployer);
                revert UpgradeUnauthorized();
            }
        } catch {
            revert UpgradeUnauthorized();
        }

        // Perform upgrade
        console.log("\nPerforming upgrade...");
        gasStart = gasleft();
        proxy.upgradeToAndCall(address(newImpl), "");
        gasUsed = gasStart - gasleft();

        console.log("Upgrade completed successfully!");
        console.log("Gas used for upgrade:", gasUsed);

        // Verify upgrade
        address newImplAddress = _getImplementation(stakingProxy);
        console.log("Implementation after upgrade:", newImplAddress);

        if (newImplAddress != address(newImpl)) {
            revert InvalidNewImplementation();
        }

        // Verify proxy state is preserved
        console.log("\nVerifying proxy state preservation...");
        console.log("HLG token address:", address(proxy.HLG()));
        console.log("Total staked:", proxy.totalStaked());
        console.log("Proxy owner:", proxy.owner());
        console.log("Is paused:", proxy.paused());

        vm.stopBroadcast();

        console.log("\nStakingRewards upgrade completed successfully!");
        console.log("Update your environment variables or deployment files with:");
        console.log("   STAKING_REWARDS_IMPL_OLD=", currentImpl);
        console.log("   STAKING_REWARDS_IMPL_NEW=", address(newImpl));
        console.log("   STAKING_REWARDS_PROXY=", stakingProxy);
    }

    /**
     * @notice Get implementation address from proxy using EIP-1967 storage slot
     */
    function _getImplementation(address proxy) internal view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        return address(uint160(uint256(vm.load(proxy, slot))));
    }

    /**
     * @notice Load proxy address from deployment file
     */
    function _loadProxyFromDeployment() internal view returns (address) {
        // Try to read from deployments directory based on current chain
        string memory chainName = _getChainName(block.chainid);
        string memory deploymentPath = string(abi.encodePacked("deployments/", chainName, "/deployment.json"));

        try vm.readFile(deploymentPath) returns (string memory deploymentData) {
            // Parse JSON to extract StakingRewards address
            return vm.parseJsonAddress(deploymentData, ".stakingRewards");
        } catch {
            console.log("Could not load deployment file:", deploymentPath);
            return address(0);
        }
    }

    /**
     * @notice Get chain name for deployment file lookup
     */
    function _getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "ethereum";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 8453) return "base";
        if (chainId == 84532) return "base-sepolia";
        return "unknown";
    }
}
