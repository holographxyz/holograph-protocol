// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ----------------------------------------------------------------------------
 * FeeRouter (Holograph 2.0)
 * ----------------------------------------------------------------------------
 * • Splits protocol fees 50 % to Treasury, 50 % to StakingRewards.
 * • Handles native ETH and arbitrary ERC-20 tokens.
 * • Minimal surface, non-upgradeable; redeploy on logic changes.
 * ----------------------------------------------------------------------------
 */

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

contract FeeRouter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*──────────────────────────────────────────────────────────────────────────
        Errors
    ──────────────────────────────────────────────────────────────────────────*/
    error ZeroAddress();
    error ZeroAmount();
    error UseRouteFeeETH();
    error EthTransferFailed();

    /*──────────────────────────────────────────────────────────────────────────
        Storage
    ──────────────────────────────────────────────────────────────────────────*/
    address public treasury; // receives 50 % of every fee
    address public stakingRewards; // receives 50 % of every fee

    /*──────────────────────────────────────────────────────────────────────────
        Events
    ──────────────────────────────────────────────────────────────────────────*/
    event DestinationsUpdated(address treasury, address stakingRewards);
    event FeeRouted(
        address indexed payer,
        address indexed asset,
        uint256 totalAmount,
        uint256 toTreasury,
        uint256 toStaking
    );

    /*──────────────────────────────────────────────────────────────────────────
        Constructor
    ──────────────────────────────────────────────────────────────────────────*/
    constructor(address _treasury, address _stakingRewards) Ownable(msg.sender) {
        if (_treasury == address(0) || _stakingRewards == address(0)) revert ZeroAddress();
        treasury = _treasury;
        stakingRewards = _stakingRewards;
    }

    /*──────────────────────────────────────────────────────────────────────────
        Admin
    ──────────────────────────────────────────────────────────────────────────*/
    function setDestinations(address _treasury, address _stakingRewards) external onlyOwner {
        if (_treasury == address(0) || _stakingRewards == address(0)) revert ZeroAddress();
        treasury = _treasury;
        stakingRewards = _stakingRewards;
        emit DestinationsUpdated(_treasury, _stakingRewards);
    }

    /*──────────────────────────────────────────────────────────────────────────
        Fee routing – ERC-20 path
    ──────────────────────────────────────────────────────────────────────────*/
    /** @notice Caller **must** have approved `amount` prior to calling. */
    function routeFee(address asset, uint256 amount) external nonReentrant {
        if (asset == address(0)) revert UseRouteFeeETH();
        if (amount == 0) revert ZeroAmount();

        uint256 half = amount / 2;
        uint256 remainder = amount - half; // handles odd numbers safely

        IERC20(asset).safeTransferFrom(msg.sender, treasury, half);
        IERC20(asset).safeTransferFrom(msg.sender, stakingRewards, remainder);

        emit FeeRouted(msg.sender, asset, amount, half, remainder);
    }

    /*──────────────────────────────────────────────────────────────────────────
        Fee routing – native ETH path
    ──────────────────────────────────────────────────────────────────────────*/
    function routeFeeETH() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        _splitETH(msg.value);
        emit FeeRouted(msg.sender, address(0), msg.value, msg.value / 2, msg.value - msg.value / 2);
    }

    receive() external payable {
        if (msg.value > 0) {
            _splitETH(msg.value);
            emit FeeRouted(msg.sender, address(0), msg.value, msg.value / 2, msg.value - msg.value / 2);
        }
    }

    /*──────────────────────────────────────────────────────────────────────────
        Internals
    ──────────────────────────────────────────────────────────────────────────*/
    function _splitETH(uint256 amount) private {
        uint256 half = amount / 2;
        (bool s1, ) = payable(treasury).call{value: half}("");
        (bool s2, ) = payable(stakingRewards).call{value: amount - half}("");
        if (!s1 || !s2) revert EthTransferFailed();
    }
}
