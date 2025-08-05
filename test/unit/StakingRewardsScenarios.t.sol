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

        // Add rewards (100 tokens: default 50% burned, 50% distributed)
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.addRewards(100 ether);
        vm.stopPrank();

        // User1 should have 50 tokens pending (with default 50% burn rate)
        uint256 burnPercentage = stakingRewards.burnPercentage();
        uint256 expectedReward = (100 ether * (10000 - burnPercentage)) / 10000;
        assertEq(stakingRewards.earned(user1), expectedReward);

        // User1 stakes another 100 tokens
        vm.prank(user1);
        stakingRewards.stake(100 ether);

        // After second stake:
        // - Original 100 + expectedReward (auto-compounded) + 100 new = total
        assertEq(stakingRewards.balanceOf(user1), 100 ether + expectedReward + 100 ether);
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
        stakingRewards.addRewards(100 ether);
        vm.stopPrank();

        // User1 has all rewards (calculate based on burn percentage)
        uint256 burnPercentage = stakingRewards.burnPercentage();
        uint256 firstRewardAmount = (100 ether * (10000 - burnPercentage)) / 10000;
        assertEq(stakingRewards.earned(user1), firstRewardAmount);

        // User2 joins
        vm.startPrank(user2);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.stake(300 ether);
        vm.stopPrank();

        // Add second batch of rewards
        vm.prank(feeRouter);
        stakingRewards.addRewards(200 ether);

        // Check proportional distribution
        uint256 secondRewardAmount = (200 ether * (10000 - burnPercentage)) / 10000;
        // User1: 100/400 = 25% of new rewards
        // User2: 300/400 = 75% of new rewards
        uint256 user1SecondReward = (secondRewardAmount * 100) / 400;
        uint256 user2SecondReward = (secondRewardAmount * 300) / 400;
        assertEq(stakingRewards.earned(user1), firstRewardAmount + user1SecondReward);
        assertEq(stakingRewards.earned(user2), user2SecondReward);

        // Compound all rewards
        stakingRewards.updateUser(user1);
        stakingRewards.updateUser(user2);

        // Final balances
        assertEq(stakingRewards.balanceOf(user1), 100 ether + firstRewardAmount + user1SecondReward);
        assertEq(stakingRewards.balanceOf(user2), 300 ether + user2SecondReward);

        // Verify invariant
        assertEq(stakingRewards.totalStaked(), stakingRewards.balanceOf(user1) + stakingRewards.balanceOf(user2));
    }

    /// @notice Test zero staker buffer functionality
    function test_ZeroStakerBuffer() public {
        // Add rewards when no stakers
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), type(uint256).max);
        stakingRewards.addRewards(100 ether);
        vm.stopPrank();

        // Check buffer has the reward portion (based on burn percentage)
        uint256 burnPercentage = stakingRewards.burnPercentage();
        uint256 expectedBufferAmount = (100 ether * (10000 - burnPercentage)) / 10000;
        assertEq(stakingRewards.unallocatedBuffer(), expectedBufferAmount);
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
        // Their balance should be 100 (stake) + expectedBufferAmount (buffered rewards)
        assertEq(stakingRewards.balanceOf(user1), 100 ether + expectedBufferAmount);
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
        stakingRewards.addRewards(150 ether);
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
