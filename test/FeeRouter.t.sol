// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {FeeRouter} from "../src/FeeRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockERC20} from "./mock/MockERC20.sol";

contract FeeRouterTest is Test {
    FeeRouter public router;
    address treasury = vm.addr(1);
    address staking = vm.addr(2);

    MockERC20 public token;

    function setUp() public {
        token = new MockERC20();
        router = new FeeRouter(treasury, staking);
    }

    /*────────────────────────────────────────────
        Constructor / Admin
    ───────────────────────────────────────────*/
    function testConstructorStoresDestinations() public view {
        assertEq(router.treasury(), treasury);
        assertEq(router.stakingRewards(), staking);
    }

    function testSetDestinations() public {
        address newTreasury = vm.addr(3);
        address newStaking = vm.addr(4);

        vm.prank(router.owner());
        router.setDestinations(newTreasury, newStaking);
        assertEq(router.treasury(), newTreasury);
        assertEq(router.stakingRewards(), newStaking);
    }

    /*────────────────────────────────────────────
        ERC‑20 path
    ───────────────────────────────────────────*/
    function testRouteFeeERC20() public {
        uint256 fee = 1e18;
        token.mint(address(this), fee);
        token.approve(address(router), fee);

        router.routeFee(address(token), fee);

        assertEq(token.balanceOf(treasury), fee / 2);
        assertEq(token.balanceOf(staking), fee - fee / 2);
    }

    function testRouteFeeERC20RevertsIfZeroAmount() public {
        vm.expectRevert(FeeRouter.ZeroAmount.selector);
        router.routeFee(address(token), 0);
    }

    function testRouteFeeERC20RevertsIfETHAsset() public {
        vm.expectRevert(FeeRouter.UseRouteFeeETH.selector);
        router.routeFee(address(0), 1);
    }

    /*────────────────────────────────────────────
        ETH path
    ───────────────────────────────────────────*/
    function testRouteFeeETHViaFunction() public {
        uint256 fee = 1 ether;
        router.routeFeeETH{value: fee}();
        assertEq(treasury.balance, fee / 2);
        assertEq(staking.balance, fee - fee / 2);
    }

    function testRouteFeeETHViaReceive() public {
        uint256 fee = 2 ether;
        (bool s, ) = payable(address(router)).call{value: fee}("");
        require(s, "send failed");
        assertEq(treasury.balance, fee / 2);
        assertEq(staking.balance, fee - fee / 2);
    }

    function testRouteFeeETHRevertsIfZero() public {
        vm.expectRevert(FeeRouter.ZeroAmount.selector);
        router.routeFeeETH();
    }
}
