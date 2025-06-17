// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/interfaces/IDoppler.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockDoppler
 * @notice Mock implementation of Doppler hook for testing trading fee collection
 * @dev Simulates fee accumulation and collection during auction phases
 */
contract MockDoppler is IDoppler {
    using SafeERC20 for IERC20;

    /// @notice Accumulated fees per token
    mapping(address token => uint256 fees) public accumulatedFees;

    /// @notice Total balance per token (including fees)
    mapping(address token => uint256 balance) public totalBalances;

    /// @notice Whether the auction is currently active
    bool public isActive = true;

    /// @notice Total proceeds from sales
    uint256 public totalProceeds;

    /// @notice Total tokens sold
    uint256 public totalTokensSold;

    /// @notice Events for testing
    event FeesAccumulated(address indexed token, uint256 amount);
    event FeesCollected(address indexed to, address indexed token, uint256 amount);

    /**
     * @notice Simulate fee accumulation during trading
     * @param token Token address (address(0) for ETH)
     * @param fees Amount of fees to accumulate
     * @param balance Total balance including fees
     */
    function accumulateFees(address token, uint256 fees, uint256 balance) external payable {
        accumulatedFees[token] += fees;
        totalBalances[token] = balance;

        // Fund the contract with tokens if needed
        if (token != address(0) && fees > 0) {
            // For testing, assume caller provides the tokens
            IERC20(token).safeTransferFrom(msg.sender, address(this), fees);
        }

        emit FeesAccumulated(token, fees);
    }

    /**
     * @notice Set auction stats for testing
     * @param proceeds Total proceeds amount
     * @param tokensSold Total tokens sold amount
     */
    function setAuctionStats(uint256 proceeds, uint256 tokensSold) external {
        totalProceeds = proceeds;
        totalTokensSold = tokensSold;
    }

    /**
     * @notice Set auction active state
     * @param active Whether auction is active
     */
    function setAuctionActive(bool active) external {
        isActive = active;
    }

    /// @inheritdoc IDoppler
    function getAccumulatedFees(address token) external view returns (uint256 totalFees, uint256 totalBalance) {
        return (accumulatedFees[token], totalBalances[token]);
    }

    /// @inheritdoc IDoppler
    function collectAccumulatedFees(address to, address token, uint256 amount) external {
        require(amount <= accumulatedFees[token], "Insufficient fees");

        accumulatedFees[token] -= amount;

        if (token == address(0)) {
            // ETH transfer
            payable(to).transfer(amount);
        } else {
            // ERC20 transfer
            IERC20(token).safeTransfer(to, amount);
        }

        emit FeesCollected(to, token, amount);
    }

    /// @inheritdoc IDoppler
    function isAuctionActive() external view returns (bool) {
        return isActive;
    }

    /// @inheritdoc IDoppler
    function getAuctionStats() external view returns (uint256, uint256) {
        return (totalProceeds, totalTokensSold);
    }

    /// @notice Allow contract to receive ETH
    receive() external payable {}
}
