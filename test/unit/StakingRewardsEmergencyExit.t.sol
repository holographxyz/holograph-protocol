// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {StakingRewards} from "../../src/StakingRewards.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract StakingRewardsEmergencyExitTest is Test {
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

    function test_EmergencyExitGhostEligibilityFix() public {
        // Alice stakes and becomes eligible
        vm.startPrank(alice);
        hlg.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();
        _rollEpoch(); // Alice now eligible

        // Distribute rewards to trigger compounding
        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether);
        vm.stopPrank();
        _rollEpoch(); // Rewards mature, Alice's compounded amount scheduled for next epoch

        // At this point:
        // - Alice has pending activation from compounding (scheduled additions)
        // - When epoch rolled, eligibleTotal was increased by Alice's compounded amount
        // - But Alice's individual eligibleBalanceOf hasn't been updated (she didn't call updateUser)

        uint256 eligibleTotalBefore = staking.eligibleTotal();
        uint256 aliceEligibleBefore = staking.eligibleBalanceOf(alice);

        // Alice emergency exits WITHOUT calling updateUser first
        // This should properly handle the ghost eligibility
        vm.prank(alice);
        staking.emergencyExit();

        // Roll to next epoch to process the scheduled removals
        _rollEpoch();

        uint256 eligibleTotalAfter = staking.eligibleTotal();

        // The fix should ensure that eligibleTotal is properly reduced
        // It should account for both Alice's active eligible balance AND her ghost pending activation
        assertEq(eligibleTotalAfter, 0, "eligibleTotal should be zero after removing all of Alice's eligibility");

        // Verify Alice can successfully finalize her withdrawal
        vm.prank(alice);
        staking.finalizeUnstake();

        // Alice should get her full compounded balance back
        assertGt(hlg.balanceOf(alice), 100 ether, "Alice should have received compounded rewards");
    }

    function test_EmergencyExitEligibleTotalConsistency() public {
        // Alice stakes and becomes eligible
        vm.startPrank(alice);
        hlg.approve(address(staking), 100 ether);
        staking.stake(100 ether);
        vm.stopPrank();
        _rollEpoch(); // Alice now eligible

        // Distribute rewards to trigger compounding
        vm.startPrank(owner);
        hlg.approve(address(staking), 100 ether);
        staking.depositAndDistribute(100 ether);
        vm.stopPrank();
        _rollEpoch(); // Rewards mature

        // Alice does NOT call updateUser, creating ghost eligibility scenario
        // At this point, eligibleTotal was increased during epoch roll due to scheduled additions
        // But Alice's individual eligibleBalanceOf was not updated

        uint256 eligibleTotalBefore = staking.eligibleTotal();

        // Alice emergency exits without ever activating her matured pending amount
        vm.prank(alice);
        staking.emergencyExit();

        // Roll epoch to process scheduled removals
        _rollEpoch();

        uint256 eligibleTotalAfter = staking.eligibleTotal();

        // The fix ensures eligibleTotal accounts for ghost eligibility removal
        assertEq(eligibleTotalAfter, 0, "eligibleTotal should be zero with no remaining stakers");

        vm.prank(alice);
        staking.finalizeUnstake();

        assertGt(hlg.balanceOf(alice), 100 ether, "Alice should get compounded rewards");
    }
}
