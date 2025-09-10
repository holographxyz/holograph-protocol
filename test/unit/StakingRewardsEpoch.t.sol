// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {StakingRewards} from "../../src/StakingRewards.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract StakingRewardsEpochTest is Test {
    StakingRewards public staking;
    MockERC20 public hlg;

    address public owner = address(0xA11CE);
    address public alice = address(0xBEEF);
    address public bob = address(0xCAFE);

    uint256 constant ONE = 1 ether;

    function setUp() public {
        vm.startPrank(owner);
        hlg = new MockERC20("HLG", "HLG");
        staking = new StakingRewards(address(hlg), owner);
        staking.setFeeRouter(owner); // dummy
        staking.unpause();
        vm.stopPrank();

        hlg.mint(alice, 10_000 ether);
        hlg.mint(bob, 10_000 ether);
        hlg.mint(owner, 10_000 ether);
    }

    function _rollEpoch() internal {
        vm.warp(block.timestamp + 8 days);
        staking.updateUser(address(0xdead));
    }

    function test_ActivationNextEpoch_and_Maturity() public {
        // Alice stakes in epoch N
        vm.startPrank(alice);
        hlg.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        // Distribution in same epoch is a no-op since eligibleTotal == 0
        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether);
        vm.stopPrank();
        assertEq(staking.earned(alice), 0, "no rewards in join epoch");

        // Roll to epoch N+1 to activate Alice's stake
        _rollEpoch();

        // Distribute in epoch N+1 -> accrues to current epoch index
        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether);
        vm.stopPrank();

        // Roll to epoch N+2 to mature
        _rollEpoch();
        // Now earned should be 50 (50% burn)
        assertEq(staking.earned(alice), 50 ether);
    }

    function test_DistributionUsesEligibleTotal_TwoUsersAcrossEpochs() public {
        // Alice stakes in N
        vm.startPrank(alice);
        hlg.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        _rollEpoch(); // activate Alice

        // Distribute in N+1 (only Alice eligible)
        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether); // 50 reward
        vm.stopPrank();

        // Bob stakes in N+1
        vm.startPrank(bob);
        hlg.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();

        // Mature N+1
        _rollEpoch();
        // Alice should have 50 pending, Bob 0
        assertEq(staking.earned(alice), 50 ether);
        assertEq(staking.earned(bob), 0);

        // Activate Bob's eligibility by settling him at the start of N+2
        staking.updateUser(bob);

        // Distribute in N+2 (Alice and Bob eligible equally)
        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether); // +50 reward over 200 eligible => 0.25 per token
        vm.stopPrank();

        // Mature N+2
        _rollEpoch();
        // Alice now should have 50 + 25, Bob 25
        assertEq(staking.earned(alice), 75 ether);
        assertEq(staking.earned(bob), 25 ether);
    }

    function test_AutoCompoundingSchedulesNextEpoch() public {
        // Alice stakes and becomes eligible
        vm.startPrank(alice);
        hlg.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();
        _rollEpoch();

        // Distribute and mature one epoch
        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether);
        vm.stopPrank();
        _rollEpoch();

        // Compound matured rewards
        staking.updateUser(alice);
        // Balance increases by 50
        assertEq(staking.balanceOf(alice), 150 ether);
        // Ensure compounded amount is scheduled, not immediately eligible
        // Distribute within same epoch; earned should remain 0
        vm.startPrank(owner);
        hlg.approve(address(staking), 10 ether);
        staking.depositAndDistribute(10 ether);
        vm.stopPrank();
        assertEq(staking.earned(alice), 0);
        // But these 50 are not yet eligible until next epoch activation
        // So earned remains 0 until we roll and then distribute again
        assertEq(staking.earned(alice), 0);

        // Next epoch activates compounded amount
        _rollEpoch();
        staking.updateUser(alice);
        // Now eligible set includes 150; distribute and mature again
        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether);
        vm.stopPrank();
        _rollEpoch();
        // Earned should be ~50 with 1e12 index precision rounding
        assertApproxEqAbs(staking.earned(alice), 50 ether, 1e12);
    }

    function test_UnstakeSchedulingAndFinalize() public {
        // Alice stakes, activates, and accrues one epoch
        vm.startPrank(alice);
        hlg.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();
        _rollEpoch();

        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether);
        vm.stopPrank();
        _rollEpoch();
        staking.updateUser(alice); // compound -> balance 150

        // Schedule unstake
        vm.prank(alice);
        staking.unstake();
        // Cannot finalize in same epoch
        vm.prank(alice);
        vm.expectRevert();
        staking.finalizeUnstake();

        // Finalize next epoch
        _rollEpoch();
        uint256 aliceHlgBefore = hlg.balanceOf(alice);
        vm.prank(alice);
        staking.finalizeUnstake();
        uint256 aliceHlgAfter = hlg.balanceOf(alice);
        assertEq(aliceHlgAfter - aliceHlgBefore, 150 ether);
    }

    function test_DistributionsAllowedWhilePaused() public {
        vm.prank(owner);
        staking.pause();
        // With no eligible stake, deposit is a no-op but should not revert
        vm.startPrank(owner);
        hlg.approve(address(staking), 10 ether);
        staking.depositAndDistribute(10 ether);
        vm.stopPrank();
    }
}
