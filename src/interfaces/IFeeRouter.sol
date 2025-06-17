// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IFeeRouter
 * @notice Interface for omnichain fee routing with Doppler integration
 * @dev Defines the external API for fee collection, processing, and cross-chain bridging
 * @author Holograph Protocol
 */
interface IFeeRouter {
    /* -------------------------------------------------------------------------- */
    /*                                Fee Intake                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Receive ETH fees and process through single-slice model
     * @dev Main entry point for fee collection from HolographFactory
     */
    function receiveFee() external payable;

    /**
     * @notice Legacy ETH fee reception (maintained for compatibility)
     * @dev Alias for receiveFee() to support existing integrations
     */
    function routeFeeETH() external payable;

    /**
     * @notice Route ERC-20 token fees through the system
     * @dev Transfers tokens from sender and processes through single-slice model
     * @param token ERC-20 token contract address
     * @param amt Amount of tokens to process
     */
    function routeFeeToken(address token, uint256 amt) external;

    /* -------------------------------------------------------------------------- */
    /*                             Doppler Integration                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Pull accumulated fees from Doppler Airlock contracts
     * @dev Keeper-only function for automated fee collection from integrated protocols
     * @param airlock Airlock contract address to pull fees from
     * @param token Token address (address(0) for ETH)
     * @param amt Amount to pull from the Airlock
     */
    function pullAndSlice(address airlock, address token, uint256 amt) external;

    /* -------------------------------------------------------------------------- */
    /*                             Cross-Chain Bridging                           */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Bridge accumulated ETH to remote chain for HLG conversion
     * @dev Protected by dust threshold to prevent uneconomical transactions
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     */
    function bridge(uint256 minGas, uint256 minHlg) external;

    /**
     * @notice Bridge accumulated ERC-20 tokens to remote chain
     * @dev Handles token approval and LayerZero messaging for cross-chain transfer
     * @param token ERC-20 token contract address to bridge
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     */
    function bridgeToken(address token, uint256 minGas, uint256 minHlg) external;

    /* -------------------------------------------------------------------------- */
    /*                               Admin Functions                              */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Update treasury address (governance function)
     * @dev Critical governance function - validates non-zero address
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external;

    /**
     * @notice Set trusted remote address for cross-chain messaging
     * @dev Critical security function for LayerZero message validation
     * @param eid Remote chain endpoint ID
     * @param remote Trusted contract address on remote chain (as bytes32)
     */
    function setTrustedRemote(uint32 eid, bytes32 remote) external;

    /**
     * @notice Emergency pause of contract operations
     * @dev Circuit breaker to halt operations during emergencies
     */
    function pause() external;

    /**
     * @notice Resume contract operations after emergency pause
     * @dev Re-enables normal fee processing and bridging
     */
    function unpause() external;
}
