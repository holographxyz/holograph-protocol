// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IDoppler
 * @notice Interface for Doppler hook contracts to collect trading fees
 * @dev Provides access to accumulated fees during auction phases
 * @author Holograph Protocol
 */
interface IDoppler {
    /**
     * @notice Get accumulated fees for a specific token
     * @dev Returns both total fees and total balance for fee calculation
     * @param token Token address to check fees for (address(0) for ETH)
     * @return totalFees Total trading fees accumulated
     * @return totalBalance Total balance including fees
     */
    function getAccumulatedFees(address token) external view returns (uint256 totalFees, uint256 totalBalance);

    /**
     * @notice Collect accumulated fees from the hook
     * @dev Transfers accumulated fees to the specified recipient
     * @param to Address to receive the fees
     * @param token Token address to collect fees for (address(0) for ETH)
     * @param amount Amount of fees to collect
     */
    function collectAccumulatedFees(address to, address token, uint256 amount) external;

    /**
     * @notice Check if the hook is in an active auction state
     * @dev Returns true if trading fees are being accumulated
     * @return isActive Whether the auction is currently active
     */
    function isAuctionActive() external view returns (bool isActive);

    /**
     * @notice Get the total proceeds and tokens sold
     * @dev Useful for calculating expected vs actual performance
     * @return totalProceeds Total proceeds from token sales
     * @return totalTokensSold Total tokens sold during auction
     */
    function getAuctionStats() external view returns (uint256 totalProceeds, uint256 totalTokensSold);
}
