// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StakingRewards} from "../src/StakingRewards.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mock/MockERC20.sol";

contract StakingRewardsTest is Test {
    StakingRewards public stakingRewards;
    MockERC20 public hlg;

    address public owner = address(0x1);
    address public feeRouter = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    uint256 public constant INITIAL_SUPPLY = 1000000 ether;
    uint256 public constant STAKE_AMOUNT = 1000 ether;
    uint256 public constant REWARD_AMOUNT = 100 ether;

    /* -------------------------------------------------------------------------- */
    /*                                   Setup                                    */
    /* -------------------------------------------------------------------------- */
    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock HLG token
        hlg = new MockERC20("Test HLG", "HLG");
        hlg.mint(user1, INITIAL_SUPPLY);
        hlg.mint(user2, INITIAL_SUPPLY);
        hlg.mint(feeRouter, INITIAL_SUPPLY);

        // Deploy staking contract
        stakingRewards = new StakingRewards(address(hlg), owner);

        // Set fee router
        stakingRewards.setFeeRouter(feeRouter);

        // Unpause the contract for testing
        stakingRewards.unpause();

        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                            Stake / Withdraw / Claim                        */
    /* -------------------------------------------------------------------------- */
    function testStakeAndWithdraw() public {
        uint256 amt = 100 ether;
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), amt);
        stakingRewards.stake(amt);
        assertEq(stakingRewards.totalStaked(), amt);
        assertEq(stakingRewards.balanceOf(user1), amt);

        vm.warp(block.timestamp + 7 days + 1);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStaked(), 0);
        assertEq(stakingRewards.balanceOf(user1), 0);
        vm.stopPrank();
    }

    function testAutoCompoundingRewards() public {
        uint256 stakeAmt = 100 ether;
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), stakeAmt);
        stakingRewards.stake(stakeAmt);
        vm.stopPrank();

        uint256 rewardAmt = 50 ether;
        hlg.mint(feeRouter, rewardAmt);
        vm.prank(feeRouter);
        hlg.approve(address(stakingRewards), rewardAmt);
        vm.prank(feeRouter);
        stakingRewards.addRewards(rewardAmt);

        uint256 earned = stakingRewards.earned(user1);
        // Get burn percentage and calculate expected reward
        uint256 burnPercentage = stakingRewards.burnPercentage();
        uint256 expectedReward = (rewardAmt * (10000 - burnPercentage)) / 10000;
        assertApproxEqAbs(earned, expectedReward, 1); // allow 1-wei rounding

        // Trigger auto-compounding by calling updateUser
        stakingRewards.updateUser(user1);

        // After compounding, user's balance should include rewards
        assertApproxEqAbs(stakingRewards.balanceOf(user1), stakeAmt + expectedReward, 1);
        assertApproxEqAbs(stakingRewards.totalStaked(), stakeAmt + expectedReward, 1);

        // Pending rewards should now be zero
        assertEq(stakingRewards.earned(user1), 0);

        // User unstakes and should receive original stake + compounded rewards
        uint256 userBalanceBefore = hlg.balanceOf(user1);
        vm.prank(user1);
        stakingRewards.unstake();

        // User should receive their full balance (original stake + rewards)
        assertApproxEqAbs(hlg.balanceOf(user1), userBalanceBefore + stakeAmt + expectedReward, 1);
        assertEq(stakingRewards.balanceOf(user1), 0);
        assertEq(stakingRewards.totalStaked(), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Pause / Unpause                             */
    /* -------------------------------------------------------------------------- */
    function testPause() public {
        vm.prank(owner);
        stakingRewards.pause();
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), 1 ether);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        stakingRewards.stake(1 ether);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                            FeeRouter only addRewards                       */
    /* -------------------------------------------------------------------------- */
    function testAddRewardsOnlyRouter() public {
        uint256 amt = 1 ether;
        hlg.mint(user1, amt);
        vm.prank(user1);
        hlg.approve(address(stakingRewards), amt);
        vm.prank(user1);
        vm.expectRevert(StakingRewards.Unauthorized.selector);
        stakingRewards.addRewards(amt);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Fuzz                                    */
    /* -------------------------------------------------------------------------- */
    function testFuzz_StakeThenReward(uint128 stakeAmt, uint128 rewardAmt) public {
        stakeAmt = uint128(bound(uint256(stakeAmt), 1e18, 1e24));
        rewardAmt = uint128(bound(uint256(rewardAmt), 1e18, 1e24));
        hlg.mint(user1, stakeAmt);
        hlg.mint(feeRouter, rewardAmt);

        vm.prank(user1);
        hlg.approve(address(stakingRewards), stakeAmt);
        vm.prank(user1);
        stakingRewards.stake(stakeAmt);

        vm.prank(feeRouter);
        hlg.approve(address(stakingRewards), rewardAmt);
        vm.prank(feeRouter);
        stakingRewards.addRewards(rewardAmt);

        uint256 earned = stakingRewards.earned(user1);
        // Get burn percentage and calculate expected reward
        uint256 burnPercentage = stakingRewards.burnPercentage();
        uint256 expectedReward = (rewardAmt * (10000 - burnPercentage)) / 10000;
        assertApproxEqAbs(earned, expectedReward, 1e18); // Allow larger delta for 1e12 precision vs 1e18
    }

    /* -------------------------------------------------------------------------- */
    /*                           Burn Percentage Tests                            */
    /* -------------------------------------------------------------------------- */

    function testSetBurnPercentage() public {
        // Test setting valid burn percentage
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit StakingRewards.BurnPercentageUpdated(5000, 3000); // 50% to 30%
        stakingRewards.setBurnPercentage(3000);

        assertEq(stakingRewards.burnPercentage(), 3000);
    }

    function testSetBurnPercentageOnlyOwner() public {
        // Test that only owner can set burn percentage
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        stakingRewards.setBurnPercentage(3000);
    }

    function testSetBurnPercentageInvalidValue() public {
        // Test that burn percentage cannot exceed 100%
        vm.prank(owner);
        vm.expectRevert(StakingRewards.InvalidBurnPercentage.selector);
        stakingRewards.setBurnPercentage(10001); // > 100%
    }

    function testDifferentBurnPercentages() public {
        uint256 stakeAmt = 100 ether;
        uint256 rewardAmt = 100 ether;

        // Setup user stake
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), stakeAmt);
        stakingRewards.stake(stakeAmt);
        vm.stopPrank();

        // Test 25% burn (75% rewards)
        vm.prank(owner);
        stakingRewards.setBurnPercentage(2500);

        hlg.mint(feeRouter, rewardAmt);
        vm.prank(feeRouter);
        hlg.approve(address(stakingRewards), rewardAmt);
        vm.prank(feeRouter);
        stakingRewards.addRewards(rewardAmt);

        uint256 earned = stakingRewards.earned(user1);
        uint256 expectedReward = (rewardAmt * 7500) / 10000; // 75% to stakers
        assertApproxEqAbs(earned, expectedReward, 1e15); // Allow for precision loss with 1e12

        // Reset for next test
        stakingRewards.updateUser(user1);

        // Test 80% burn (20% rewards)
        vm.prank(owner);
        stakingRewards.setBurnPercentage(8000);

        hlg.mint(feeRouter, rewardAmt);
        vm.prank(feeRouter);
        hlg.approve(address(stakingRewards), rewardAmt);
        vm.prank(feeRouter);
        stakingRewards.addRewards(rewardAmt);

        earned = stakingRewards.earned(user1);
        expectedReward = (rewardAmt * 2000) / 10000; // 20% to stakers
        assertApproxEqAbs(earned, expectedReward, 1e15); // Allow for precision loss with 1e12
    }

    function testZeroBurnPercentage() public {
        uint256 stakeAmt = 100 ether;
        uint256 rewardAmt = 100 ether;

        // Setup user stake
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), stakeAmt);
        stakingRewards.stake(stakeAmt);
        vm.stopPrank();

        // Set 0% burn (100% rewards)
        vm.prank(owner);
        stakingRewards.setBurnPercentage(0);

        hlg.mint(feeRouter, rewardAmt);
        vm.prank(feeRouter);
        hlg.approve(address(stakingRewards), rewardAmt);
        vm.prank(feeRouter);
        stakingRewards.addRewards(rewardAmt);

        uint256 earned = stakingRewards.earned(user1);
        assertEq(earned, rewardAmt); // All rewards go to stakers
    }

    /* -------------------------------------------------------------------------- */
    /*                           Batch Staking Tests                              */
    /* -------------------------------------------------------------------------- */

    function testStakeFor() public {
        uint256 amount = 100 ether;
        hlg.mint(owner, amount);

        vm.startPrank(owner);
        stakingRewards.pause(); // Pause for stakeFor
        hlg.approve(address(stakingRewards), amount);
        stakingRewards.stakeFor(user1, amount);
        vm.stopPrank();

        assertEq(stakingRewards.balanceOf(user1), amount);
        assertEq(stakingRewards.totalStaked(), amount);
    }

    function testStakeForOnlyOwner() public {
        uint256 amount = 100 ether;
        hlg.mint(user1, amount);

        vm.prank(user1);
        hlg.approve(address(stakingRewards), amount);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        stakingRewards.stakeFor(user2, amount);
    }

    function testStakeForOnlyWhenPaused() public {
        uint256 amount = 100 ether;
        hlg.mint(owner, amount);

        // Contract is unpaused in setUp, so stakeFor should fail
        vm.prank(owner);
        hlg.approve(address(stakingRewards), amount);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        stakingRewards.stakeFor(user1, amount);
    }

    function testBatchStakeFor() public {
        // Pause contract for batch operations
        vm.prank(owner);
        stakingRewards.pause();

        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = address(0x5);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;

        uint256 totalAmount = 600 ether;
        hlg.mint(owner, totalAmount);

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), totalAmount);
        stakingRewards.batchStakeFor(users, amounts, 0, 3);
        vm.stopPrank();

        assertEq(stakingRewards.balanceOf(user1), 100 ether);
        assertEq(stakingRewards.balanceOf(user2), 200 ether);
        assertEq(stakingRewards.balanceOf(address(0x5)), 300 ether);
        assertEq(stakingRewards.totalStaked(), 600 ether);
    }

    function testBatchStakeForPartialRange() public {
        vm.prank(owner);
        stakingRewards.pause();

        address[] memory users = new address[](5);
        uint256[] memory amounts = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            users[i] = address(uint160(0x100 + i));
            amounts[i] = (i + 1) * 100 ether;
        }

        // Process only users 1-3 (indices 1,2,3)
        uint256 batchAmount = 200 ether + 300 ether + 400 ether; // 900 ether
        hlg.mint(owner, batchAmount);

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), batchAmount);
        stakingRewards.batchStakeFor(users, amounts, 1, 4);
        vm.stopPrank();

        assertEq(stakingRewards.balanceOf(users[0]), 0); // Not processed
        assertEq(stakingRewards.balanceOf(users[1]), 200 ether);
        assertEq(stakingRewards.balanceOf(users[2]), 300 ether);
        assertEq(stakingRewards.balanceOf(users[3]), 400 ether);
        assertEq(stakingRewards.balanceOf(users[4]), 0); // Not processed
        assertEq(stakingRewards.totalStaked(), 900 ether);
    }

    function testBatchStakeForArrayMismatch() public {
        vm.prank(owner);
        stakingRewards.pause();

        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](3); // Different length

        vm.prank(owner);
        vm.expectRevert(StakingRewards.ArrayLengthMismatch.selector);
        stakingRewards.batchStakeFor(users, amounts, 0, 2);
    }

    function testBatchStakeForInvalidRange() public {
        vm.prank(owner);
        stakingRewards.pause();

        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        vm.prank(owner);
        vm.expectRevert(StakingRewards.EndIndexOutOfBounds.selector);
        stakingRewards.batchStakeFor(users, amounts, 0, 3);

        vm.prank(owner);
        vm.expectRevert(StakingRewards.InvalidIndexRange.selector);
        stakingRewards.batchStakeFor(users, amounts, 2, 1);
    }

    function testBatchStakeForCompoundsExistingRewards() public {
        // First, setup a user with some stake and add rewards
        uint256 initialStake = 100 ether;
        vm.startPrank(user1);
        hlg.approve(address(stakingRewards), initialStake);
        stakingRewards.stake(initialStake);
        vm.stopPrank();

        // Add rewards
        uint256 rewardAmount = 50 ether;
        hlg.mint(feeRouter, rewardAmount);
        vm.prank(feeRouter);
        hlg.approve(address(stakingRewards), rewardAmount);
        vm.prank(feeRouter);
        stakingRewards.addRewards(rewardAmount);

        // Check pending rewards
        uint256 burnPercentage = stakingRewards.burnPercentage();
        uint256 expectedReward = (rewardAmount * (10000 - burnPercentage)) / 10000;
        assertApproxEqAbs(stakingRewards.earned(user1), expectedReward, 1);

        // Now pause and batch stake for the same user
        vm.prank(owner);
        stakingRewards.pause();

        address[] memory users = new address[](1);
        users[0] = user1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 200 ether;

        hlg.mint(owner, 200 ether);
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.batchStakeFor(users, amounts, 0, 1);
        vm.stopPrank();

        // User should have initial stake + rewards + new stake
        assertApproxEqAbs(stakingRewards.balanceOf(user1), initialStake + expectedReward + 200 ether, 1);

        // Pending rewards should be 0 after compounding
        assertEq(stakingRewards.earned(user1), 0);
    }

    function testDistributorPauseBehavior() public {
        address mockDistributor = address(0x1234);
        uint256 amount = 100 ether;
        
        // Setup distributor
        vm.prank(owner);
        stakingRewards.setDistributor(mockDistributor, true);
        
        // Fund distributor
        hlg.mint(address(this), amount * 2); // Need extra for second call
        hlg.transfer(mockDistributor, amount * 2);
        
        // Distributor can call when not paused (contract is unpaused by default in setup)
        vm.startPrank(mockDistributor);
        hlg.approve(address(stakingRewards), amount);
        stakingRewards.stakeFromDistributor(user1, amount);
        vm.stopPrank();
        
        // Verify stake was credited
        assertEq(stakingRewards.balanceOf(user1), amount, "Stake should be credited when not paused");
        
        // Pause the contract
        vm.prank(owner);
        stakingRewards.pause();
        
        // Distributor call should revert when paused
        vm.startPrank(mockDistributor);
        hlg.approve(address(stakingRewards), amount);
        vm.expectRevert(); // EnforcedPause() is the actual error
        stakingRewards.stakeFromDistributor(user2, amount);
        vm.stopPrank();
        
        // But user can still unstake when paused
        vm.prank(user1);
        stakingRewards.unstake();
        assertEq(stakingRewards.balanceOf(user1), 0, "User should be able to unstake when paused");
    }

    function testDistributorWhitelistError() public {
        address unauthorizedDistributor = address(0x5678);
        uint256 amount = 100 ether;
        
        // Fund unauthorized distributor
        hlg.mint(address(this), amount);
        hlg.transfer(unauthorizedDistributor, amount);
        
        // Contract is already unpaused by setup
        
        // Unauthorized distributor should revert with NotWhitelistedDistributor
        vm.startPrank(unauthorizedDistributor);
        hlg.approve(address(stakingRewards), amount);
        vm.expectRevert(StakingRewards.NotWhitelistedDistributor.selector);
        stakingRewards.stakeFromDistributor(user1, amount);
        vm.stopPrank();
    }
}
