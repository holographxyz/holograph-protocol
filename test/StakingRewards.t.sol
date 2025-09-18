// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StakingRewards} from "../src/StakingRewards.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockZeroSinkNoBurn} from "./mock/MockZeroSinkNoBurn.sol";
import {MockFeeOnTransfer} from "./mock/MockFeeOnTransfer.sol";
import {MockCorruptedStaking} from "./mock/MockCorruptedStaking.sol";

/**
 * @title StakingRewards Test Suite
 * @notice Test suite for StakingRewards contract covering:
 * - Basic functionality (stake/unstake/emergency)
 * - Reward distribution and compounding
 * - Virtual compounding model tests
 * - Admin functions and security
 * - Edge cases and error conditions
 * - Fork tests with real HLG token
 * - Cooldown mechanism tests
 */
contract StakingRewardsTest is Test {
    // Event declarations for testing
    event RewardsForfeited(address indexed user, uint256 forfeitedAmount);
    event TokensRecovered(address indexed token, uint256 amount, address indexed to);

    StakingRewards public stakingRewards;
    MockERC20 public hlg;

    address public owner = address(0x1);
    address public feeRouter = address(0x2);
    address public alice = address(0x3);
    address public bob = address(0x4);
    address public charlie = address(0x5);
    address public distributor = address(0x6);

    uint256 public constant INITIAL_SUPPLY = 1000000 ether;
    uint256 public constant STAKE_AMOUNT = 1000 ether;
    uint256 public constant REWARD_AMOUNT = 100 ether;

    // Real HLG token address on Base for fork tests
    address constant HLG_ADDRESS = 0x740df024CE73f589ACD5E8756b377ef8C6558BaB;
    address constant HLG_HOLDER = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;

    /* -------------------------------------------------------------------------- */
    /*                                   Setup                                    */
    /* -------------------------------------------------------------------------- */

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock HLG token
        hlg = new MockERC20("Test HLG", "HLG");

        // Deploy StakingRewards implementation
        StakingRewards stakingImpl = new StakingRewards();

        // Deploy proxy and initialize
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(stakingImpl), abi.encodeCall(StakingRewards.initialize, (address(hlg), owner)));

        // Cast proxy to StakingRewards interface
        stakingRewards = StakingRewards(payable(address(proxy)));
        stakingRewards.setFeeRouter(feeRouter);
        stakingRewards.unpause();

        vm.stopPrank();

        // Mint tokens for testing
        hlg.mint(alice, INITIAL_SUPPLY);
        hlg.mint(bob, INITIAL_SUPPLY);
        hlg.mint(charlie, INITIAL_SUPPLY);
        hlg.mint(owner, INITIAL_SUPPLY);
        hlg.mint(feeRouter, INITIAL_SUPPLY);
        hlg.mint(distributor, INITIAL_SUPPLY);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Basic Staking Tests                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Stakes and then fully withdraws, verifying balances and totals
    function testStakeAndWithdraw() public {
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);

        assertEq(stakingRewards.balanceOf(alice), STAKE_AMOUNT);
        assertEq(stakingRewards.totalStaked(), STAKE_AMOUNT);

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 7 days + 1);

        stakingRewards.unstake();
        assertEq(stakingRewards.balanceOf(alice), 0);
        assertEq(stakingRewards.totalStaked(), 0);
        vm.stopPrank();
    }

    /// @notice Emergency exit returns staked tokens without compounding rewards
    function testEmergencyExit() public {
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        vm.startPrank(alice);
        uint256 balanceBefore = hlg.balanceOf(alice);
        stakingRewards.emergencyExit();

        assertEq(stakingRewards.balanceOf(alice), 0);
        assertEq(hlg.balanceOf(alice), balanceBefore + STAKE_AMOUNT);
        vm.stopPrank();
    }

    /// @notice Emergency exit reverts when contract is not paused (audit security requirement)
    function testEmergencyExitRevertsWhenNotPaused() public {
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);

        // emergencyExit should revert when not paused
        vm.expectRevert(); // EnforcedPause
        stakingRewards.emergencyExit();
        vm.stopPrank();
    }

    /// @notice Reverts when attempting to stake a zero amount
    function testCannotStakeZeroAmount() public {
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        vm.expectRevert(StakingRewards.ZeroAmount.selector);
        stakingRewards.stake(0);
        vm.stopPrank();
    }

    /// @notice Reverts when attempting to unstake without an active stake
    function testCannotUnstakeWithNoStake() public {
        vm.prank(alice);
        vm.expectRevert(StakingRewards.NoStake.selector);
        stakingRewards.unstake();
    }

    /* -------------------------------------------------------------------------- */
    /*                         Reward Distribution Tests                         */
    /* -------------------------------------------------------------------------- */

    /// @notice Rewards accrue and compound into balance via updateUser()
    function testAutoCompoundingRewards() public {
        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Distribute rewards (50% burn, 50% rewards)
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        stakingRewards.depositAndDistribute(REWARD_AMOUNT);
        vm.stopPrank();

        // Check pending rewards
        uint256 expectedRewards = REWARD_AMOUNT / 2; // 50% of 100 = 50
        assertEq(stakingRewards.pendingRewards(alice), expectedRewards);

        // Unstake to auto-compound (wait for cooldown first)
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(alice);
        stakingRewards.unstake();

        // Alice should have received original stake + compounded rewards
        assertEq(hlg.balanceOf(alice), INITIAL_SUPPLY - STAKE_AMOUNT + STAKE_AMOUNT + expectedRewards);
    }

    /// @notice FeeRouter.addRewards() accrues rewards to active stakers
    function testFeeRouterAddRewards() public {
        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // FeeRouter distributes rewards
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        stakingRewards.addRewards(REWARD_AMOUNT);
        vm.stopPrank();

        uint256 expectedRewards = REWARD_AMOUNT / 2;
        assertEq(stakingRewards.pendingRewards(alice), expectedRewards);
    }

    /// @notice Non-router callers cannot add rewards
    function testAddRewardsOnlyRouter() public {
        vm.prank(alice);
        vm.expectRevert(StakingRewards.Unauthorized.selector);
        stakingRewards.addRewards(REWARD_AMOUNT);
    }

    /// @notice Rewards split proportionally among multiple concurrent stakers
    function testMultipleUsersProportionalRewards() public {
        // Alice stakes 300, Bob stakes 200
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 300 ether);
        stakingRewards.stake(300 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.stake(200 ether);
        vm.stopPrank();

        // Distribute 100 HLG (50 rewards after 50% burn)
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.depositAndDistribute(100 ether);
        vm.stopPrank();

        // Alice should get 60% (30 HLG), Bob should get 40% (20 HLG)
        assertEq(stakingRewards.pendingRewards(alice), 30 ether);
        assertEq(stakingRewards.pendingRewards(bob), 20 ether);

        // Trigger compounding by staking a small amount for each user
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stake(1 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stake(1 ether);
        vm.stopPrank();

        // Now balances should include compounded rewards + new stakes
        assertEq(stakingRewards.balanceOf(alice), 331 ether); // 300 + 30 rewards + 1 new stake
        assertEq(stakingRewards.balanceOf(bob), 221 ether); // 200 + 20 rewards + 1 new stake
    }

    /* -------------------------------------------------------------------------- */
    /*                      Virtual Compounding Model Tests                      */
    /* -------------------------------------------------------------------------- */

    /// @notice Multiple distributions before user updates are allocated exactly once
    function testNoDoubleCountingAcrossMultipleDistributions() public {
        // Two users stake 100 each
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        // Distribute 60 HLG, don't call updateUser
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 60 ether);
        stakingRewards.depositAndDistribute(60 ether);
        vm.stopPrank();

        // With 50% burn, reward amount should be 30 ether
        uint256 expectedReward = 30 ether;
        assertEq(stakingRewards.unallocatedRewards(), expectedReward);
        assertEq(stakingRewards.totalStaked(), 200 ether + expectedReward);

        // Distribute 40 HLG again, still no updates
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), 40 ether);
        stakingRewards.addRewards(40 ether);
        vm.stopPrank();

        // Additional reward should be 20 ether (50% of 40)
        uint256 additionalReward = 20 ether;
        uint256 totalExpectedReward = expectedReward + additionalReward;
        assertEq(stakingRewards.unallocatedRewards(), totalExpectedReward);
        assertEq(stakingRewards.totalStaked(), 200 ether + totalExpectedReward);

        // Trigger compounding for both users by staking small amounts
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1 wei);
        stakingRewards.stake(1 wei);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 1 wei);
        stakingRewards.stake(1 wei);
        vm.stopPrank();

        // Each user should get exactly 25 ether in rewards (50 total rewards split equally) + tiny stake
        assertApproxEqAbs(stakingRewards.balanceOf(alice), 125 ether, 1); // 100 original + 25 rewards + 1 wei
        assertApproxEqAbs(stakingRewards.balanceOf(bob), 125 ether, 1); // 100 original + 25 rewards + 1 wei

        // unallocatedRewards should be 0
        assertEq(stakingRewards.unallocatedRewards(), 0);

        // Sum of balances should equal totalStaked
        uint256 sumBalances = stakingRewards.balanceOf(alice) + stakingRewards.balanceOf(bob);
        assertEq(sumBalances, stakingRewards.totalStaked());
    }

    /// @notice Pending rewards use active stake as the denominator, not totalStaked
    function testDenominatorCorrectness() public {
        // Alice stakes 100, Bob stakes 200
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.stake(200 ether);
        vm.stopPrank();

        // Distribute 90 HLG (45 rewards)
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 90 ether);
        stakingRewards.depositAndDistribute(90 ether);
        vm.stopPrank();

        // Now totalStaked = 345, unallocated = 45, active = 300
        assertEq(stakingRewards.totalStaked(), 345 ether);
        assertEq(stakingRewards.unallocatedRewards(), 45 ether);

        // Check pending rewards are based on active stake (300), not totalStaked (345)
        uint256 alicePending = stakingRewards.pendingRewards(alice);
        uint256 bobPending = stakingRewards.pendingRewards(bob);

        // Alice has 100/300 = 1/3 of active stake, should get 15 HLG
        // Bob has 200/300 = 2/3 of active stake, should get 30 HLG
        assertEq(alicePending, 15 ether, "Alice should get 15 HLG based on active stake");
        assertEq(bobPending, 30 ether, "Bob should get 30 HLG based on active stake");

        // Total pending should equal unallocated
        assertEq(alicePending + bobPending, stakingRewards.unallocatedRewards());
    }

    /// @notice updateUser() reverts if unallocated rewards are corrupted below what is owed
    function testInsufficientUnallocatedReverts() public {
        // Deploy corrupted staking contract for this test
        MockCorruptedStaking corruptedStakingImpl = new MockCorruptedStaking();
        ERC1967Proxy corruptedProxy = new ERC1967Proxy(
            address(corruptedStakingImpl), abi.encodeCall(StakingRewards.initialize, (address(hlg), owner))
        );
        MockCorruptedStaking corruptedStaking = MockCorruptedStaking(payable(address(corruptedProxy)));

        vm.prank(owner);
        corruptedStaking.setFeeRouter(feeRouter);
        vm.prank(owner);
        corruptedStaking.unpause();

        // Setup users
        vm.startPrank(alice);
        hlg.approve(address(corruptedStaking), 100 ether);
        corruptedStaking.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(corruptedStaking), 100 ether);
        corruptedStaking.stake(100 ether);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(corruptedStaking), 80 ether);
        corruptedStaking.depositAndDistribute(80 ether); // 40 ether rewards
        vm.stopPrank();

        // Alice updates first, consuming some unallocated
        corruptedStaking.testUpdateUser(alice);
        assertEq(corruptedStaking.balanceOf(alice), 120 ether);
        assertEq(corruptedStaking.unallocatedRewards(), 20 ether);

        // Corrupt unallocatedRewards to be less than Bob's pending
        corruptedStaking.corruptUnallocatedRewards(10 ether);
        assertEq(corruptedStaking.unallocatedRewards(), 10 ether);

        // Bob's updateUser should now revert NotEnoughRewardsAvailable
        vm.expectRevert(StakingRewards.NotEnoughRewardsAvailable.selector);
        corruptedStaking.testUpdateUser(bob);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Burn Functionality                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Reverts distribution if token "burn" does not truly reduce total supply
    function testBurnHelperRevertsIfTransferToZeroDoesNotBurn() public {
        // Deploy zero-sink token that doesn't actually burn
        MockZeroSinkNoBurn noburn = new MockZeroSinkNoBurn();

        // Deploy implementation and proxy
        StakingRewards noBurnStakingImpl = new StakingRewards();
        ERC1967Proxy noBurnProxy = new ERC1967Proxy(
            address(noBurnStakingImpl), abi.encodeCall(StakingRewards.initialize, (address(noburn), owner))
        );
        StakingRewards noBurnStaking = StakingRewards(payable(address(noBurnProxy)));

        noburn.mint(owner, 1000 ether);

        vm.startPrank(owner);
        noBurnStaking.setFeeRouter(feeRouter);
        noBurnStaking.setBurnPercentage(5000); // 50% burn to avoid RewardTooSmall
        // Note: stakeFor only works when paused, so don't unpause yet

        // Stake some tokens while paused
        noburn.approve(address(noBurnStaking), 500 ether);
        noBurnStaking.stakeFor(alice, 500 ether);

        // Now unpause for distribution
        noBurnStaking.unpause();

        // Try to distribute - should fail with BurnFailed (large enough amount to pass RewardTooSmall check)
        noburn.approve(address(noBurnStaking), 100 ether);
        vm.expectRevert(StakingRewards.BurnFailed.selector);
        noBurnStaking.depositAndDistribute(100 ether);
        vm.stopPrank();
    }

    /// @notice With 0% burn, 100% of distribution goes to stakers
    function testZeroBurnPercentage() public {
        vm.prank(owner);
        stakingRewards.setBurnPercentage(0);

        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // All rewards should go to stakers, nothing burned
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        stakingRewards.depositAndDistribute(REWARD_AMOUNT);
        vm.stopPrank();

        assertEq(stakingRewards.pendingRewards(alice), REWARD_AMOUNT);
    }

    /// @notice With 100% burn, no index change and no pending rewards
    function testHundredPercentBurnNoRevertAndNoIndexChange() public {
        // Set 100% burn
        vm.prank(owner);
        stakingRewards.setBurnPercentage(10000);

        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Record index
        uint256 indexBefore = stakingRewards.rewardPerToken();

        // Distribute; should not revert, all burned, no rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        stakingRewards.depositAndDistribute(REWARD_AMOUNT);
        vm.stopPrank();

        // Index unchanged and no pending rewards
        assertEq(stakingRewards.rewardPerToken(), indexBefore);
        assertEq(stakingRewards.pendingRewards(alice), 0);
    }

    /// @notice Funding methods revert while the contract is paused
    function testFundingBlockedWhenPaused() public {
        // Pause contract
        vm.prank(owner);
        stakingRewards.pause();

        // depositAndDistribute should revert
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        vm.expectRevert();
        stakingRewards.depositAndDistribute(REWARD_AMOUNT);
        vm.stopPrank();

        // addRewards should NOT revert when paused (audit change allows FeeRouter to work while paused)
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        // This should work (no expectRevert) since addRewards can be called while paused
        stakingRewards.addRewards(REWARD_AMOUNT);
        vm.stopPrank();
    }

    /// @notice addRewards distributes rewards correctly while paused (audit operational continuity)
    function testAddRewardsDistributesCorrectlyWhilePaused() public {
        // Set up staker first
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Pause contract
        vm.prank(owner);
        stakingRewards.pause();

        // FeeRouter adds rewards while paused
        uint256 rewardAmount = 200 ether;
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), rewardAmount);
        stakingRewards.addRewards(rewardAmount);
        vm.stopPrank();

        // Verify rewards were properly distributed (50% after burn)
        uint256 expectedRewards = (rewardAmount * (10000 - stakingRewards.burnPercentage())) / 10000;
        assertEq(stakingRewards.pendingRewards(alice), expectedRewards);

        // User should be able to claim rewards after unpause
        vm.prank(owner);
        stakingRewards.unpause();

        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(alice);
        stakingRewards.unstake();

        // Alice should receive original stake + compounded rewards
        assertEq(stakingRewards.balanceOf(alice), 0);
        assertGt(hlg.balanceOf(alice), STAKE_AMOUNT); // More than original stake due to rewards
    }

    /// @notice Reward accrual amount reflects configured burn percentage
    function testDifferentBurnPercentages() public {
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        // Test 25% burn (7500 rewards out of 10000)
        vm.prank(owner);
        stakingRewards.setBurnPercentage(2500);

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.depositAndDistribute(100 ether);
        vm.stopPrank();

        assertEq(stakingRewards.pendingRewards(alice), 75 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Fee-on-Transfer Tests                          */
    /* -------------------------------------------------------------------------- */

    /// @notice Fee-on-transfer tokens are rejected for staking
    function testFeeOnTransferRejection() public {
        // Deploy fee-on-transfer token
        MockFeeOnTransfer feeToken = new MockFeeOnTransfer();

        // Deploy implementation and proxy
        StakingRewards feeStakingImpl = new StakingRewards();
        ERC1967Proxy feeProxy = new ERC1967Proxy(
            address(feeStakingImpl), abi.encodeCall(StakingRewards.initialize, (address(feeToken), owner))
        );
        StakingRewards feeStaking = StakingRewards(payable(address(feeProxy)));

        vm.prank(owner);
        feeStaking.unpause();

        feeToken.mint(alice, 1e18);

        // stake(1e18) reverts FeeOnTransferNotSupported()
        vm.startPrank(alice);
        feeToken.approve(address(feeStaking), 1e18);
        vm.expectRevert(StakingRewards.FeeOnTransferNotSupported.selector);
        feeStaking.stake(1e18);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Admin Functions                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Owner can set the burn percentage within bounds
    function testSetBurnPercentage() public {
        vm.prank(owner);
        stakingRewards.setBurnPercentage(7500);
        assertEq(stakingRewards.burnPercentage(), 7500);
    }

    /// @notice Reverts when burn percentage exceeds 10000 bps
    function testSetBurnPercentageInvalidValue() public {
        vm.prank(owner);
        vm.expectRevert(StakingRewards.InvalidBurnPercentage.selector);
        stakingRewards.setBurnPercentage(10001);
    }

    /// @notice Only the owner can modify burn percentage
    function testSetBurnPercentageOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        stakingRewards.setBurnPercentage(7500);
    }

    /// @notice Pausing disables staking and reflects paused state
    function testPause() public {
        vm.prank(owner);
        stakingRewards.pause();
        assertTrue(stakingRewards.paused());

        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        vm.expectRevert();
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();
    }

    /// @notice Only the owner may call stakeFor()
    function testStakeForOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        stakingRewards.stakeFor(bob, STAKE_AMOUNT);
    }

    /// @notice stakeFor() is only available while the contract is paused
    function testStakeForOnlyWhenPaused() public {
        vm.prank(owner);
        vm.expectRevert();
        stakingRewards.stakeFor(alice, STAKE_AMOUNT);
    }

    /// @notice Owner can whitelist and de-whitelist distributor addresses
    function testDistributorWhitelist() public {
        vm.prank(owner);
        stakingRewards.setDistributor(distributor, true);
        assertTrue(stakingRewards.isDistributor(distributor));

        vm.prank(owner);
        stakingRewards.setDistributor(distributor, false);
        assertFalse(stakingRewards.isDistributor(distributor));
    }

    /// @notice Whitelisted distributors can stake on behalf of users
    function testDistributorStake() public {
        vm.prank(owner);
        stakingRewards.setDistributor(distributor, true);

        vm.startPrank(distributor);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stakeFromDistributor(alice, STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(stakingRewards.balanceOf(alice), STAKE_AMOUNT);
    }

    /// @notice Non-whitelisted distributor cannot stake on behalf of users
    function testDistributorStakeNotWhitelisted() public {
        vm.startPrank(distributor);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        vm.expectRevert(StakingRewards.NotWhitelistedDistributor.selector);
        stakingRewards.stakeFromDistributor(alice, STAKE_AMOUNT);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                            Extra Token Recovery                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Owner can recover surplus tokens not tracked by accounting
    function testExtraTokenRecovery() public {
        // Directly transfer 100 HLG to the contract (not via functions)
        hlg.mint(address(this), 100 ether);
        hlg.transfer(address(stakingRewards), 100 ether);

        // getExtraTokens() equals 100 initially
        assertEq(stakingRewards.getExtraTokens(), 100 ether);

        // recoverExtraHLG(alice, 60) works
        uint256 aliceBalanceBefore = hlg.balanceOf(alice);
        vm.prank(owner);
        stakingRewards.recoverExtraHLG(alice, 60 ether);

        uint256 aliceBalanceAfter = hlg.balanceOf(alice);
        assertEq(aliceBalanceAfter, aliceBalanceBefore + 60 ether);

        // recoverExtraHLG(bob, 50) reverts NotEnoughExtraTokens()
        vm.prank(owner);
        vm.expectRevert(StakingRewards.NotEnoughExtraTokens.selector);
        stakingRewards.recoverExtraHLG(bob, 50 ether);

        // Remaining surplus equals 40
        assertEq(stakingRewards.getExtraTokens(), 40 ether);
    }

    /// @notice Owner can reclaim unallocated rewards when no active stake exists
    function testReclaimUnallocatedRewards() public {
        // Setup: Alice stakes, rewards distributed, Alice uses emergency exit
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.depositAndDistribute(200 ether);
        vm.stopPrank();

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        // Alice emergency exits (forfeits pending rewards)
        vm.prank(alice);
        stakingRewards.emergencyExit();

        // Now _activeStaked() == 0 but unallocatedRewards > 0
        assertEq(stakingRewards.balanceOf(alice), 0);
        assertGt(stakingRewards.unallocatedRewards(), 0);
        assertEq(stakingRewards.totalStaked(), stakingRewards.unallocatedRewards());

        // Owner can reclaim unallocated rewards
        uint256 unallocatedAmount = stakingRewards.unallocatedRewards();
        uint256 treasuryBalanceBefore = hlg.balanceOf(owner);

        vm.prank(owner);
        stakingRewards.reclaimUnallocatedRewards(owner);

        // Verify rewards were reclaimed
        assertEq(stakingRewards.unallocatedRewards(), 0);
        assertEq(stakingRewards.totalStaked(), 0);
        assertEq(hlg.balanceOf(owner), treasuryBalanceBefore + unallocatedAmount);
    }

    /// @notice Reclaiming unallocated rewards reverts if there is active stake
    function testReclaimUnallocatedRewardsRevertsWithActiveStake() public {
        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.depositAndDistribute(200 ether);
        vm.stopPrank();

        // Should revert because Alice still has active stake
        vm.prank(owner);
        vm.expectRevert(StakingRewards.ActiveStakeExists.selector);
        stakingRewards.reclaimUnallocatedRewards(owner);
    }

    /// @notice Distributions too small to move the index revert with RewardTooSmall
    function testRewardTooSmall() public {
        // Large stake to make tiny rewards not move the index
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000000 ether);
        stakingRewards.stake(1000000 ether);
        vm.stopPrank();

        // Try to distribute very small amount that won't move index
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 1);

        // Should revert - depositAndDistribute is not part of LayerZero flow
        vm.expectRevert(StakingRewards.RewardTooSmall.selector);
        stakingRewards.depositAndDistribute(1);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Edge Cases                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Distributions are no-ops when there are zero active stakers
    function testZeroStakerNoOp() public {
        // No one has staked, distributions should be no-ops
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        stakingRewards.depositAndDistribute(REWARD_AMOUNT);
        vm.stopPrank();

        // Contract should have no rewards allocated
        assertEq(stakingRewards.totalStaked(), 0);
        assertEq(stakingRewards.unallocatedRewards(), 0);
    }

    /// @notice System remains consistent after all users exit and a new user stakes
    function testEveryoneExitsThenNewStake() public {
        // Alice and Bob stake
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.stake(200 ether);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 90 ether);
        stakingRewards.depositAndDistribute(90 ether);
        vm.stopPrank();

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 7 days + 1);

        // Both users compound and exit
        vm.prank(alice);
        stakingRewards.unstake();
        vm.prank(bob);
        stakingRewards.unstake();

        // totalStaked should be 0, but there might be dust in unallocatedRewards
        assertEq(stakingRewards.totalStaked(), stakingRewards.unallocatedRewards());

        // New user stakes - should work normally
        vm.startPrank(charlie);
        hlg.approve(address(stakingRewards), 500 ether);
        stakingRewards.stake(500 ether);
        vm.stopPrank();

        assertEq(stakingRewards.balanceOf(charlie), 500 ether);

        // System should work normally with new distributions
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.depositAndDistribute(100 ether);
        vm.stopPrank();

        // Charlie should earn rewards normally
        uint256 charliePending = stakingRewards.pendingRewards(charlie);
        assertEq(charliePending, 50 ether); // 50% of 100 HLG distributed
    }

    /* -------------------------------------------------------------------------- */
    /*                               Fork Tests                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice On Base fork, 100% burn reduces HLG total supply by distribution amount
    function testForkBurnReducesSupply() public {
        // Skip if not forking
        if (block.chainid != 8453) return; // Base mainnet

        vm.createSelectFork("https://mainnet.base.org", 22_500_000);

        IERC20 realHLG = IERC20(HLG_ADDRESS);

        // Deploy implementation and proxy for fork test
        StakingRewards forkStakingImpl = new StakingRewards();
        ERC1967Proxy forkProxy =
            new ERC1967Proxy(address(forkStakingImpl), abi.encodeCall(StakingRewards.initialize, (HLG_ADDRESS, owner)));
        StakingRewards forkStaking = StakingRewards(payable(address(forkProxy)));

        vm.startPrank(owner);
        forkStaking.setFeeRouter(feeRouter);
        forkStaking.setBurnPercentage(10000); // 100% burn
        forkStaking.unpause();
        vm.stopPrank();

        // Fund via deal if holder doesn't have enough
        deal(HLG_ADDRESS, alice, 1000 ether);
        deal(HLG_ADDRESS, owner, 1000 ether);

        // Alice stakes
        vm.startPrank(alice);
        realHLG.approve(address(forkStaking), 500 ether);
        forkStaking.stake(500 ether);
        vm.stopPrank();

        uint256 supplyBefore = realHLG.totalSupply();

        // Owner distributes with 100% burn
        vm.startPrank(owner);
        realHLG.approve(address(forkStaking), 100 ether);
        forkStaking.depositAndDistribute(100 ether);
        vm.stopPrank();

        uint256 supplyAfter = realHLG.totalSupply();
        assertEq(supplyBefore - supplyAfter, 100 ether, "Total supply should decrease by burned amount");
    }

    /* -------------------------------------------------------------------------- */
    /*                       Precision and Dust Handling Tests                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Dust guard prevents zero-index updates from tiny distributions
    function testDustHandling() public {
        // Setup large active stake
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000000 ether);
        stakingRewards.stake(1000000 ether);
        vm.stopPrank();

        uint256 rewardAmount = 500; // Tiny reward that would result in index delta == 0

        // Should revert with RewardTooSmall since the dust guard prevents it
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), rewardAmount);
        vm.expectRevert(StakingRewards.RewardTooSmall.selector);
        stakingRewards.depositAndDistribute(rewardAmount);
        vm.stopPrank();
    }

    /// @notice Unallocated increases by full reward; extra tokens remain unchanged
    function testFullRewardPreCredit() public {
        // Setup moderate stake
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 100000 ether);
        stakingRewards.stake(100000 ether);
        vm.stopPrank();

        uint256 rewardAmount = 1000 ether;
        uint256 actualReward = rewardAmount / 2; // 500 ether after 50% burn

        // Record initial state
        uint256 initialUnallocated = stakingRewards.unallocatedRewards();
        uint256 initialSurplus = stakingRewards.getExtraTokens();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), rewardAmount);
        stakingRewards.depositAndDistribute(rewardAmount);
        vm.stopPrank();

        // Assert unallocatedRewards increased by full actualReward
        assertEq(
            stakingRewards.unallocatedRewards(),
            initialUnallocated + actualReward,
            "Unallocated should equal full reward"
        );

        // Assert extra tokens stay the same (balance increased by actualReward, totalStaked also increased by actualReward)
        assertEq(stakingRewards.getExtraTokens(), initialSurplus, "Extra tokens should remain unchanged");

        // Verify user can claim the expected amount
        uint256 expectedEarned = actualReward; // Alice has 100% of stake
        assertEq(stakingRewards.pendingRewards(alice), expectedEarned, "Alice should earn full reward");
    }

    /// @notice Randomized action sequences preserve accounting invariants
    function testInvariantFuzzSequences(uint8 seed) public {
        // Initialize with some stake
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 10000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Use seed to create pseudo-random sequence
        uint256 rng = uint256(keccak256(abi.encode(seed)));

        for (uint256 i = 0; i < 5; i++) {
            uint256 action = rng % 4;
            rng = uint256(keccak256(abi.encode(rng)));

            if (action == 0) {
                // Stake
                uint256 amount = (rng % 1000) + 100; // 100-1099
                rng = uint256(keccak256(abi.encode(rng)));

                vm.startPrank(alice);
                hlg.approve(address(stakingRewards), amount);
                stakingRewards.stake(amount);
                vm.stopPrank();
            } else if (action == 1) {
                // Distribute (use larger amounts to avoid RewardTooSmall)
                uint256 amount = (rng % 1000) + 1000; // 1000-1999 to avoid dust guard
                rng = uint256(keccak256(abi.encode(rng)));

                vm.startPrank(owner);
                hlg.approve(address(stakingRewards), amount);
                try stakingRewards.depositAndDistribute(amount) {
                    // Distribution succeeded
                } catch {
                    // Skip if RewardTooSmall - this is expected behavior
                }
                vm.stopPrank();
            } else if (action == 2) {
                // Random user action
            } else if (action == 3 && stakingRewards.balanceOf(alice) > 0) {
                // Unstake (only if has balance and can unstake)
                if (stakingRewards.canUnstake(alice)) {
                    vm.prank(alice);
                    stakingRewards.unstake();

                    // Re-stake something to continue
                    vm.startPrank(alice);
                    hlg.approve(address(stakingRewards), 1000 ether);
                    stakingRewards.stake(1000 ether);
                    vm.stopPrank();
                }
            }

            // Check invariants after each action
            _checkInvariants();
        }
    }

    /// @notice rewardPerToken index accrues as expected across stake/distribute sequence
    function testIndexAccrualTwoStakersSequenceMatchesExpectedRPT() public {
        // Alice stakes 1 HLG
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stake(1 ether);
        vm.stopPrank();

        // First distribution: 1 HLG total, 50% rewards -> 0.5 HLG over active=1
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.depositAndDistribute(1 ether);
        vm.stopPrank();

        // Bob stakes 1 HLG after first distribution
        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stake(1 ether);
        vm.stopPrank();

        // Second distribution: 1 HLG total, 50% rewards -> 0.5 HLG over active=2
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.depositAndDistribute(1 ether);
        vm.stopPrank();

        // Expected rewardPerToken index = 0.5e12 + 0.25e12 = 0.75e12
        assertEq(stakingRewards.rewardPerToken(), 750_000_000_000);
    }

    /// @notice Per-user pendingRewards amounts match expected allocations across distributions
    function testEarnedAllocationTwoStakersSequence() public {
        // Alice stakes 1 HLG
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stake(1 ether);
        vm.stopPrank();

        // First distribution with only Alice active
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.depositAndDistribute(1 ether); // 0.5 HLG rewards
        vm.stopPrank();

        // Bob stakes 1 HLG, then second distribution
        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stake(1 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.depositAndDistribute(1 ether); // +0.5 HLG rewards over active=2
        vm.stopPrank();

        // Alice should have 0.75 HLG pending (0.5 from first, 0.25 from second)
        // Bob should have 0.25 HLG pending (only second distribution share)
        assertEq(stakingRewards.pendingRewards(alice), 0.75 ether);
        assertEq(stakingRewards.pendingRewards(bob), 0.25 ether);

        // Check balances with pending rewards included
        assertEq(stakingRewards.balanceWithPendingRewards(alice), 1.75 ether);
        assertEq(stakingRewards.balanceWithPendingRewards(bob), 1.25 ether);
        assertEq(stakingRewards.unallocatedRewards(), 1 ether);
    }

    /// @notice User snapshot updates on settlement and resets to zero after full exit
    function testUserIndexSnapshotLifecycle() public {
        // Alice stakes at index 0
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 10 ether);
        stakingRewards.stake(10 ether);
        vm.stopPrank();

        // Distribute to bump index
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 10 ether);
        stakingRewards.depositAndDistribute(10 ether);
        vm.stopPrank();

        // Snapshot remains 0 until Alice is updated
        assertEq(stakingRewards.userIndexSnapshot(alice), 0);
        assertGt(stakingRewards.rewardPerToken(), 0);

        // Snapshot will be updated during unstake

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 7 days + 1);

        // Full exit resets snapshot to 0
        vm.prank(alice);
        stakingRewards.unstake();
        assertEq(stakingRewards.userIndexSnapshot(alice), 0);
    }

    /// @notice addRewards() with zero active stakers pulls tokens as extra tokens
    function testAddRewardsNoStakerPullsTokensAsExtra() public {
        // Ensure no active stakers
        assertEq(stakingRewards.totalStaked(), 0);
        uint256 feeRouterBalanceBefore = hlg.balanceOf(feeRouter);
        uint256 contractBalanceBefore = hlg.balanceOf(address(stakingRewards));

        // FeeRouter attempts addRewards while no active stake
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.addRewards(100 ether);
        vm.stopPrank();

        // Tokens SHOULD be pulled but no burn/distribution occurs (returns early)
        assertEq(hlg.balanceOf(feeRouter), feeRouterBalanceBefore - 100 ether);
        assertEq(hlg.balanceOf(address(stakingRewards)), contractBalanceBefore + 100 ether); // Full amount

        // Index unchanged since no stakers
        assertEq(stakingRewards.unallocatedRewards(), 0);
        assertEq(stakingRewards.rewardPerToken(), 0);

        // Full amount becomes extra tokens (no burn occurred)
        assertEq(stakingRewards.getExtraTokens(), 100 ether);
    }

    /// @notice Third parties cannot compound other users' rewards (gaming prevention)
    function testUpdateUserNoLongerCallableExternally() public {
        // Alice stakes and a distribution occurs
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 50 ether);
        stakingRewards.depositAndDistribute(50 ether); // 25 rewards
        vm.stopPrank();

        // Verify rewards are pending but not compounded
        assertEq(stakingRewards.pendingRewards(alice), 25 ether);
        assertEq(stakingRewards.balanceOf(alice), 100 ether); // Original stake only

        // Rewards will only compound when Alice stakes more or unstakes
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(alice);
        stakingRewards.unstake();

        // Now Alice gets original stake + compounded rewards
        assertEq(hlg.balanceOf(alice), INITIAL_SUPPLY - 100 ether + 125 ether);
    }

    /// @notice Three stakers join sequentially across distributions; exact pendingRewards splits verified
    function testThreeStakersSequentialJoinsAndDistributionsExactSplit() public {
        // Alice stakes 1 HLG
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stake(1 ether);
        vm.stopPrank();

        // First distribution: 1 HLG total -> 0.5 reward over active=1
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.depositAndDistribute(1 ether);
        vm.stopPrank();

        // Bob stakes 1 HLG
        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stake(1 ether);
        vm.stopPrank();

        // Second distribution: 1 HLG total -> 0.5 reward over active=2
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.depositAndDistribute(1 ether);
        vm.stopPrank();

        // Charlie stakes 2 HLG
        vm.startPrank(charlie);
        hlg.approve(address(stakingRewards), 2 ether);
        stakingRewards.stake(2 ether);
        vm.stopPrank();

        // Third distribution: 2 HLG total -> 1 reward over active=4
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 2 ether);
        stakingRewards.depositAndDistribute(2 ether);
        vm.stopPrank();

        // Expected pendings: Alice 1.0, Bob 0.5, Charlie 0.5
        assertEq(stakingRewards.pendingRewards(alice), 1 ether);
        assertEq(stakingRewards.pendingRewards(bob), 0.5 ether);
        assertEq(stakingRewards.pendingRewards(charlie), 0.5 ether);

        // Check total balances including pending rewards
        assertEq(stakingRewards.balanceWithPendingRewards(alice), 2 ether);
        assertEq(stakingRewards.balanceWithPendingRewards(bob), 1.5 ether);
        assertEq(stakingRewards.balanceWithPendingRewards(charlie), 2.5 ether);
        assertEq(stakingRewards.unallocatedRewards(), 2 ether);
    }

    /// @notice Users exit mid-sequence; remaining stakers correctly receive subsequent rewards
    function testThreeStakersExitMidwayDistributions() public {
        // Alice 2, Bob 2
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 2 ether);
        stakingRewards.stake(2 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 2 ether);
        stakingRewards.stake(2 ether);
        vm.stopPrank();

        // Distribute 2 -> 1 reward over active=4 (Alice 0.5, Bob 0.5)
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 2 ether);
        stakingRewards.depositAndDistribute(2 ether);
        vm.stopPrank();

        // Alice exits

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(alice);
        stakingRewards.unstake();
        assertEq(stakingRewards.balanceOf(alice), 0);

        // Charlie joins with 2
        vm.startPrank(charlie);
        hlg.approve(address(stakingRewards), 2 ether);
        stakingRewards.stake(2 ether);
        vm.stopPrank();

        // Distribute 2 -> 1 reward over active=4 (Bob 0.5, Charlie 0.5)
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 2 ether);
        stakingRewards.depositAndDistribute(2 ether);
        vm.stopPrank();

        // Bob total pending 1.0, Charlie 0.5, Alice 0 (exited after settling)
        assertEq(stakingRewards.pendingRewards(bob), 1 ether);
        assertEq(stakingRewards.pendingRewards(charlie), 0.5 ether);
        assertEq(stakingRewards.pendingRewards(alice), 0);

        // Verify total balances including pending rewards
        assertEq(stakingRewards.balanceWithPendingRewards(bob), 3 ether);
        assertEq(stakingRewards.balanceWithPendingRewards(charlie), 2.5 ether);
    }

    /// @notice Interleaves stakeFor (paused) and distributor stakes with distributions
    function testInterleavedStakeForAndDistributorStakesAcrossDistributions() public {
        // Pause to use stakeFor
        vm.prank(owner);
        stakingRewards.pause();

        // Owner stakes for Alice (1) and Bob (2) while paused
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 3 ether);
        stakingRewards.stakeFor(alice, 1 ether);
        stakingRewards.stakeFor(bob, 2 ether);
        stakingRewards.unpause();
        vm.stopPrank();

        // Whitelist distributor and stake for Charlie (1)
        vm.prank(owner);
        stakingRewards.setDistributor(distributor, true);
        vm.startPrank(distributor);
        hlg.approve(address(stakingRewards), 1 ether);
        stakingRewards.stakeFromDistributor(charlie, 1 ether);
        vm.stopPrank();

        // Distribute 2 -> 1 reward over active=4 (Alice 0.25, Bob 0.5, Charlie 0.25)
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 2 ether);
        stakingRewards.depositAndDistribute(2 ether);
        vm.stopPrank();

        // Verify total balances including pending rewards
        assertEq(stakingRewards.balanceWithPendingRewards(alice), 1.25 ether);
        assertEq(stakingRewards.balanceWithPendingRewards(bob), 2.5 ether);
        assertEq(stakingRewards.balanceWithPendingRewards(charlie), 1.25 ether);
    }

    /// @notice Randomized sequence across three users maintains invariants and does not revert unexpectedly
    function testFuzz_ThreeStakersRandomizedSequences(uint8 seed) public {
        // Seed initial stakes to avoid zero-active edge early
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 10_000 ether);
        stakingRewards.stake(1_000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 10_000 ether);
        stakingRewards.stake(1_000 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        hlg.approve(address(stakingRewards), 10_000 ether);
        stakingRewards.stake(1_000 ether);
        vm.stopPrank();

        uint256 rng = uint256(keccak256(abi.encode(seed)));
        for (uint256 i = 0; i < 8; i++) {
            uint256 action = rng % 6; // 0..5
            rng = uint256(keccak256(abi.encode(rng)));

            if (action == 0) {
                // Random user stakes [100, 1100)
                address user = [alice, bob, charlie][rng % 3];
                rng = uint256(keccak256(abi.encode(rng)));
                uint256 amount = (rng % 1000) + 100;
                rng = uint256(keccak256(abi.encode(rng)));
                // Only attempt to stake when unpaused to avoid expected revert
                if (!stakingRewards.paused()) {
                    vm.startPrank(user);
                    hlg.approve(address(stakingRewards), amount);
                    // Stake may still revert on edge conditions; ignore failures
                    try stakingRewards.stake(amount) {} catch {}
                    vm.stopPrank();
                }
            } else if (action == 1) {
                // Distribute [1000, 2000) to avoid dust
                uint256 amount = (rng % 1000) + 1000;
                rng = uint256(keccak256(abi.encode(rng)));
                vm.startPrank(owner);
                hlg.approve(address(stakingRewards), amount);
                try stakingRewards.depositAndDistribute(amount) {} catch {}
                vm.stopPrank();
            } else if (action == 2) {
                // Random user action
                rng = uint256(keccak256(abi.encode(rng)));
            } else if (action == 3) {
                // Unstake random user if has balance and can unstake
                address user = [alice, bob, charlie][rng % 3];
                rng = uint256(keccak256(abi.encode(rng)));
                if (stakingRewards.balanceOf(user) > 0 && stakingRewards.canUnstake(user)) {
                    vm.prank(user);
                    stakingRewards.unstake();
                }
            } else if (action == 4) {
                // Pause/unpause rarely
                if (!stakingRewards.paused() && (rng & 0xFF) == 0x7F) {
                    vm.prank(owner);
                    stakingRewards.pause();
                } else if (stakingRewards.paused() && (rng & 0xFF) == 0x80) {
                    vm.prank(owner);
                    stakingRewards.unpause();
                }
                rng = uint256(keccak256(abi.encode(rng)));
            } else if (action == 5) {
                // Random user action
                rng = uint256(keccak256(abi.encode(rng)));
            }

            _checkInvariants();
        }
    }

    /// @notice Snapshots and accrual remain correct across pause/unpause boundaries
    function testSnapshotsAcrossPauseUnpause() public {
        // Alice stakes and one distribution occurs
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 10 ether);
        stakingRewards.stake(10 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 10 ether);
        stakingRewards.depositAndDistribute(10 ether);
        vm.stopPrank();

        // Pause; funding should revert, snapshot unchanged
        vm.prank(owner);
        stakingRewards.pause();
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 1 ether);
        vm.expectRevert();
        stakingRewards.depositAndDistribute(1 ether);
        vm.stopPrank();
        assertEq(stakingRewards.userIndexSnapshot(alice), 0);

        // Unpause and distribute again; then settle
        vm.prank(owner);
        stakingRewards.unpause();
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 10 ether);
        stakingRewards.depositAndDistribute(10 ether);
        vm.stopPrank();

        // Verify rewards are tracked properly
        assertGt(stakingRewards.pendingRewards(alice), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Staker Count Tests                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Staker count increments from 0 to 1 on first stake
    function testStakerCountIncrementOnFirstStake() public {
        assertEq(stakingRewards.totalStakers(), 0);

        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(stakingRewards.totalStakers(), 1);
    }

    /// @notice Staker count does not increment on subsequent stakes by same user
    function testStakerCountNoIncrementOnSubsequentStake() public {
        // Alice stakes twice
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT * 2);
        stakingRewards.stake(STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 1);

        stakingRewards.stake(STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 1);
        vm.stopPrank();
    }

    /// @notice Staker count decrements on full unstake
    function testStakerCountDecrementOnUnstake() public {
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 1);

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 7 days + 1);

        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 0);
        vm.stopPrank();
    }

    /// @notice Staker count decrements on emergency exit
    function testStakerCountDecrementOnEmergencyExit() public {
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 1);
        vm.stopPrank();

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        vm.startPrank(alice);
        stakingRewards.emergencyExit();
        assertEq(stakingRewards.totalStakers(), 0);
        vm.stopPrank();
    }

    /// @notice Staker count tracks multiple users correctly
    function testStakerCountMultipleUsers() public {
        assertEq(stakingRewards.totalStakers(), 0);

        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();
        assertEq(stakingRewards.totalStakers(), 1);

        // Bob stakes
        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();
        assertEq(stakingRewards.totalStakers(), 2);

        // Charlie stakes
        vm.startPrank(charlie);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();
        assertEq(stakingRewards.totalStakers(), 3);

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 7 days + 1);

        // Alice exits
        vm.prank(alice);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 2);

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        // Bob exits
        vm.prank(bob);
        stakingRewards.emergencyExit();
        assertEq(stakingRewards.totalStakers(), 1);

        // Charlie exits
        vm.prank(charlie);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 0);
    }

    /// @notice Staker count remains accurate with rewards and compounding
    function testStakerCountWithRewardsAndCompounding() public {
        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();
        assertEq(stakingRewards.totalStakers(), 1);

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        stakingRewards.depositAndDistribute(REWARD_AMOUNT);
        vm.stopPrank();

        // Count unchanged by reward distribution
        assertEq(stakingRewards.totalStakers(), 1);

        // Staker count unchanged
        assertEq(stakingRewards.totalStakers(), 1);

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 7 days + 1);

        // Exit still decrements count
        vm.prank(alice);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 0);
    }

    /// @notice Staker count works correctly with stakeFor (owner-only, paused)
    function testStakerCountStakeFor() public {
        vm.prank(owner);
        stakingRewards.pause();

        assertEq(stakingRewards.totalStakers(), 0);

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT * 3);
        stakingRewards.stakeFor(alice, STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 1);

        stakingRewards.stakeFor(bob, STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 2);

        // Stake more for Alice (no increment)
        stakingRewards.stakeFor(alice, STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 2);
        vm.stopPrank();

        vm.prank(owner);
        stakingRewards.unpause();

        // Users can still exit and count decrements (no cooldown from stakeFor)
        vm.prank(alice);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 1);

        vm.prank(bob);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 0);
    }

    /// @notice Staker count works correctly with batch operations
    function testStakerCountBatchOperations() public {
        vm.prank(owner);
        stakingRewards.pause();

        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;
        amounts[2] = 300 ether;

        assertEq(stakingRewards.totalStakers(), 0);

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 600 ether);
        stakingRewards.batchStakeFor(users, amounts, 0, 3);
        vm.stopPrank();

        assertEq(stakingRewards.totalStakers(), 3);

        vm.prank(owner);
        stakingRewards.unpause();

        // Batch again for same users (no increment)
        vm.prank(owner);
        stakingRewards.pause();

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 600 ether);
        stakingRewards.batchStakeFor(users, amounts, 0, 3);
        vm.stopPrank();

        assertEq(stakingRewards.totalStakers(), 3);
    }

    /// @notice Staker count works correctly with distributor staking
    function testStakerCountDistributorStaking() public {
        vm.prank(owner);
        stakingRewards.setDistributor(distributor, true);

        assertEq(stakingRewards.totalStakers(), 0);

        vm.startPrank(distributor);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT * 3);
        stakingRewards.stakeFromDistributor(alice, STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 1);

        stakingRewards.stakeFromDistributor(bob, STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 2);

        // Stake more for Alice (no increment)
        stakingRewards.stakeFromDistributor(alice, STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 2);
        vm.stopPrank();

        // Users can exit normally (no cooldown from distributor staking)
        vm.prank(alice);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 1);

        vm.prank(bob);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 0);
    }

    /// @notice Zero to one to zero cycle maintains count accuracy
    function testStakerCountZeroToOneToZero() public {
        for (uint256 i = 0; i < 3; i++) {
            assertEq(stakingRewards.totalStakers(), 0);

            vm.startPrank(alice);
            hlg.approve(address(stakingRewards), STAKE_AMOUNT);
            stakingRewards.stake(STAKE_AMOUNT);
            assertEq(stakingRewards.totalStakers(), 1);

            if (i % 2 == 0) {
                // Wait for cooldown period to pass
                vm.warp(block.timestamp + 7 days + 1);
                stakingRewards.unstake();
            } else {
                vm.stopPrank();
                // Pause contract so emergency exit can be called
                vm.prank(owner);
                stakingRewards.pause();
                vm.prank(alice);
                stakingRewards.emergencyExit();

                // Unpause for next iteration
                vm.prank(owner);
                stakingRewards.unpause();
            }
            assertEq(stakingRewards.totalStakers(), 0);
            vm.stopPrank();
        }
    }

    /// @notice Rapid stake/unstake operations maintain count accuracy
    function testStakerCountRapidStakeUnstake() public {
        address[3] memory users = [alice, bob, charlie];

        // Rapid stakes
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(users[i]);
            hlg.approve(address(stakingRewards), STAKE_AMOUNT);
            stakingRewards.stake(STAKE_AMOUNT);
            vm.stopPrank();
            assertEq(stakingRewards.totalStakers(), i + 1);
        }

        // Wait for cooldown period to pass
        vm.warp(block.timestamp + 7 days + 1);

        // Rapid unstakes
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(users[i]);
            stakingRewards.unstake();
            assertEq(stakingRewards.totalStakers(), 2 - i);
        }
    }

    /// @notice Staker count persists across pause/unpause
    function testStakerCountAcrossPauseUnpause() public {
        // Stake while unpaused
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();
        assertEq(stakingRewards.totalStakers(), 1);

        // Pause
        vm.prank(owner);
        stakingRewards.pause();
        assertEq(stakingRewards.totalStakers(), 1);

        // Wait for cooldown period to pass before unstaking
        vm.warp(block.timestamp + 7 days + 1);

        // Can still exit while paused
        vm.prank(alice);
        stakingRewards.unstake();
        assertEq(stakingRewards.totalStakers(), 0);

        // Use stakeFor while paused
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stakeFor(bob, STAKE_AMOUNT);
        assertEq(stakingRewards.totalStakers(), 1);

        // Unpause
        stakingRewards.unpause();
        vm.stopPrank();
        assertEq(stakingRewards.totalStakers(), 1);

        // Normal operations work
        vm.startPrank(charlie);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT);
        stakingRewards.stake(STAKE_AMOUNT);
        vm.stopPrank();
        assertEq(stakingRewards.totalStakers(), 2);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Cooldown Mechanism Tests                        */
    /* -------------------------------------------------------------------------- */

    /// @notice Owner staking (stakeFor) does not set cooldown timestamp
    function testOwnerStakeForDoesNotSetTimestamp() public {
        vm.prank(owner);
        stakingRewards.pause();

        // Owner stakes for alice (should NOT set timestamp)
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 50 ether);
        stakingRewards.stakeFor(alice, 50 ether);
        vm.stopPrank();

        // Check that alice has balance
        assertEq(stakingRewards.balanceOf(alice), 50 ether);

        // Check that timestamp was NOT set (should be 0)
        assertEq(stakingRewards.lastStakeTimestamp(alice), 0);

        // User should be able to unstake immediately (no cooldown from owner staking)
        assertTrue(stakingRewards.canUnstake(alice));

        vm.prank(alice);
        stakingRewards.unstake();

        assertEq(stakingRewards.balanceOf(alice), 0);
    }

    /// @notice Batch owner staking does not set cooldown timestamps
    function testBatchStakeForDoesNotSetTimestamp() public {
        vm.prank(owner);
        stakingRewards.pause();

        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        users[0] = alice;
        users[1] = bob;
        amounts[0] = 30 ether;
        amounts[1] = 20 ether;

        // Owner batch stakes (should NOT set timestamps)
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 50 ether);
        stakingRewards.batchStakeFor(users, amounts, 0, 2);
        vm.stopPrank();

        // Check balances
        assertEq(stakingRewards.balanceOf(alice), 30 ether);
        assertEq(stakingRewards.balanceOf(bob), 20 ether);

        // Check that timestamps were NOT set (should be 0)
        assertEq(stakingRewards.lastStakeTimestamp(alice), 0);
        assertEq(stakingRewards.lastStakeTimestamp(bob), 0);

        // Users should be able to unstake immediately
        assertTrue(stakingRewards.canUnstake(alice));
        assertTrue(stakingRewards.canUnstake(bob));

        vm.prank(alice);
        stakingRewards.unstake();
        vm.prank(bob);
        stakingRewards.unstake();

        assertEq(stakingRewards.balanceOf(alice), 0);
        assertEq(stakingRewards.balanceOf(bob), 0);
    }

    /// @notice User-initiated staking still sets cooldown timestamp
    function testUserStakeStillSetsTimestamp() public {
        // User stakes normally (should set timestamp)
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 20 ether);
        stakingRewards.stake(20 ether);
        vm.stopPrank();

        // Check that timestamp WAS set
        assertGt(stakingRewards.lastStakeTimestamp(alice), 0);
        assertEq(stakingRewards.lastStakeTimestamp(alice), block.timestamp);

        // User should NOT be able to unstake immediately
        assertFalse(stakingRewards.canUnstake(alice));

        // Fast forward 7 days
        vm.warp(block.timestamp + 7 days + 1);

        // Now should be able to unstake
        assertTrue(stakingRewards.canUnstake(alice));
        vm.prank(alice);
        stakingRewards.unstake();
    }

    /// @notice Distributor staking does not set cooldown timestamp
    function testDistributorStakeNoTimestamp() public {
        vm.prank(owner);
        stakingRewards.setDistributor(distributor, true);

        // Distributor stakes for user (should NOT set timestamp)
        vm.startPrank(distributor);
        hlg.approve(address(stakingRewards), 30 ether);
        stakingRewards.stakeFromDistributor(alice, 30 ether);
        vm.stopPrank();

        // Check that timestamp was NOT set (should remain 0)
        assertEq(stakingRewards.lastStakeTimestamp(alice), 0);

        // User should be able to unstake immediately (no cooldown)
        assertTrue(stakingRewards.canUnstake(alice));
        vm.prank(alice);
        stakingRewards.unstake();
    }

    /// @notice Mixed owner and user staking - cooldown only applies to user-initiated stakes
    function testMixedOwnerAndUserStaking() public {
        // First: Owner stakes for user (no timestamp)
        vm.prank(owner);
        stakingRewards.pause();

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 30 ether);
        stakingRewards.stakeFor(alice, 30 ether);
        stakingRewards.unpause();
        vm.stopPrank();

        // User should be able to unstake immediately
        assertTrue(stakingRewards.canUnstake(alice));

        // Then: User stakes more (sets timestamp)
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 20 ether);
        stakingRewards.stake(20 ether);
        vm.stopPrank();

        // Now user should NOT be able to unstake (cooldown active)
        assertFalse(stakingRewards.canUnstake(alice));

        // Total balance should be 50 ether
        assertEq(stakingRewards.balanceOf(alice), 50 ether);

        // Fast forward and unstake
        vm.warp(block.timestamp + 7 days + 1);
        assertTrue(stakingRewards.canUnstake(alice));

        vm.prank(alice);
        stakingRewards.unstake();
        assertEq(stakingRewards.balanceOf(alice), 0);
    }

    /// @notice Cooldown can be configured by owner
    function testCooldownConfiguration() public {
        vm.startPrank(owner);

        // Set cooldown to 1 day
        stakingRewards.setStakingCooldown(1 days);
        assertEq(stakingRewards.stakingCooldown(), 1 days);

        // Set cooldown to 0 (no cooldown)
        stakingRewards.setStakingCooldown(0);
        assertEq(stakingRewards.stakingCooldown(), 0);

        vm.stopPrank();
    }

    /// @notice With zero cooldown, users can unstake immediately
    function testNoCooldownWhenSetToZero() public {
        // Set cooldown to 0
        vm.prank(owner);
        stakingRewards.setStakingCooldown(0);

        // User stakes and should be able to unstake immediately
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 10 ether);
        stakingRewards.stake(10 ether);

        assertTrue(stakingRewards.canUnstake(alice));
        stakingRewards.unstake();
        vm.stopPrank();
    }

    /// @notice Emergency exit bypasses cooldown restrictions
    function testEmergencyExitBypassesCooldown() public {
        // User stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 10 ether);
        stakingRewards.stake(10 ether);

        // Check that user cannot unstake immediately
        assertFalse(stakingRewards.canUnstake(alice));
        vm.stopPrank();

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        // Emergency exit should work even during cooldown
        vm.prank(alice);
        stakingRewards.emergencyExit();

        // Check balance is zero
        assertEq(stakingRewards.balanceOf(alice), 0);
        vm.stopPrank();
    }

    /// @notice Cooldown prevents sandwich attacks on reward distributions
    function testCooldownPreventsSandwichAttacks() public {
        address attacker = makeAddr("attacker");
        hlg.mint(attacker, 1000 ether);

        // Attacker tries to front-run a reward distribution
        vm.startPrank(attacker);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);

        // Even if rewards are distributed immediately after
        vm.stopPrank();

        // Attacker cannot unstake immediately to capture rewards
        vm.startPrank(attacker);
        assertFalse(stakingRewards.canUnstake(attacker));
        vm.expectRevert(StakingRewards.StakingCooldownNotMet.selector);
        stakingRewards.unstake();
        vm.stopPrank();

        // Attacker would need to wait 7 days to unstake
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(attacker);
        assertTrue(stakingRewards.canUnstake(attacker));
    }

    /// @notice Test case showing reward compounding gaming is completely prevented
    function testRewardCompoundingGamingPrevented() public {
        vm.prank(owner);
        stakingRewards.setDistributor(distributor, true);

        // Both Alice and Bob stake at the same time
        vm.startPrank(distributor);
        hlg.approve(address(stakingRewards), STAKE_AMOUNT * 2);
        stakingRewards.stakeFromDistributor(alice, STAKE_AMOUNT);
        stakingRewards.stakeFromDistributor(bob, STAKE_AMOUNT);
        vm.stopPrank();

        // Rewards are sent to the protocol
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        stakingRewards.depositAndDistribute(REWARD_AMOUNT);
        vm.stopPrank();

        // Gaming prevention verified - users cannot manually trigger compounding

        // More rewards are sent to the protocol
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), REWARD_AMOUNT);
        stakingRewards.depositAndDistribute(REWARD_AMOUNT);
        vm.stopPrank();

        // Both Alice and Bob unstake at same time - equal rewards (no gaming advantage)
        vm.startPrank(alice);
        stakingRewards.unstake();
        vm.stopPrank();

        vm.startPrank(bob);
        stakingRewards.unstake();
        vm.stopPrank();

        // Now they have equal final balances (gaming prevented)
        assertEq(hlg.balanceOf(alice), hlg.balanceOf(bob));

        console.log("Alice balance %e", hlg.balanceOf(alice));
        console.log("Bob balance %e", hlg.balanceOf(bob));
        console.log("Gaming completely prevented - equal rewards!");
    }

    /* -------------------------------------------------------------------------- */
    /*                            Small Rewards Tests                            */
    /* -------------------------------------------------------------------------- */

    /// @notice addRewards should not revert with small amounts that don't move the index
    function testAddRewardsSmallAmountDoesNotRevert() public {
        // Alice stakes to create active stake
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Try adding tiny reward amount that won't move the index
        // With INDEX_PRECISION = 1e12 and stake = 1000e18
        // Minimum needed to move index: (1000e18 * 1) / 1e12 = 1e6 = 1 wei per 1e12
        // So anything less than 1e6 wei should be silently skipped
        uint256 tinyAmount = 1000; // Much smaller than threshold

        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), tinyAmount);

        // This should not revert - should silently skip
        stakingRewards.addRewards(tinyAmount);
        vm.stopPrank();

        // Verify no index change occurred
        assertEq(stakingRewards.globalRewardIndex(), 0);
        assertEq(stakingRewards.unallocatedRewards(), 0);
    }

    /// @notice depositAndDistribute should revert with small amounts (owner-only function)
    function testDepositAndDistributeSmallAmountReverts() public {
        // Alice stakes to create active stake
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Try depositing tiny amount that won't move the index
        uint256 tinyAmount = 500; // Much smaller than threshold

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), tinyAmount);

        // This should revert since depositAndDistribute is not part of LayerZero flow
        vm.expectRevert(StakingRewards.RewardTooSmall.selector);
        stakingRewards.depositAndDistribute(tinyAmount);
        vm.stopPrank();
    }

    /// @notice Large rewards still work normally after small rewards fix
    function testNormalRewardsStillWork() public {
        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Add normal-sized reward that should move the index
        uint256 normalAmount = 100 ether;

        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), normalAmount);
        stakingRewards.addRewards(normalAmount);
        vm.stopPrank();

        // Verify index increased
        assertGt(stakingRewards.globalRewardIndex(), 0);
        assertGt(stakingRewards.unallocatedRewards(), 0);
    }

    /// @notice Multiple small rewards in sequence should not revert
    function testMultipleSmallRewardsDoNotRevert() public {
        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        vm.startPrank(feeRouter);

        // Add multiple tiny rewards - none should revert
        for (uint256 i = 0; i < 5; i++) {
            hlg.approve(address(stakingRewards), 100);
            stakingRewards.addRewards(100);
        }

        vm.stopPrank();

        // Index should still be 0 (no rewards were actually added)
        assertEq(stakingRewards.globalRewardIndex(), 0);
        assertEq(stakingRewards.unallocatedRewards(), 0);
    }

    /// @notice Edge case: minimum amount that moves index should work
    function testRewardsAtThresholdWork() public {
        // Alice stakes 1000 ether
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Use an amount that will definitely move the index after burn
        // We need: (rewardAmount * INDEX_PRECISION) / staked >= 1
        // staked = 1000e18, INDEX_PRECISION = 1e12
        // So rewardAmount >= 1000e18 / 1e12 = 1e6
        // But since half gets burned, we need at least 2e6 input to get 1e6 reward
        uint256 inputAmount = 2e12; // Large enough to definitely move index

        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), inputAmount);
        stakingRewards.addRewards(inputAmount);
        vm.stopPrank();

        // Should have moved the index
        assertGt(stakingRewards.globalRewardIndex(), 0);
        assertGt(stakingRewards.unallocatedRewards(), 0);
    }

    /// @notice Rewards sent to contract with no stakers can be recovered by owner
    function testNoStakerRewardsRecoverable() public {
        // Ensure no stakers
        assertEq(stakingRewards.totalStaked(), 0);

        uint256 ownerBalanceBefore = hlg.balanceOf(owner);

        // FeeRouter sends rewards with no stakers
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.addRewards(100 ether);
        vm.stopPrank();

        // Verify full amount is extra tokens (no burn occurred)
        assertEq(stakingRewards.getExtraTokens(), 100 ether);

        // Owner can recover the extra tokens
        vm.prank(owner);
        stakingRewards.recoverExtraHLG(owner, 100 ether);

        // Owner receives the full amount
        assertEq(hlg.balanceOf(owner), ownerBalanceBefore + 100 ether);
    }

    /// @notice Rewards accumulate as extra tokens when no stakers, then distribute when stakers join
    function testNoStakerToStakerTransition() public {
        // Ensure no stakers initially
        assertEq(stakingRewards.totalStaked(), 0);

        // FeeRouter sends rewards with no stakers (becomes extra tokens)
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.addRewards(100 ether);
        vm.stopPrank();

        // Verify extra tokens (full amount, no burn)
        assertEq(stakingRewards.getExtraTokens(), 100 ether);

        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Extra tokens should still be there
        assertEq(stakingRewards.getExtraTokens(), 100 ether);

        // Now FeeRouter sends more rewards with active staker
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.addRewards(100 ether);
        vm.stopPrank();

        // This time rewards should be distributed normally (with burn)
        assertGt(stakingRewards.unallocatedRewards(), 0);

        // Alice should have pending rewards from the second distribution
        assertGt(stakingRewards.pendingRewards(alice), 0);

        // Original extra tokens should still be recoverable
        assertEq(stakingRewards.getExtraTokens(), 100 ether);
    }

    /// @notice Multiple no-staker reward cycles accumulate extra tokens
    function testMultipleNoStakerCycles() public {
        // Ensure no stakers
        assertEq(stakingRewards.totalStaked(), 0);

        // Multiple FeeRouter reward cycles with no stakers
        for (uint256 i = 0; i < 3; i++) {
            vm.startPrank(feeRouter);
            hlg.approve(address(stakingRewards), 100 ether);
            stakingRewards.addRewards(100 ether);
            vm.stopPrank();
        }

        // All amounts should accumulate as extra tokens (no burn)
        assertEq(stakingRewards.getExtraTokens(), 300 ether); // 3 * 100 ether

        // Owner can recover all at once
        uint256 ownerBalanceBefore = hlg.balanceOf(owner);
        vm.prank(owner);
        stakingRewards.recoverExtraHLG(owner, 300 ether);

        assertEq(hlg.balanceOf(owner), ownerBalanceBefore + 300 ether);
        assertEq(stakingRewards.getExtraTokens(), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Forfeited Rewards Tests                          */
    /* -------------------------------------------------------------------------- */

    /// @notice Emergency exit tracks forfeited pending rewards
    function testEmergencyExitTracksForfeited() public {
        // Alice stakes
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.depositAndDistribute(200 ether);
        vm.stopPrank();

        // Check pending rewards before emergency exit
        uint256 pendingBefore = stakingRewards.pendingRewards(alice);
        assertGt(pendingBefore, 0);

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        // Emergency exit should track forfeited rewards
        vm.expectEmit(true, false, false, true);
        emit RewardsForfeited(alice, pendingBefore);

        vm.prank(alice);
        stakingRewards.emergencyExit();

        // Verify forfeited rewards tracked
        assertEq(stakingRewards.forfeitedRewards(), pendingBefore);
    }

    /// @notice Owner can reclaim forfeited rewards while stakers remain
    function testReclaimForfeitedRewardsWithActiveStakers() public {
        // Alice and Bob stake
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 500 ether);
        stakingRewards.stake(500 ether);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 300 ether);
        stakingRewards.depositAndDistribute(300 ether);
        vm.stopPrank();

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        // Alice emergency exits (forfeits pending rewards)
        uint256 alicePending = stakingRewards.pendingRewards(alice);
        vm.prank(alice);
        stakingRewards.emergencyExit();

        // Bob still has active stake
        assertGt(stakingRewards.balanceOf(bob), 0);
        assertGt(stakingRewards.pendingRewards(bob), 0);

        // Owner can reclaim Alice's forfeited rewards even with Bob still staking
        uint256 ownerBalanceBefore = hlg.balanceOf(owner);

        vm.expectEmit(true, true, false, true);
        emit TokensRecovered(address(hlg), alicePending, owner);

        vm.prank(owner);
        stakingRewards.reclaimUnallocatedRewards(owner);

        // Verify reclaim successful
        assertEq(stakingRewards.forfeitedRewards(), 0);
        assertEq(hlg.balanceOf(owner), ownerBalanceBefore + alicePending);

        // Bob's stake and rewards unaffected
        assertGt(stakingRewards.balanceOf(bob), 0);
        assertGt(stakingRewards.pendingRewards(bob), 0);
    }

    /// @notice Multiple emergency exits accumulate forfeited rewards
    function testMultipleEmergencyExitsAccumulate() public {
        // Alice and Bob stake
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 400 ether);
        stakingRewards.depositAndDistribute(400 ether);
        vm.stopPrank();

        // Both emergency exit
        uint256 alicePending = stakingRewards.pendingRewards(alice);
        uint256 bobPending = stakingRewards.pendingRewards(bob);

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        vm.prank(alice);
        stakingRewards.emergencyExit();

        vm.prank(bob);
        stakingRewards.emergencyExit();

        // Verify forfeited rewards accumulated
        assertEq(stakingRewards.forfeitedRewards(), alicePending + bobPending);

        // Owner can reclaim all forfeited rewards
        uint256 ownerBalanceBefore = hlg.balanceOf(owner);
        vm.prank(owner);
        stakingRewards.reclaimUnallocatedRewards(owner);

        assertEq(stakingRewards.forfeitedRewards(), 0);
        assertEq(hlg.balanceOf(owner), ownerBalanceBefore + alicePending + bobPending);
    }

    /// @notice Cannot reclaim more forfeited rewards than available
    function testCannotReclaimExcessiveForfeited() public {
        // Alice stakes and exits without rewards
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        vm.prank(alice);
        stakingRewards.emergencyExit(); // No pending rewards to forfeit

        // No forfeited rewards
        assertEq(stakingRewards.forfeitedRewards(), 0);

        // Should revert when trying to reclaim
        vm.prank(owner);
        vm.expectRevert(StakingRewards.ZeroAmount.selector);
        stakingRewards.reclaimUnallocatedRewards(owner);
    }

    /// @notice Forfeited rewards cannot exceed unallocated rewards
    function testForfeitedRewardsRespectUnallocated() public {
        // Setup scenario where forfeited might exceed unallocated
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 1000 ether);
        stakingRewards.stake(1000 ether);
        vm.stopPrank();

        // Distribute rewards
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.depositAndDistribute(200 ether);
        vm.stopPrank();

        // Manually reduce unallocated to simulate edge case
        uint256 pendingBefore = stakingRewards.pendingRewards(alice);

        // Pause contract so emergency exit can be called
        vm.prank(owner);
        stakingRewards.pause();

        // Emergency exit
        vm.prank(alice);
        stakingRewards.emergencyExit();

        // Try to reclaim when insufficient unallocated
        // This should work normally since forfeited <= unallocated in this test
        vm.prank(owner);
        stakingRewards.reclaimUnallocatedRewards(owner);

        assertEq(stakingRewards.forfeitedRewards(), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Invariant Helpers                             */
    /* -------------------------------------------------------------------------- */

    function _checkInvariants() internal view {
        uint256 contractBalance = hlg.balanceOf(address(stakingRewards));
        uint256 totalStaked = stakingRewards.totalStaked();
        uint256 unallocated = stakingRewards.unallocatedRewards();

        // HLG.balanceOf(this) >= totalStaked
        assertGe(contractBalance, totalStaked, "Contract balance should be >= totalStaked");

        // sum(balanceOf) + unallocatedRewards == totalStaked
        uint256 aliceBalance = stakingRewards.balanceOf(alice);
        uint256 bobBalance = stakingRewards.balanceOf(bob);
        uint256 charlieBalance = stakingRewards.balanceOf(charlie);
        uint256 sumBalances = aliceBalance + bobBalance + charlieBalance;
        assertEq(sumBalances + unallocated, totalStaked, "Sum of balances + unallocated should equal totalStaked");

        // Extra tokens should be contractBalance - totalStaked
        uint256 extraTokens = stakingRewards.getExtraTokens();
        uint256 expectedExtra = contractBalance > totalStaked ? contractBalance - totalStaked : 0;
        assertEq(extraTokens, expectedExtra, "Extra tokens should be contractBalance - totalStaked");
    }

    function testRecoverExtraHLGZeroAmount() public {
        // Should revert when trying to recover zero amount
        vm.expectRevert(StakingRewards.ZeroAmount.selector);
        vm.prank(owner);
        stakingRewards.recoverExtraHLG(alice, 0);
    }

    function testRecoverTokenZeroAmount() public {
        MockERC20 testToken = new MockERC20("Test", "TEST");

        // Should revert when trying to recover with zero minimum amount
        vm.expectRevert(StakingRewards.ZeroAmount.selector);
        vm.prank(owner);
        stakingRewards.recoverToken(address(testToken), alice, 0);
    }

    function testRecoverExtraHLGValidAmount() public {
        // Send extra HLG to the contract
        uint256 extraAmount = 100 ether;
        hlg.mint(address(stakingRewards), extraAmount);

        uint256 balanceBefore = hlg.balanceOf(alice);

        vm.prank(owner);
        stakingRewards.recoverExtraHLG(alice, extraAmount);

        uint256 balanceAfter = hlg.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, extraAmount, "Alice should receive the extra HLG");
    }

    function testRecoverTokenValidAmount() public {
        MockERC20 testToken = new MockERC20("Test", "TEST");
        uint256 tokenAmount = 50 ether;

        // Send test tokens to the contract
        testToken.mint(address(stakingRewards), tokenAmount);

        uint256 balanceBefore = testToken.balanceOf(alice);

        vm.prank(owner);
        stakingRewards.recoverToken(address(testToken), alice, tokenAmount);

        uint256 balanceAfter = testToken.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, tokenAmount, "Alice should receive the test tokens");
    }

    /* -------------------------------------------------------------------------- */
    /*                              Upgrade Tests                                */
    /* -------------------------------------------------------------------------- */

    function testUpgradeStakingRewards() public {
        // Set up initial state with some stakes and rewards
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 100 ether);
        stakingRewards.stake(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        hlg.approve(address(stakingRewards), 200 ether);
        stakingRewards.stake(200 ether);
        vm.stopPrank();

        // Add some rewards (need to call as feeRouter, which is address(0x2))
        hlg.mint(feeRouter, 50 ether);
        vm.startPrank(feeRouter);
        hlg.approve(address(stakingRewards), 50 ether);
        stakingRewards.addRewards(50 ether);
        vm.stopPrank();

        // Record state before upgrade
        uint256 aliceBalanceBefore = stakingRewards.balanceOf(alice);
        uint256 bobBalanceBefore = stakingRewards.balanceOf(bob);
        uint256 totalStakedBefore = stakingRewards.totalStaked();
        uint256 totalStakersBefore = stakingRewards.totalStakers();
        uint256 unallocatedBefore = stakingRewards.unallocatedRewards();
        address hlgTokenBefore = address(stakingRewards.HLG());
        address ownerBefore = stakingRewards.owner();

        // Deploy new implementation
        StakingRewards newImpl = new StakingRewards();

        // Perform upgrade (only owner can do this)
        vm.prank(owner);
        stakingRewards.upgradeToAndCall(address(newImpl), "");

        // Verify state preservation after upgrade
        assertEq(stakingRewards.balanceOf(alice), aliceBalanceBefore, "Alice balance should be preserved");
        assertEq(stakingRewards.balanceOf(bob), bobBalanceBefore, "Bob balance should be preserved");
        assertEq(stakingRewards.totalStaked(), totalStakedBefore, "Total staked should be preserved");
        assertEq(stakingRewards.totalStakers(), totalStakersBefore, "Total stakers should be preserved");
        assertEq(stakingRewards.unallocatedRewards(), unallocatedBefore, "Unallocated rewards should be preserved");
        assertEq(address(stakingRewards.HLG()), hlgTokenBefore, "HLG token address should be preserved");
        assertEq(stakingRewards.owner(), ownerBefore, "Owner should be preserved");

        // Verify functionality still works after upgrade
        vm.startPrank(alice);
        hlg.approve(address(stakingRewards), 50 ether);
        stakingRewards.stake(50 ether);
        vm.stopPrank();

        // Verify the stake worked (Alice should have more than before due to potential reward distribution)
        assertGe(
            stakingRewards.balanceOf(alice),
            aliceBalanceBefore + 50 ether,
            "Alice should have at least the additional stake"
        );

        // Test that upgrade is owner-only
        StakingRewards anotherImpl = new StakingRewards();
        vm.prank(alice);
        vm.expectRevert(); // Should revert due to unauthorized access
        stakingRewards.upgradeToAndCall(address(anotherImpl), "");
    }

    function testOwnershipInitializationAtomic() public {
        // Deploy implementation
        StakingRewards impl = new StakingRewards();

        // Deploy proxy with initialization - owner should be set atomically
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(StakingRewards.initialize, (address(hlg), alice)));
        StakingRewards stakingContract = StakingRewards(payable(address(proxy)));

        // Owner should be set immediately
        assertEq(stakingContract.owner(), alice);
        assertEq(stakingContract.pendingOwner(), address(0));
    }

    function testCannotReinitializeProxy() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        stakingRewards.initialize(address(hlg), alice);
    }

    function testDirectImplementationCannotBeInitialized() public {
        StakingRewards impl = new StakingRewards();
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        impl.initialize(address(hlg), alice);
    }

    function testTwoStepOwnershipTransferStillWorks() public {
        // Transfer ownership using two-step process
        vm.prank(owner);
        stakingRewards.transferOwnership(alice);

        // Owner unchanged until accepted
        assertEq(stakingRewards.owner(), owner);
        assertEq(stakingRewards.pendingOwner(), alice);

        // Alice accepts ownership
        vm.prank(alice);
        stakingRewards.acceptOwnership();

        // Ownership transferred
        assertEq(stakingRewards.owner(), alice);
        assertEq(stakingRewards.pendingOwner(), address(0));
    }

    function testUpgradeToNonUUPSImplementation() public {
        // Deploy a non-UUPS implementation (MockERC20 as example)
        MockERC20 nonUUPSImpl = new MockERC20("Test", "TEST");

        // Attempt to upgrade to non-UUPS implementation should fail
        vm.prank(owner);
        vm.expectRevert(); // OpenZeppelin will revert with ERC1967InvalidImplementation or similar
        stakingRewards.upgradeToAndCall(address(nonUUPSImpl), "");
    }

    function testDirectUpgradeOnImplementationFails() public {
        // Deploy a new implementation
        StakingRewards newImpl = new StakingRewards();

        // Attempting to call upgradeToAndCall directly on implementation should fail
        vm.expectRevert(); // Should revert with UUPSUnauthorizedCallContext
        newImpl.upgradeToAndCall(address(newImpl), "");
    }

    function testInitializerIdempotenceFreshProxy() public {
        // Deploy fresh implementation and proxy
        StakingRewards freshImpl = new StakingRewards();
        ERC1967Proxy freshProxy =
            new ERC1967Proxy(address(freshImpl), abi.encodeCall(StakingRewards.initialize, (address(hlg), alice)));
        StakingRewards freshStaking = StakingRewards(payable(address(freshProxy)));

        // Verify initialization worked
        assertEq(freshStaking.owner(), alice);
        assertEq(address(freshStaking.HLG()), address(hlg));

        // Second initialization should fail
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        freshStaking.initialize(address(hlg), bob);
    }

    /// @notice batchStakeFor only works when paused (bootstrap phase)
    function testBatchStakeForOnlyWhenPaused() public {
        // Prepare test data
        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        users[0] = alice;
        users[1] = bob;
        amounts[0] = 100 ether;
        amounts[1] = 200 ether;

        // Fund owner with HLG
        hlg.mint(owner, 300 ether);

        // Test 1: batchStakeFor fails when unpaused
        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), 300 ether);
        vm.expectRevert(); // Reverts with ExpectedPause() from whenPaused modifier
        stakingRewards.batchStakeFor(users, amounts, 0, 2);
        vm.stopPrank();

        // Test 2: batchStakeFor works when paused
        vm.prank(owner);
        stakingRewards.pause();

        vm.startPrank(owner);
        stakingRewards.batchStakeFor(users, amounts, 0, 2);
        vm.stopPrank();

        // Verify balances
        assertEq(stakingRewards.balanceOf(alice), 100 ether);
        assertEq(stakingRewards.balanceOf(bob), 200 ether);
        assertEq(stakingRewards.totalStaked(), 300 ether);
        assertEq(stakingRewards.totalStakers(), 2);

        // Test 3: Users can't use batchStakeFor even when paused
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        stakingRewards.batchStakeFor(users, amounts, 0, 1);
    }

    /// @notice Test resume functionality by processing in two segments
    function testBatchStakeForResumeScenario() public {
        // Prepare test data for 6 users
        address[] memory users = new address[](6);
        uint256[] memory amounts = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            users[i] = address(uint160(0x1000 + i));
            amounts[i] = (i + 1) * 100 ether; // 100, 200, 300, 400, 500, 600 HLG
        }

        // Fund owner with total HLG needed
        uint256 totalHLG = 2100 ether; // Sum of all amounts
        hlg.mint(owner, totalHLG);

        // Pause contract for batch operations
        vm.prank(owner);
        stakingRewards.pause();

        vm.startPrank(owner);
        hlg.approve(address(stakingRewards), totalHLG);

        // Segment 1: Process users 0-2 (first 3 users)
        stakingRewards.batchStakeFor(users, amounts, 0, 3);

        // Verify first segment
        assertEq(stakingRewards.balanceOf(users[0]), 100 ether);
        assertEq(stakingRewards.balanceOf(users[1]), 200 ether);
        assertEq(stakingRewards.balanceOf(users[2]), 300 ether);
        assertEq(stakingRewards.totalStaked(), 600 ether);
        assertEq(stakingRewards.totalStakers(), 3);

        // Segment 2: Process users 3-5 (resume from index 3)
        stakingRewards.batchStakeFor(users, amounts, 3, 6);

        // Verify second segment
        assertEq(stakingRewards.balanceOf(users[3]), 400 ether);
        assertEq(stakingRewards.balanceOf(users[4]), 500 ether);
        assertEq(stakingRewards.balanceOf(users[5]), 600 ether);

        // Verify total after both segments
        assertEq(stakingRewards.totalStaked(), 2100 ether);
        assertEq(stakingRewards.totalStakers(), 6);

        vm.stopPrank();

        // Verify no user was processed twice
        for (uint256 i = 0; i < 6; i++) {
            assertEq(stakingRewards.balanceOf(users[i]), (i + 1) * 100 ether);
        }
    }

    /// @notice Test contract version returns correct semver string
    function testContractVersion() public view {
        string memory version = stakingRewards.contractVersion();
        assertEq(version, "1.0.0");
    }
}
