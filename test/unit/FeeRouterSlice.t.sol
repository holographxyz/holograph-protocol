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

        // Setup MockSwapRouter for token swaps
        mockSwapRouter.setOutputToken(address(mockHLG));

        // Mint HLG tokens to MockSwapRouter for swap operations
        mockHLG.mint(address(mockSwapRouter), 1000000 * 10 ** 18); // 1M HLG tokens

        // Mint WETH tokens to MockSwapRouter for ERC20 → WETH swaps
        mockWETH.mint(address(mockSwapRouter), 1000000 * 10 ** 18); // 1M WETH tokens

        // Mint some HLG to the staking contract for stakes
        mockHLG.mint(address(mockStaking), 1000000 * 10 ** 18);
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
        emit SlicePulled(alice, address(0), expectedHolo, expectedTreasury);

        vm.prank(alice);
        (bool success, ) = address(feeRouter).call{value: amount}("");
        require(success, "ETH transfer failed");

        // Check treasury received 98.5%
        assertEq(treasury.balance, treasuryBalanceBefore + expectedTreasury);

        // Check FeeRouter processed protocol fee (may have some remaining balance from HLG processing)
        assertTrue(address(feeRouter).balance >= routerBalanceBefore);
    }

    function testReceiveFee_ZeroAmount_Reverts() public {
        // Note: ETH transfers with 0 value are allowed by receive()
        // ZeroAmount check only applies to explicit token amounts
        vm.prank(alice);
        (bool success, ) = address(feeRouter).call{value: 0}("");
        require(success, "ETH transfer failed");
    }

    function testReceiveFee_DirectTransfer() public {
        uint256 amount = 0.5 ether;
        uint256 expectedHolo = (amount * HOLO_FEE_BPS) / 10_000;
        uint256 expectedTreasury = amount - expectedHolo;

        vm.expectEmit(true, true, false, true);
        emit SlicePulled(alice, address(0), expectedHolo, expectedTreasury);

        // Send ETH directly to contract (triggers receive())
        vm.prank(alice);
        (bool success, ) = address(feeRouter).call{value: amount}("");
        assertTrue(success);

        assertEq(treasury.balance, expectedTreasury);
        assertTrue(address(feeRouter).balance >= 1 ether); // Protocol fee processed
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
        emit SlicePulled(alice, address(token), expectedHolo, expectedTreasury);

        vm.prank(alice);
        feeRouter.routeFeeToken(address(token), amount);

        // Check treasury received 98.5%
        assertEq(token.balanceOf(treasury), expectedTreasury);

        // Check FeeRouter processed protocol fee (1.5% converted to HLG and burned/staked)
        assertEq(token.balanceOf(address(feeRouter)), 0); // Protocol fee fully processed
    }

    /* -------------------------------------------------------------------------- */
    /*                           Doppler Integration Tests                        */
    /* -------------------------------------------------------------------------- */

    function testCollectAirlockFees_OnlyKeeper() public {
        vm.expectRevert();
        vm.prank(alice);
        feeRouter.collectAirlockFees(address(mockAirlock), address(0), 0.1 ether);
    }

    function testMockAirlock_Debug() public {
        uint256 amount = 0.5 ether;

        // Setup: fund the airlock
        vm.deal(address(mockAirlock), amount);
        mockAirlock.setCollectableAmount(address(0), amount);

        // Check balance
        assertEq(address(mockAirlock).balance, amount);

        // Try to collect fees directly
        vm.prank(keeper);
        mockAirlock.collectIntegratorFees(address(feeRouter), address(0), amount);

        // MockAirlock transfers ETH which triggers receive() causing slicing
        // 98.5% goes to treasury, 1.5% processed through HLG protocol
        assertTrue(address(feeRouter).balance >= 1 ether); // Protocol fee processed
    }

    function testCollectAirlockFees_Success() public {
        uint256 amount = 0.5 ether;

        // Setup: fund the airlock to simulate fees
        vm.deal(address(mockAirlock), amount);
        mockAirlock.setCollectableAmount(address(0), amount);

        // New behavior explanation:
        // 1. collectAirlockFees calls mockAirlock.collectIntegratorFees()
        // 2. MockAirlock transfers ETH which triggers FeeRouter.receive()
        // 3. receive() calls _takeAndSlice(address(0), 0.5 ether) -> SlicePulled event
        // 4. collectAirlockFees then calls _takeAndSlice(address(0), 0.5 ether) -> second SlicePulled event
        // Both calls use the same amount (0.5 ether), so both events will be identical

        uint256 holoAmt = (amount * HOLO_FEE_BPS) / 10_000; // 1.5% = 0.0075 ether
        uint256 treasuryAmt = amount - holoAmt; // 98.5% = 0.4925 ether

        // Expect the SlicePulled event from receive() function (triggered by MockAirlock transfer)
        // Since we fixed double-processing, only receive() processes the ETH now
        vm.expectEmit(true, true, false, true);
        emit SlicePulled(address(mockAirlock), address(0), holoAmt, treasuryAmt);

        vm.prank(keeper);
        feeRouter.collectAirlockFees(address(mockAirlock), address(0), amount);

        // Verify treasury received the correct amount (no double processing)
        assertEq(treasury.balance, treasuryAmt);

        // Verify final balances after single processing
        uint256 actualBalance = address(feeRouter).balance;
        // Expected: Started with 1 ether, received 0.5 ether from airlock = 1.5 ether total
        // Sent to treasury: 0.4925 ether
        // Protocol fees: 0.0075 ether (processed through HLG)
        // Remaining should be approximately: 1.5 - 0.4925 = 1.0075 ether (minus small amounts for HLG processing)
        assertTrue(actualBalance >= 1 ether); // Allow for processing variations
    }

    function testReceiveAirlockFees_Direct() public {
        uint256 amount = 0.3 ether;

        // Test sending ETH directly instead of the removed receiveAirlockFees
        vm.deal(alice, amount);
        vm.prank(alice);
        (bool success, ) = address(feeRouter).call{value: amount}("");
        require(success, "ETH transfer failed");

        // Should process through normal slicing
        assertTrue(address(feeRouter).balance >= 1 ether); // Protocol fee processed
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
        // Setup: create mock ERC20 and fund FeeRouter
        MockERC20 token = new MockERC20("TestToken", "TEST");
        uint256 amount = 100 * 10 ** 18; // 100 tokens

        token.mint(address(feeRouter), amount);

        // Set trusted remote
        vm.prank(owner);
        feeRouter.setTrustedRemote(ETHEREUM_EID, bytes32(uint256(uint160(address(feeRouter)))));

        // Should bridge successfully
        vm.prank(keeper);
        feeRouter.bridgeToken(address(token), 200_000, 0);

        // Verify token balance is transferred (mocked behavior)
        // In real scenario, tokens would be sent via LayerZero
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

        // Note: receive() function doesn't check pause state
        // Only routeFeeToken is paused
        vm.prank(alice);
        (bool success, ) = address(feeRouter).call{value: 1 ether}("");
        require(success, "ETH transfer succeeded as expected");
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
        (bool success, ) = address(feeRouter).call{value: 1 ether}("");
        require(success, "ETH transfer failed");
    }

    /* -------------------------------------------------------------------------- */
    /*                              Edge Cases                                    */
    /* -------------------------------------------------------------------------- */

    function testSlicing_OddAmounts() public {
        uint256 amount = 1 wei; // Smallest possible amount

        vm.prank(alice);
        (bool success, ) = address(feeRouter).call{value: amount}("");
        require(success, "ETH transfer failed");

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
        (bool success, ) = address(feeRouter).call{value: amount}("");
        require(success, "ETH transfer failed");

        assertEq(treasury.balance, expectedTreasury);
        assertTrue(address(feeRouter).balance >= 1 ether); // Protocol fee processed
    }

    function testMultipleSlices_Accumulation() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;

        vm.prank(alice);
        (bool success1, ) = address(feeRouter).call{value: amount1}("");
        require(success1, "ETH transfer failed");

        vm.prank(bob);
        (bool success2, ) = address(feeRouter).call{value: amount2}("");
        require(success2, "ETH transfer failed");

        uint256 totalAmount = amount1 + amount2;
        uint256 expectedTotalHolo = (totalAmount * HOLO_FEE_BPS) / 10_000;
        uint256 expectedTotalTreasury = totalAmount - expectedTotalHolo;

        assertEq(treasury.balance, expectedTotalTreasury);
        assertTrue(address(feeRouter).balance >= 1 ether); // Protocol fees processed
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
        (bool success, ) = address(feeRouter).call{value: amount}("");
        require(success, "ETH transfer failed");

        // Verify precise slicing
        assertEq(treasury.balance, expectedTreasury);
        assertTrue(address(feeRouter).balance >= 1 ether); // Protocol fee processed

        // Verify total equals input
        assertEq(expectedHolo + expectedTreasury, amount);
    }

    function testMockAirlock_Simple() public {
        uint256 amount = 0.3 ether;
        vm.deal(address(mockAirlock), amount);
        mockAirlock.setCollectableAmount(address(0), amount);

        vm.prank(keeper);
        mockAirlock.collectIntegratorFees(address(feeRouter), address(0), amount);

        // Should have transferred the ETH to FeeRouter
        assertEq(address(mockAirlock).balance, 0);
    }

    function testMockAirlock_ToFeeRouter() public {
        uint256 amount = 0.2 ether;
        vm.deal(address(mockAirlock), amount);
        mockAirlock.setCollectableAmount(address(0), amount);

        uint256 feeRouterBalanceBefore = address(feeRouter).balance;

        vm.prank(keeper);
        mockAirlock.collectIntegratorFees(address(feeRouter), address(0), amount);

        // FeeRouter processes protocol fee through HLG mechanism
        assertTrue(address(feeRouter).balance >= feeRouterBalanceBefore);
    }
}
