// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/FeeRouter.sol";
import "../../src/StakingRewards.sol";
import "../mock/MockLZEndpoint.sol";
import "../mock/MockWETH.sol";
import "../mock/MockHLG.sol";
import "../mock/MockSwapRouter.sol";
import "../mock/MockDoppler.sol";
import "../mock/MockERC20.sol";

/**
 * @title DopplerTradingFeesTest
 * @notice Test suite for Doppler trading fee collection during auction phases
 * @dev Tests the complete flow: registration → fee accumulation → collection → processing → bridging
 */
contract DopplerTradingFeesTest is Test {
    /* -------------------------------------------------------------------------- */
    /*                               Test Contracts                               */
    /* -------------------------------------------------------------------------- */

    FeeRouter public feeRouter;
    MockLZEndpoint public lzEndpoint;
    MockDoppler public dopplerHook1;
    MockDoppler public dopplerHook2;
    MockERC20 public testToken;

    /* -------------------------------------------------------------------------- */
    /*                                Test Actors                                 */
    /* -------------------------------------------------------------------------- */

    address public owner = address(0x1);
    address public treasury = address(0x2);
    address public user = address(0x3);

    /* -------------------------------------------------------------------------- */
    /*                                 Constants                                  */
    /* -------------------------------------------------------------------------- */

    uint32 constant BASE_EID = 30184;
    uint32 constant ETH_EID = 30101;

    /* -------------------------------------------------------------------------- */
    /*                                   Setup                                    */
    /* -------------------------------------------------------------------------- */

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock contracts
        lzEndpoint = new MockLZEndpoint();
        dopplerHook1 = new MockDoppler();
        dopplerHook2 = new MockDoppler();
        testToken = new MockERC20("Test Token", "TEST");

        // Deploy FeeRouter on Base (no HLG/WETH/SwapRouter)
        feeRouter = new FeeRouter(
            address(lzEndpoint),
            ETH_EID,
            address(0), // stakingPool
            address(0), // HLG
            address(0), // WETH
            address(0), // swapRouter
            treasury
        );

        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                              Hook Registration                             */
    /* -------------------------------------------------------------------------- */

    function testRegisterDopplerHook() public {
        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        assertTrue(feeRouter.activeDopplerHooks(address(dopplerHook1)));
        assertEq(feeRouter.getDopplerHooksCount(), 1);

        address[] memory hooks = feeRouter.getAllDopplerHooks();
        assertEq(hooks.length, 1);
        assertEq(hooks[0], address(dopplerHook1));
    }

    function testRegisterMultipleDopplerHooks() public {
        vm.startPrank(owner);

        feeRouter.registerDopplerHook(address(dopplerHook1));
        feeRouter.registerDopplerHook(address(dopplerHook2));

        vm.stopPrank();

        assertTrue(feeRouter.activeDopplerHooks(address(dopplerHook1)));
        assertTrue(feeRouter.activeDopplerHooks(address(dopplerHook2)));
        assertEq(feeRouter.getDopplerHooksCount(), 2);
    }

    function testCannotRegisterSameHookTwice() public {
        vm.startPrank(owner);

        feeRouter.registerDopplerHook(address(dopplerHook1));

        vm.expectRevert(FeeRouter.HookAlreadyActive.selector);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        vm.stopPrank();
    }

    function testCannotRegisterZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.ZeroAddress.selector);
        feeRouter.registerDopplerHook(address(0));
    }

    function testOnlyOwnerCanRegisterHooks() public {
        vm.prank(user);
        vm.expectRevert();
        feeRouter.registerDopplerHook(address(dopplerHook1));
    }

    /* -------------------------------------------------------------------------- */
    /*                             Hook Deregistration                            */
    /* -------------------------------------------------------------------------- */

    function testDeregisterDopplerHook() public {
        vm.startPrank(owner);

        feeRouter.registerDopplerHook(address(dopplerHook1));
        feeRouter.registerDopplerHook(address(dopplerHook2));

        feeRouter.deregisterDopplerHook(address(dopplerHook1));

        vm.stopPrank();

        assertFalse(feeRouter.activeDopplerHooks(address(dopplerHook1)));
        assertTrue(feeRouter.activeDopplerHooks(address(dopplerHook2)));
        assertEq(feeRouter.getDopplerHooksCount(), 1);

        address[] memory hooks = feeRouter.getAllDopplerHooks();
        assertEq(hooks.length, 1);
        assertEq(hooks[0], address(dopplerHook2));
    }

    function testCannotDeregisterInactiveHook() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.HookNotActive.selector);
        feeRouter.deregisterDopplerHook(address(dopplerHook1));
    }

    /* -------------------------------------------------------------------------- */
    /*                           Doppler Fee Calculation                          */
    /* -------------------------------------------------------------------------- */

    function testDopplerFeeCalculation() public {
        // Test the complex Doppler fee formula
        uint256 balance = 1000 ether;
        uint256 fees = 30 ether; // 3% trading fees

        // Expected calculation:
        // protocolLpFees = 30 / 20 = 1.5 ether (5% of trading fees)
        // protocolProceedsFees = (1000 - 30) / 1000 = 0.97 ether (0.1% of proceeds)
        // protocolFees = max(1.5, 0.97) = 1.5 ether
        // maxProtocolFees = 30 / 5 = 6 ether (20% cap)
        // Since 1.5 < 6, protocolFees = 1.5, integratorFees = 30 - 1.5 = 28.5 ether

        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        // Setup mock data
        dopplerHook1.accumulateFees{value: fees}(address(0), fees, balance);

        vm.prank(owner);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));

        // Check accumulated fees
        assertEq(feeRouter.accumulatedTradingFees(address(0)), 28.5 ether);
    }

    function testDopplerFeeCalculationWithCap() public {
        // Test case where protocol fee hits the 20% cap
        uint256 balance = 100 ether;
        uint256 fees = 50 ether; // 50% trading fees (extreme case)

        // Expected calculation:
        // protocolLpFees = 50 / 20 = 2.5 ether (5% of trading fees)
        // protocolProceedsFees = (100 - 50) / 1000 = 0.05 ether (0.1% of proceeds)
        // protocolFees = max(2.5, 0.05) = 2.5 ether
        // maxProtocolFees = 50 / 5 = 10 ether (20% cap)
        // Since 2.5 < 10, protocolFees = 2.5, integratorFees = 50 - 2.5 = 47.5 ether

        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        // Setup mock data
        dopplerHook1.accumulateFees{value: fees}(address(0), fees, balance);

        vm.prank(owner);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));

        // Check accumulated fees
        assertEq(feeRouter.accumulatedTradingFees(address(0)), 47.5 ether);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Trading Fee Collection                            */
    /* -------------------------------------------------------------------------- */

    function testCollectDopplerTradingFeesETH() public {
        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        // Simulate trading fees accumulation
        uint256 fees = 1 ether;
        uint256 balance = 10 ether;
        dopplerHook1.accumulateFees{value: fees}(address(0), fees, balance);

        uint256 feeRouterBalanceBefore = address(feeRouter).balance;

        vm.prank(owner);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));

        // Check that fees were collected
        uint256 expectedIntegratorFee = fees - (fees / 20); // fees - 5% protocol fee
        assertEq(feeRouter.accumulatedTradingFees(address(0)), expectedIntegratorFee);
    }

    function testCollectDopplerTradingFeesERC20() public {
        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        // Setup ERC20 fees
        uint256 fees = 100e18;
        uint256 balance = 1000e18;

        // Mint tokens and approve
        testToken.mint(address(this), fees);
        testToken.approve(address(dopplerHook1), fees);

        dopplerHook1.accumulateFees(address(testToken), fees, balance);

        vm.prank(owner);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(testToken));

        // Check that ERC20 fees were collected
        uint256 expectedIntegratorFee = fees - (fees / 20); // fees - 5% protocol fee
        assertEq(feeRouter.accumulatedTradingFees(address(testToken)), expectedIntegratorFee);
    }

    function testCannotCollectFromInactiveHook() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.HookNotActive.selector);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));
    }

    function testCollectZeroFeesDoesNothing() public {
        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        // No fees accumulated
        vm.prank(owner);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));

        // Should have no accumulated fees
        assertEq(feeRouter.accumulatedTradingFees(address(0)), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Batch Fee Collection                             */
    /* -------------------------------------------------------------------------- */

    function testBatchCollectDopplerTradingFees() public {
        vm.startPrank(owner);

        feeRouter.registerDopplerHook(address(dopplerHook1));
        feeRouter.registerDopplerHook(address(dopplerHook2));

        vm.stopPrank();

        // Setup fees in both hooks
        uint256 fees1 = 1 ether;
        uint256 fees2 = 2 ether;
        dopplerHook1.accumulateFees{value: fees1}(address(0), fees1, 10 ether);
        dopplerHook2.accumulateFees{value: fees2}(address(0), fees2, 20 ether);

        // Batch collect
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);

        vm.prank(owner);
        feeRouter.batchCollectDopplerTradingFees(tokens);

        // Check both hooks had fees collected
        uint256 expectedFees1 = fees1 - (fees1 / 20);
        uint256 expectedFees2 = fees2 - (fees2 / 20);
        assertEq(feeRouter.accumulatedTradingFees(address(0)), expectedFees1 + expectedFees2);
    }

    /* -------------------------------------------------------------------------- */
    /*                        Accumulated Fee Processing                          */
    /* -------------------------------------------------------------------------- */

    function testProcessAccumulatedTradingFees() public {
        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        // Collect some fees first
        uint256 fees = 1 ether;
        dopplerHook1.accumulateFees{value: fees}(address(0), fees, 10 ether);

        vm.prank(owner);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));

        uint256 accumulatedBefore = feeRouter.accumulatedTradingFees(address(0));
        uint256 treasuryBalanceBefore = treasury.balance;

        // Process accumulated fees
        vm.prank(owner);
        feeRouter.processAccumulatedTradingFees(address(0));

        // Check fees were processed through slicing
        assertEq(feeRouter.accumulatedTradingFees(address(0)), 0);

        // Treasury should receive 98.5% of accumulated fees
        uint256 expectedTreasuryFee = (accumulatedBefore * 9850) / 10000;
        assertEq(treasury.balance - treasuryBalanceBefore, expectedTreasuryFee);
    }

    function testProcessAllAccumulatedTradingFees() public {
        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        // Collect fees for both ETH and ERC20
        uint256 ethFees = 1 ether;
        uint256 tokenFees = 100e18;

        dopplerHook1.accumulateFees{value: ethFees}(address(0), ethFees, 10 ether);

        testToken.mint(address(this), tokenFees);
        testToken.approve(address(dopplerHook1), tokenFees);
        dopplerHook1.accumulateFees(address(testToken), tokenFees, 1000e18);

        vm.startPrank(owner);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(testToken));

        // Process all at once
        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = address(testToken);

        feeRouter.processAllAccumulatedTradingFees(tokens);
        vm.stopPrank();

        // Check all accumulated fees were processed
        assertEq(feeRouter.accumulatedTradingFees(address(0)), 0);
        assertEq(feeRouter.accumulatedTradingFees(address(testToken)), 0);
    }

    function testCannotProcessZeroAccumulatedFees() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.ZeroAmount.selector);
        feeRouter.processAccumulatedTradingFees(address(0));
    }

    /* -------------------------------------------------------------------------- */
    /*                              Manual Bridging                              */
    /* -------------------------------------------------------------------------- */

    function testManualBridgeETH() public {
        // Fund FeeRouter with ETH
        vm.deal(address(feeRouter), 1 ether);

        vm.prank(owner);
        feeRouter.manualBridge(address(0), 200_000, 0);

        // Check LayerZero was called
        assertTrue(lzEndpoint.sendCalled());
        assertEq(lzEndpoint.lastValue(), 1 ether);
    }

    function testManualBridgeERC20() public {
        // Fund FeeRouter with tokens
        testToken.mint(address(feeRouter), 100e18);

        vm.prank(owner);
        feeRouter.manualBridge(address(testToken), 200_000, 0);

        // Check LayerZero was called
        assertTrue(lzEndpoint.sendCalled());
    }

    function testCannotManualBridgeInsufficientBalance() public {
        // Try to bridge with insufficient balance
        vm.prank(owner);
        vm.expectRevert(FeeRouter.InsufficientBalance.selector);
        feeRouter.manualBridge(address(0), 200_000, 0);
    }

    function testOnlyOwnerCanManualBridge() public {
        vm.deal(address(feeRouter), 1 ether);

        vm.prank(user);
        vm.expectRevert();
        feeRouter.manualBridge(address(0), 200_000, 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Access Control                               */
    /* -------------------------------------------------------------------------- */

    function testOnlyOwnerCanCollectTradingFees() public {
        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        vm.prank(user);
        vm.expectRevert();
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));
    }

    function testOnlyOwnerCanProcessAccumulatedFees() public {
        vm.prank(user);
        vm.expectRevert();
        feeRouter.processAccumulatedTradingFees(address(0));
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    function testDopplerHookRegistrationEvent() public {
        vm.expectEmit(true, false, false, false);
        emit FeeRouter.DopplerHookRegistered(address(dopplerHook1));

        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));
    }

    function testDopplerTradingFeesCollectedEvent() public {
        vm.prank(owner);
        feeRouter.registerDopplerHook(address(dopplerHook1));

        uint256 fees = 1 ether;
        dopplerHook1.accumulateFees{value: fees}(address(0), fees, 10 ether);

        vm.expectEmit(true, true, false, false);
        emit FeeRouter.DopplerTradingFeesCollected(
            address(dopplerHook1),
            address(0),
            fees,
            fees / 20,
            fees - fees / 20
        );

        vm.prank(owner);
        feeRouter.collectDopplerTradingFees(address(dopplerHook1), address(0));
    }

    function testManualBridgeTriggeredEvent() public {
        vm.deal(address(feeRouter), 1 ether);

        vm.expectEmit(true, true, false, false);
        emit FeeRouter.ManualBridgeTriggered(owner, address(0), 1 ether);

        vm.prank(owner);
        feeRouter.manualBridge(address(0), 200_000, 0);
    }
}
