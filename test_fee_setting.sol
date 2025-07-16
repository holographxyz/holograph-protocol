// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/FeeRouter.sol";
import "../test/mock/MockLZEndpoint.sol";
import "../test/mock/MockSwapRouter.sol";

contract FeeSettingTest is Test {
    FeeRouter public feeRouter;
    MockLZEndpoint public lzEndpoint;
    MockSwapRouter public swapRouter;
    
    address public owner = address(0x1);
    address public treasury = address(0x2);
    
    function setUp() public {
        lzEndpoint = new MockLZEndpoint();
        swapRouter = new MockSwapRouter();
        
        vm.prank(owner);
        feeRouter = new FeeRouter(
            address(lzEndpoint),
            1, // remoteEid
            address(0), // stakingPool
            address(0), // hlg
            address(0), // weth
            address(0), // swapRouter
            treasury
        );
    }
    
    function test_SetHolographFee() public {
        // Initial fee should be 150 BPS (1.5%)
        assertEq(feeRouter.holographFeeBps(), 150);
        
        // Owner can set new fee
        vm.prank(owner);
        feeRouter.setHolographFee(200); // 2%
        
        assertEq(feeRouter.holographFeeBps(), 200);
        
        // Fee calculation should use new fee
        (uint256 protocolFee, uint256 treasuryFee) = feeRouter.calculateFeeSplit(1000e18);
        assertEq(protocolFee, (1000e18 * 200) / 10_000); // 2%
        assertEq(treasuryFee, 1000e18 - protocolFee); // 98%
    }
    
    function test_RevertSetHolographFeeExceedsMax() public {
        vm.prank(owner);
        vm.expectRevert(FeeRouter.FeeExceedsMaximum.selector);
        feeRouter.setHolographFee(10_001); // > 100%
    }
    
    function test_RevertNonOwnerCannotSetFee() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        feeRouter.setHolographFee(200);
    }
}