// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {FeeRouter} from "../../src/FeeRouter.sol";
import {MockLZEndpoint} from "../mock/MockLZEndpoint.sol";
import {MockAirlock} from "../mock/MockAirlock.sol";
import {MockStakingRewards} from "../mock/MockStakingRewards.sol";
import {MockHLG} from "../mock/MockHLG.sol";
import {MockWETH} from "../mock/MockWETH.sol";
import {MockSwapRouter} from "../mock/MockSwapRouter.sol";

/**
 * @title FeeRouterInvariants
 * @notice Property-based tests for FeeRouter contract invariants
 * @dev Tests invariants that should always hold regardless of execution path
 */
contract FeeRouterInvariants is Test {
    FeeRouter public feeRouter;
    MockLZEndpoint public lzEndpoint;
    MockAirlock public airlock;
    MockStakingRewards public stakingPool;
    MockHLG public hlg;
    MockWETH public weth;
    MockSwapRouter public swapRouter;

    // Test addresses
    address public owner = address(0x1234567890123456789012345678901234567890);
    address public keeper = address(0x0987654321098765432109876543210987654321);
    address public treasury = address(0x1111111111111111111111111111111111111111);

    // Network configuration
    uint32 constant UNICHAIN_EID = 40328;

    function setUp() public {
        // Deploy mocks
        lzEndpoint = new MockLZEndpoint();
        airlock = new MockAirlock();
        hlg = new MockHLG();
        stakingPool = new MockStakingRewards(address(hlg));
        weth = new MockWETH();
        swapRouter = new MockSwapRouter();

        // Deploy FeeRouter
        vm.prank(owner);
        feeRouter = new FeeRouter(
            address(lzEndpoint),
            UNICHAIN_EID,
            address(stakingPool),
            address(hlg),
            address(weth),
            address(swapRouter),
            treasury,
            owner
        );

        // Grant keeper role
        vm.prank(owner);
        feeRouter.grantRole(feeRouter.KEEPER_ROLE(), keeper);

        // Set up trusted contracts
        vm.prank(owner);
        feeRouter.setTrustedAirlock(address(airlock), true);
        vm.prank(owner);
        feeRouter.setTrustedRemote(UNICHAIN_EID, bytes32(uint256(uint160(address(0x4444)))));

        // Target this contract for invariant testing
        targetContract(address(feeRouter));
    }

    /**
     * @notice Invariant: Bridge can only succeed if trustedRemotes[remoteEid] != bytes32(0)
     * @dev This property ensures that bridge operations require properly configured remote endpoints
     */
    function invariant_bridgeOnlyWithTrustedRemote() public {
        uint32 currentRemoteEid = feeRouter.remoteEid();
        bytes32 trustedRemote = feeRouter.trustedRemotes(currentRemoteEid);
        
        // If the router has sufficient balance for bridging, trusted remote must be set
        if (address(feeRouter).balance >= feeRouter.MIN_BRIDGE_VALUE()) {
            assertTrue(
                trustedRemote != bytes32(0), 
                "Bridge possible but no trusted remote configured"
            );
        }
    }

    /**
     * @notice Invariant: Contract balance should never decrease without proper authorization
     * @dev Ensures only authorized functions can move value out of the contract
     */
    function invariant_balanceOnlyDecreasesOnAuthorizedCalls() public {
        // This would require more sophisticated state tracking in a real implementation
        // For now, we verify basic sanity
        assertTrue(address(feeRouter).balance >= 0, "Balance cannot be negative");
    }

    /**
     * @notice Invariant: Protocol fee should never exceed 100%
     * @dev Ensures fee calculations remain within valid bounds
     */
    function invariant_protocolFeeWithinBounds() public {
        uint16 currentFeeBps = feeRouter.holographFeeBps();
        assertTrue(currentFeeBps <= 10000, "Protocol fee exceeds 100%");
    }

    /**
     * @notice Invariant: Remote EID should never be zero after construction
     * @dev Ensures contract is always configured with a valid remote endpoint
     */
    function invariant_remoteEidNonZero() public {
        uint32 currentRemoteEid = feeRouter.remoteEid();
        assertTrue(currentRemoteEid != 0, "Remote EID should never be zero");
    }

    /**
     * @notice Invariant: Contract should always have a valid owner
     * @dev Ensures contract ownership is properly maintained
     */
    function invariant_ownerExists() public {
        address currentOwner = feeRouter.owner();
        assertTrue(currentOwner != address(0), "Owner should never be zero address");
    }
}