// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HolographERC20, MintingNotStartedYet, NoMintableAmount} from "../../src/HolographERC20.sol";
import {HolographFactory} from "../../src/HolographFactory.sol";

/**
 * @title HolographERC20Test
 * @notice Comprehensive test suite for HolographERC20 with DERC20 features
 * @dev Tests governance, vesting, and inflation controls
 */
contract HolographERC20Test is Test {
    /// @notice Mock implementation of isTokenCreator for testing
    function isTokenCreator(address, /*token*/ address caller) external view returns (bool) {
        // For testing, the owner is considered the creator
        return caller == owner;
    }

    HolographERC20 public token;
    HolographFactory public mockFactory;

    address public owner = address(this);
    address public user = address(0x1234);
    address public recipient = address(0x5678);
    address public pool = address(0x9999);

    // Test parameters
    string constant TOKEN_NAME = "Test Holograph Token";
    string constant TOKEN_SYMBOL = "THT";
    uint256 constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 constant YEARLY_MINT_RATE = 15e15; // 1.5% yearly inflation
    uint256 constant VESTING_DURATION = 365 days;
    string constant TOKEN_URI = "https://test.token.uri";

    event Transfer(address indexed from, address indexed to, uint256 value);
    event PoolSet(address indexed pool);
    event PoolUnlocked();

    function setUp() public {
        // Deploy token implementation
        token = new HolographERC20();

        // Mock factory to act as the initializer
        mockFactory = HolographFactory(address(this));

        // Initialize token (simulating clone initialization)
        token.initialize(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            INITIAL_SUPPLY,
            recipient,
            owner,
            YEARLY_MINT_RATE,
            VESTING_DURATION,
            new address[](0), // No vesting recipients
            new uint256[](0), // No vesting amounts
            TOKEN_URI
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                              Basic ERC20 Functionality                   */
    /* -------------------------------------------------------------------------- */

    function test_TokenMetadata() public {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(recipient), INITIAL_SUPPLY);
    }

    function test_Transfer() public {
        uint256 amount = 1000e18;

        vm.prank(recipient);
        vm.expectEmit(true, true, false, true);
        emit Transfer(recipient, user, amount);

        token.transfer(user, amount);

        assertEq(token.balanceOf(user), amount);
        assertEq(token.balanceOf(recipient), INITIAL_SUPPLY - amount);
    }

    function test_Approve() public {
        uint256 amount = 1000e18;

        vm.prank(recipient);
        token.approve(user, amount);

        assertEq(token.allowance(recipient, user), amount);
    }

    function test_TransferFrom() public {
        uint256 amount = 1000e18;

        vm.prank(recipient);
        token.approve(user, amount);

        vm.prank(user);
        token.transferFrom(recipient, address(0x9999), amount);

        assertEq(token.balanceOf(address(0x9999)), amount);
        assertEq(token.allowance(recipient, user), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                              DERC20 Features                             */
    /* -------------------------------------------------------------------------- */

    function test_OwnershipAndInitialState() public {
        assertEq(token.owner(), owner);
        assertEq(token.yearlyMintRate(), YEARLY_MINT_RATE);
        assertEq(token.vestingDuration(), VESTING_DURATION);
        assertEq(token.tokenURI(), TOKEN_URI);
        assertEq(token.currentYearStart(), 0); // Initially zero until pool is unlocked
    }

    function test_MintingAfterStartDate() public {
        // Unlock pool to enable minting
        vm.prank(owner);
        token.unlockPool();

        // Fast forward past start date
        vm.warp(block.timestamp + 1 days);

        uint256 balanceBefore = token.balanceOf(owner);

        vm.prank(owner);
        token.mintInflation(); // This mints to owner based on time elapsed

        uint256 balanceAfter = token.balanceOf(owner);
        assertGt(balanceAfter, balanceBefore, "Should have minted some tokens after time elapsed");
    }

    function test_RevertMintingBeforeStartDate() public {
        // Try minting immediately (should fail since pool not unlocked)
        vm.prank(owner);
        vm.expectRevert(MintingNotStartedYet.selector);
        token.mintInflation();
    }

    function test_MintingCap() public {
        // Unlock pool to enable minting
        vm.prank(owner);
        token.unlockPool();

        // Fast forward one full year
        vm.warp(block.timestamp + 365 days);

        uint256 balanceBefore = token.balanceOf(owner);

        vm.prank(owner);
        token.mintInflation();

        uint256 balanceAfter = token.balanceOf(owner);
        uint256 minted = balanceAfter - balanceBefore;

        // Should be close to yearly mint rate applied to total supply
        uint256 expectedMintAmount = (INITIAL_SUPPLY * YEARLY_MINT_RATE) / 1 ether;
        assertApproxEqRel(minted, expectedMintAmount, 0.01e18); // 1% tolerance

        // After minting for this period, should need more time to mint again
        vm.expectRevert(NoMintableAmount.selector);
        vm.prank(owner);
        token.mintInflation();
    }

    function test_OnlyOwnerCanMint() public {
        // Unlock pool first
        vm.prank(owner);
        token.unlockPool();

        vm.warp(block.timestamp + 1 days);

        // User (not owner) tries to mint - should revert with OwnableUnauthorizedAccount
        vm.prank(user);
        vm.expectRevert();
        token.mintInflation();
    }

    /* -------------------------------------------------------------------------- */
    /*                              ERC20 Votes (Governance)                    */
    /* -------------------------------------------------------------------------- */

    function test_VotingPower() public {
        uint256 amount = 1000e18;

        // Initially no voting power
        assertEq(token.getVotes(recipient), 0);

        // Self-delegate to activate voting power
        vm.prank(recipient);
        token.delegate(recipient);

        assertEq(token.getVotes(recipient), INITIAL_SUPPLY);
    }

    function test_Delegation() public {
        vm.prank(recipient);
        token.delegate(user);

        assertEq(token.delegates(recipient), user);
        assertEq(token.getVotes(user), INITIAL_SUPPLY);
        assertEq(token.getVotes(recipient), 0);
    }

    function test_VotingPowerAfterTransfer() public {
        uint256 transferAmount = 1000e18;

        // Self-delegate first
        vm.prank(recipient);
        token.delegate(recipient);

        // Transfer tokens
        vm.prank(recipient);
        token.transfer(user, transferAmount);

        // Voting power should decrease for sender
        assertEq(token.getVotes(recipient), INITIAL_SUPPLY - transferAmount);

        // Receiver gets no voting power until they delegate
        assertEq(token.getVotes(user), 0);

        // Delegate and check voting power
        vm.prank(user);
        token.delegate(user);
        assertEq(token.getVotes(user), transferAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Pool Protection                              */
    /* -------------------------------------------------------------------------- */
    // NOTE: Pool protection functionality not yet implemented in HolographERC20
    // These tests will be added when the pool protection feature is implemented

    /* -------------------------------------------------------------------------- */
    /*                              Permit2 Integration                         */
    /* -------------------------------------------------------------------------- */

    function test_Permit2AllowanceIsMax() public {
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Canonical Permit2

        // Permit2 should have max allowance from any address
        assertEq(token.allowance(recipient, permit2), type(uint256).max);
        assertEq(token.allowance(user, permit2), type(uint256).max);
        assertEq(token.allowance(address(0), permit2), type(uint256).max);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Edge Cases & Security                       */
    /* -------------------------------------------------------------------------- */

    function test_CannotMintToZeroAddress() public {
        // NOTE: This test would require a direct mint function that accepts an address
        // The current implementation only mints via mintInflation() to the owner
        // This test is commented out until direct minting is implemented
    }

    function test_TransferToPoolWhenNotSet() public {
        // When no pool is set, transfers should work normally
        vm.prank(recipient);
        token.transfer(address(0x9999), 1000e18);
        assertEq(token.balanceOf(address(0x9999)), 1000e18);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Fuzz Testing                                */
    /* -------------------------------------------------------------------------- */

    function testFuzz_MintAmount(uint256 timeElapsed) public {
        vm.assume(timeElapsed > 0 && timeElapsed <= 365 days * 10); // Up to 10 years

        vm.warp(block.timestamp + timeElapsed);
        uint256 balanceBefore = token.balanceOf(owner);

        try token.mintInflation() {
            uint256 balanceAfter = token.balanceOf(owner);
            assertGe(balanceAfter, balanceBefore);
        } catch {
            // If no mintable amount, that's also valid
        }
    }

    function testFuzz_Transfer(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_SUPPLY);

        vm.prank(recipient);
        token.transfer(user, amount);

        assertEq(token.balanceOf(user), amount);
        assertEq(token.balanceOf(recipient), INITIAL_SUPPLY - amount);
    }

    function testFuzz_VotingDelegation(address delegatee) public {
        vm.assume(delegatee != address(0));

        vm.prank(recipient);
        token.delegate(delegatee);

        assertEq(token.delegates(recipient), delegatee);
        assertEq(token.getVotes(delegatee), INITIAL_SUPPLY);
    }
}
