// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract MockAirlock {
    using SafeERC20 for IERC20;

    mapping(address => uint256) private _collectableAmounts;
    mapping(address => mapping(address => uint256)) private _tokenAmounts;

    event IntegratorFeesCollected(address indexed integrator, address indexed token, uint256 amount);

    /**
     * @notice Mock implementation of collectIntegratorFees
     * @param integrator The integrator address (should be FeeRouter)
     * @param token The token address (address(0) for ETH)
     * @param amount The amount to collect
     */
    function collectIntegratorFees(address integrator, address token, uint128 amount) external {
        if (token == address(0)) {
            // ETH case
            require(address(this).balance >= amount, "MockAirlock: Insufficient ETH");
            // Call receiveAirlockFees specifically to avoid reentrancy with pullAndSlice's nonReentrant modifier
            // The receive() function would cause reentrancy, but receiveAirlockFees doesn't
            bytes memory callData = abi.encodeWithSelector(bytes4(keccak256("receiveAirlockFees()")));
            (bool success, ) = integrator.call{value: amount}(callData);
            require(success, "MockAirlock: ETH transfer failed");
        } else {
            // ERC-20 case
            require(_tokenAmounts[token][integrator] >= amount, "MockAirlock: Insufficient token balance");
            _tokenAmounts[token][integrator] -= amount;
            IERC20(token).safeTransfer(integrator, amount);
        }

        emit IntegratorFeesCollected(integrator, token, amount);
    }

    /**
     * @notice Set collectable amount for testing
     */
    function setCollectableAmount(address token, uint256 amount) external {
        _collectableAmounts[token] = amount;
    }

    /**
     * @notice Set token balance for a specific integrator (for testing)
     */
    function setTokenBalance(address token, address integrator, uint256 amount) external {
        _tokenAmounts[token][integrator] = amount;
    }

    /**
     * @notice Get collectable amount
     */
    function getCollectableAmount(address token) external view returns (uint256) {
        return _collectableAmounts[token];
    }

    /**
     * @notice Get token balance for integrator
     */
    function getTokenBalance(address token, address integrator) external view returns (uint256) {
        return _tokenAmounts[token][integrator];
    }

    /**
     * @notice Allow contract to receive ETH
     */
    receive() external payable {}

    /**
     * @notice Fund contract with tokens for testing
     */
    function fundWithToken(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }
}
