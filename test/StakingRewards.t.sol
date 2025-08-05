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
        uint256 expectedReward = rewardAmt / 2; // 50% distributed, 50% burned
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
        uint256 expectedReward = rewardAmt / 2; // 50% distributed, 50% burned
        assertApproxEqAbs(earned, expectedReward, 1e18); // Allow larger delta for 1e12 precision vs 1e18
    }
}
