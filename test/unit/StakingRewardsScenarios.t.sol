// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {StakingRewards} from "../../src/StakingRewards.sol";
import {MockERC20} from "../mock/MockERC20.sol";

/// @title StakingRewardsScenarios
/// @notice Specific scenario tests for StakingRewards edge cases
contract StakingRewardsScenarios is Test {
    StakingRewards public stakingRewards;
    MockERC20 public hlg;

    address public owner = address(this);
    address public feeRouter = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    function setUp() public {
        // Deploy contracts
        hlg = new MockERC20("HLG", "HLG");
        stakingRewards = new StakingRewards(address(hlg), owner);

        // Configure
        stakingRewards.setFeeRouter(feeRouter);
        stakingRewards.unpause();

        // Fund users
        hlg.mint(user1, 10_000 ether);
        hlg.mint(user2, 10_000 ether);
        hlg.mint(feeRouter, 10_000 ether);
    }

    /// @notice Test double stake scenario to ensure rewards aren't lost
    function test_DoubleStakeRewardsPreserved() public {
        // User1 stakes 100 tokens
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        assertEq(stakingRewards.balanceOf(user1), 100 ether);
        assertEq(stakingRewards.earned(user1), 0);

        // Add rewards (100 tokens: 50 burned, 50 distributed)
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.addRewards(100 ether);
        vm.stopPrank();

        // User1 should have 50 tokens pending
        assertEq(stakingRewards.earned(user1), 50 ether);

        // User1 stakes another 100 tokens
        vm.prank(user1);
        stakingRewards.stake(100 ether);

        // After second stake:
        // - Original 100 + 50 rewards (auto-compounded) + 100 new = 250 total
        assertEq(stakingRewards.balanceOf(user1), 250 ether);
        assertEq(stakingRewards.earned(user1), 0); // Rewards were compounded

        // Verify invariant
        assertEq(stakingRewards.totalStaked(), stakingRewards.balanceOf(user1));
    }

    /// @notice Test multiple users with different stake times
    function test_MultipleUsersProportionalRewards() public {
        // User1 stakes first
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        // Add first batch of rewards
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.addRewards(100 ether); // 50 to stakers
        vm.stopPrank();

        // User1 has all rewards
        assertEq(stakingRewards.earned(user1), 50 ether);

        // User2 joins
        vm.startPrank(user2);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(300 ether);
        vm.stopPrank();

        // Add second batch of rewards
        vm.prank(feeRouter);
        stakingRewards.addRewards(200 ether); // 100 to stakers

        // Check proportional distribution
        // User1: 100/400 = 25% of new rewards = 25
        // User2: 300/400 = 75% of new rewards = 75
        assertEq(stakingRewards.earned(user1), 50 ether + 25 ether);
        assertEq(stakingRewards.earned(user2), 75 ether);

        // Compound all rewards
        stakingRewards.updateUser(user1);
        stakingRewards.updateUser(user2);

        // Final balances
        assertEq(stakingRewards.balanceOf(user1), 175 ether); // 100 + 50 + 25
        assertEq(stakingRewards.balanceOf(user2), 375 ether); // 300 + 75

        // Verify invariant
        assertEq(stakingRewards.totalStaked(), stakingRewards.balanceOf(user1) + stakingRewards.balanceOf(user2));
    }

    /// @notice Test zero staker buffer functionality
    function test_ZeroStakerBuffer() public {
        // Add rewards when no stakers
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.addRewards(100 ether); // 50 to buffer
        vm.stopPrank();

        // Check buffer has the reward portion
        assertEq(stakingRewards.unallocatedBuffer(), 50 ether);
        assertEq(stakingRewards.globalRewardIndex(), 0);

        // First user stakes
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        // Buffer should be distributed to first staker
        assertEq(stakingRewards.unallocatedBuffer(), 0);
        assertEq(stakingRewards.globalRewardIndex(), 0); // Index stays 0 - first staker gets all

        // User1's buffered rewards were auto-compounded during stake
        // Their balance should be 100 (stake) + 50 (buffered rewards) = 150
        assertEq(stakingRewards.balanceOf(user1), 150 ether);
        assertEq(stakingRewards.earned(user1), 0); // No pending since already compounded
    }

    /// @notice Test emergency exit preserves invariant
    function test_EmergencyExitInvariant() public {
        // Setup: two users with stakes
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(200 ether);
        vm.stopPrank();

        // Add rewards
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.addRewards(150 ether); // 75 to stakers
        vm.stopPrank();

        uint256 totalBefore = stakingRewards.totalStaked();
        uint256 user1BalBefore = stakingRewards.balanceOf(user1);

        // User1 emergency exits (forfeits pending rewards)
        vm.prank(user1);
        stakingRewards.emergencyExit();

        // Verify state
        assertEq(stakingRewards.balanceOf(user1), 0);
        assertEq(stakingRewards.totalStaked(), totalBefore - user1BalBefore);

        // Verify invariant still holds
        assertEq(stakingRewards.totalStaked(), stakingRewards.balanceOf(user1) + stakingRewards.balanceOf(user2));
    }
}
