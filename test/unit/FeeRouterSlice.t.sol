// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/FeeRouter.sol";
import "../../src/interfaces/IStakingRewards.sol";
import "../mock/MockLZEndpoint.sol";
import "../mock/MockWETH.sol";
import "../mock/MockHLG.sol";
import "../mock/MockSwapRouter.sol";
import "../mock/MockStakingRewards.sol";
import "../mock/MockAirlock.sol";
import "../mock/MockERC20.sol";

/**
 * @title FeeRouterSlice Unit Tests
 * @notice Comprehensive tests for the new single-slice fee processing model
 */
contract FeeRouterSliceTest is Test {
    /* -------------------------------------------------------------------------- */
    /*                                Test Setup                                  */
    /* -------------------------------------------------------------------------- */

    FeeRouter public feeRouter;
    MockLZEndpoint public mockEndpoint;
    MockWETH public mockWETH;
    MockHLG public mockHLG;
    MockSwapRouter public mockSwapRouter;
    MockStakingRewards public mockStaking;
    MockAirlock public mockAirlock;

    address public owner = address(0x1234567890123456789012345678901234567890);
    address public keeper = address(0x0987654321098765432109876543210987654321);
    address public treasury = address(0x1111111111111111111111111111111111111111);
    address public alice = address(0x2222222222222222222222222222222222222222);
    address public bob = address(0x3333333333333333333333333333333333333333);

    uint32 constant ETHEREUM_EID = 30101;
    uint24 constant POOL_FEE = 3000;
    uint16 constant HOLO_FEE_BPS = 150; // 1.5%

    event SlicePulled(address indexed airlock, address indexed token, uint256 holoAmt, uint256 treasuryAmt);
    event TokenReceived(address indexed sender, address indexed token, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);

    function setUp() public {
        // Deploy mocks
        mockEndpoint = new MockLZEndpoint();
        mockWETH = new MockWETH();
        mockHLG = new MockHLG();
        mockSwapRouter = new MockSwapRouter();
        mockStaking = new MockStakingRewards(address(mockHLG));
        mockAirlock = new MockAirlock();

        // Deploy FeeRouter as owner
        vm.startPrank(owner);
        feeRouter = new FeeRouter(
            address(mockEndpoint),
            ETHEREUM_EID,
            address(mockStaking),
            address(mockHLG),
            address(mockWETH),
            address(mockSwapRouter),
            treasury
        );

        // Grant keeper role (owner has DEFAULT_ADMIN_ROLE by default)
        feeRouter.grantRole(feeRouter.KEEPER_ROLE(), keeper);
        vm.stopPrank();

        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(address(feeRouter), 1 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Single-Slice Model Tests                        */
    /* -------------------------------------------------------------------------- */

    function testReceiveFee_SlicesCorrectly() public {
        uint256 amount = 1 ether;
        uint256 expectedHolo = (amount * HOLO_FEE_BPS) / 10_000; // 1.5%
        uint256 expectedTreasury = amount - expectedHolo; // 98.5%

        uint256 treasuryBalanceBefore = treasury.balance;
        uint256 routerBalanceBefore = address(feeRouter).balance;

        vm.expectEmit(true, true, false, true);
        emit SlicePulled(address(0), address(0), expectedHolo, expectedTreasury);

        vm.prank(alice);
        feeRouter.receiveFee{value: amount}();

        // Check treasury received 98.5%
        assertEq(treasury.balance, treasuryBalanceBefore + expectedTreasury);

        // Check FeeRouter kept 1.5% for bridging
        assertEq(address(feeRouter).balance, routerBalanceBefore + expectedHolo);
    }

    function testReceiveFee_ZeroAmount_Reverts() public {
        vm.expectRevert(FeeRouter.ZeroAmount.selector);
        vm.prank(alice);
        feeRouter.receiveFee{value: 0}();
    }

    function testReceiveFee_DirectTransfer() public {
        uint256 amount = 0.5 ether;
        uint256 expectedHolo = (amount * HOLO_FEE_BPS) / 10_000;
        uint256 expectedTreasury = amount - expectedHolo;

        vm.expectEmit(true, true, false, true);
        emit SlicePulled(address(0), address(0), expectedHolo, expectedTreasury);

        // Send ETH directly to contract (triggers receive())
        vm.prank(alice);
        (bool success, ) = address(feeRouter).call{value: amount}("");
        assertTrue(success);

        assertEq(treasury.balance, expectedTreasury);
        assertEq(address(feeRouter).balance, 1 ether + expectedHolo);
    }

    function testRouteFeeToken_ERC20Slicing() public {
        MockERC20 token = new MockERC20("Test Token", "TEST");
        uint256 amount = 1000e18;
        uint256 expectedHolo = (amount * HOLO_FEE_BPS) / 10_000;
        uint256 expectedTreasury = amount - expectedHolo;

        // Setup: give Alice tokens and approve FeeRouter
        token.mint(alice, amount);
        vm.prank(alice);
        token.approve(address(feeRouter), amount);

        vm.expectEmit(true, true, false, true);
        emit TokenReceived(alice, address(token), amount);

        vm.expectEmit(true, true, false, true);
        emit SlicePulled(address(0), address(token), expectedHolo, expectedTreasury);

        vm.prank(alice);
        feeRouter.routeFeeToken(address(token), amount);

        // Check treasury received 98.5%
        assertEq(token.balanceOf(treasury), expectedTreasury);

        // Check FeeRouter kept 1.5%
        assertEq(token.balanceOf(address(feeRouter)), expectedHolo);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Doppler Integration Tests                        */
    /* -------------------------------------------------------------------------- */

    function testPullAndSlice_OnlyKeeper() public {
        vm.expectRevert();
        vm.prank(alice);
        feeRouter.pullAndSlice(address(mockAirlock), address(0), 0.1 ether);
    }

    function testMockAirlock_Debug() public {
        uint128 amount = 0.5 ether;

        // Setup: fund the airlock
        vm.deal(address(mockAirlock), amount);

        // Check balance
        assertEq(address(mockAirlock).balance, amount);

        // Try to collect fees directly
        vm.prank(keeper);
        mockAirlock.collectIntegratorFees(address(feeRouter), address(0), amount);

        // MockAirlock now uses receiveAirlockFees() which doesn't trigger automatic slicing
        // So FeeRouter should receive the full amount
        assertEq(address(feeRouter).balance, 1 ether + amount); // 1 ether from setup + full amount
    }

    function testPullAndSlice_Success() public {
        uint128 amount = 0.5 ether;
        uint256 expectedHolo = (amount * HOLO_FEE_BPS) / 10_000; // 1.5%
        uint256 expectedTreasury = amount - expectedHolo; // 98.5%

        // Setup: fund the airlock to simulate fees
        vm.deal(address(mockAirlock), amount);
        mockAirlock.setCollectableAmount(address(0), amount);

        // Using receiveAirlockFees avoids reentrancy and double-slicing
        vm.expectEmit(true, true, false, true);
        emit SlicePulled(address(0), address(0), expectedHolo, expectedTreasury);

        vm.prank(keeper);
        feeRouter.pullAndSlice(address(mockAirlock), address(0), amount);

        assertEq(treasury.balance, expectedTreasury);
    }

    function testReceiveAirlockFees_Direct() public {
        uint256 amount = 0.3 ether;

        // Test calling receiveAirlockFees directly
        vm.deal(alice, amount);
        vm.prank(alice);
        feeRouter.receiveAirlockFees{value: amount}();

        // Should receive the full amount without slicing
        assertEq(address(feeRouter).balance, 1 ether + amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Bridging Tests                                   */
    /* -------------------------------------------------------------------------- */

    function testBridge_OnlyKeeper() public {
        vm.expectRevert();
        vm.prank(alice);
        feeRouter.bridge(200_000, 0);
    }

    function testBridge_DustProtection() public {
        // Set balance below MIN_BRIDGE_VALUE (0.01 ether)
        vm.deal(address(feeRouter), 0.005 ether);

        // Should not revert, just return early
        vm.prank(keeper);
        feeRouter.bridge(200_000, 0);

        // Balance should remain unchanged
        assertEq(address(feeRouter).balance, 0.005 ether);
    }

    function testBridge_AboveThreshold() public {
        uint256 amount = 0.05 ether; // Above MIN_BRIDGE_VALUE
        vm.deal(address(feeRouter), amount);

        vm.prank(keeper);
        feeRouter.bridge(200_000, 0);

        // Should have called LayerZero endpoint
        assertTrue(mockEndpoint.sendCalled());
        assertEq(mockEndpoint.lastValue(), amount);
    }

    function testBridgeToken_OnlyKeeper() public {
        MockERC20 token = new MockERC20("Test", "TEST");

        vm.expectRevert();
        vm.prank(alice);
        feeRouter.bridgeToken(address(token), 200_000, 0);
    }

    function testBridgeToken_Success() public {
        MockERC20 token = new MockERC20("Test", "TEST");
        uint256 amount = 100e18;

        // Fund FeeRouter with tokens
        token.mint(address(feeRouter), amount);

        vm.prank(keeper);
        feeRouter.bridgeToken(address(token), 200_000, 0);

        assertTrue(mockEndpoint.sendCalled());
        // Token should have been approved to endpoint
        assertEq(token.allowance(address(feeRouter), address(mockEndpoint)), amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Admin Function Tests                             */
    /* -------------------------------------------------------------------------- */

    function testSetTreasury_OnlyOwner() public {
        vm.expectRevert();
        vm.prank(alice);
        feeRouter.setTreasury(alice);
    }

    function testSetTreasury_ZeroAddress() public {
        vm.expectRevert(FeeRouter.ZeroAddress.selector);
        vm.prank(owner);
        feeRouter.setTreasury(address(0));
    }

    function testSetTreasury_Success() public {
        address newTreasury = address(0x999);

        vm.expectEmit(true, false, false, true);
        emit TreasuryUpdated(newTreasury);

        vm.prank(owner);
        feeRouter.setTreasury(newTreasury);

        assertEq(feeRouter.treasury(), newTreasury);
    }

    function testPause_OnlyOwner() public {
        vm.expectRevert();
        vm.prank(alice);
        feeRouter.pause();
    }

    function testPause_BlocksReceiveFee() public {
        vm.prank(owner);
        feeRouter.pause();

        vm.expectRevert();
        vm.prank(alice);
        feeRouter.receiveFee{value: 1 ether}();
    }

    function testUnpause_RestoresFunctionality() public {
        // Pause first
        vm.prank(owner);
        feeRouter.pause();

        // Unpause
        vm.prank(owner);
        feeRouter.unpause();

        // Should work again
        vm.prank(alice);
        feeRouter.receiveFee{value: 1 ether}();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Edge Cases                                    */
    /* -------------------------------------------------------------------------- */

    function testSlicing_OddAmounts() public {
        uint256 amount = 1 wei; // Smallest possible amount

        vm.prank(alice);
        feeRouter.receiveFee{value: amount}();

        // With 1 wei, 1.5% = 0 (rounds down), so treasury gets 1 wei
        assertEq(treasury.balance, 1 wei);
        assertEq(address(feeRouter).balance, 1 ether); // Original balance unchanged
    }

    function testSlicing_LargeAmounts() public {
        uint256 amount = 100 ether;
        uint256 expectedHolo = (amount * HOLO_FEE_BPS) / 10_000; // 1.5 ether
        uint256 expectedTreasury = amount - expectedHolo; // 98.5 ether

        vm.deal(alice, amount);
        vm.prank(alice);
        feeRouter.receiveFee{value: amount}();

        assertEq(treasury.balance, expectedTreasury);
        assertEq(address(feeRouter).balance, 1 ether + expectedHolo);
    }

    function testMultipleSlices_Accumulation() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;

        vm.prank(alice);
        feeRouter.receiveFee{value: amount1}();

        vm.prank(bob);
        feeRouter.receiveFee{value: amount2}();

        uint256 totalAmount = amount1 + amount2;
        uint256 expectedTotalHolo = (totalAmount * HOLO_FEE_BPS) / 10_000;
        uint256 expectedTotalTreasury = totalAmount - expectedTotalHolo;

        assertEq(treasury.balance, expectedTotalTreasury);
        assertEq(address(feeRouter).balance, 1 ether + expectedTotalHolo);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Fuzzing Tests                                  */
    /* -------------------------------------------------------------------------- */

    function testFuzz_SlicingPrecision(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000 ether);
        vm.deal(alice, amount);

        uint256 expectedHolo = (amount * HOLO_FEE_BPS) / 10_000;
        uint256 expectedTreasury = amount - expectedHolo;

        vm.prank(alice);
        feeRouter.receiveFee{value: amount}();

        // Verify precise slicing
        assertEq(treasury.balance, expectedTreasury);
        assertEq(address(feeRouter).balance, 1 ether + expectedHolo);

        // Verify total equals input
        assertEq(expectedHolo + expectedTreasury, amount);
    }

    function testMockAirlock_Simple() public {
        uint128 amount = 0.1 ether;

        // Fund MockAirlock
        vm.deal(address(mockAirlock), amount);

        // Check balance
        assertEq(address(mockAirlock).balance, amount);

        // Try collectIntegratorFees with alice (not FeeRouter)
        address recipient = alice;
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(keeper);
        mockAirlock.collectIntegratorFees(recipient, address(0), amount);

        // Check that alice received the ETH
        assertEq(recipient.balance, recipientBalanceBefore + amount);
    }

    function testMockAirlock_ToFeeRouter() public {
        uint128 amount = 0.1 ether;

        // Fund MockAirlock
        vm.deal(address(mockAirlock), amount);

        // Check balance
        assertEq(address(mockAirlock).balance, amount);

        // Try collectIntegratorFees with FeeRouter
        uint256 feeRouterBalanceBefore = address(feeRouter).balance;

        vm.prank(keeper);
        mockAirlock.collectIntegratorFees(address(feeRouter), address(0), amount);

        // FeeRouter should have received some ETH (might be sliced by receive())
        assertTrue(address(feeRouter).balance > feeRouterBalanceBefore);
    }
}
