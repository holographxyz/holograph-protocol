// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IFeeRouter
 * @notice Interface for single-slice fee routing with Doppler integration
 * @dev Minimal interface for 1.5% protocol fee, 98.5% treasury distribution
 * @author Holograph Protocol
 */
interface IFeeRouter {
    /* -------------------------------------------------------------------------- */
    /*                                  Events                                    */
    /* -------------------------------------------------------------------------- */
    event SlicePulled(address indexed airlock, address indexed token, uint256 holoAmt, uint256 treasuryAmt);
    event TokenBridged(address indexed token, uint256 amount, uint64 nonce);
    event TrustedRemoteSet(uint32 indexed eid, bytes32 remote);
    event TreasuryUpdated(address indexed newTreasury);

    /* -------------------------------------------------------------------------- */
    /*                                  Errors                                    */
    /* -------------------------------------------------------------------------- */
    error NotEndpoint();
    error UntrustedRemote();
    error ZeroAddress();
    error ZeroAmount();

    /* -------------------------------------------------------------------------- */
    /*                               Functions                                    */
    /* -------------------------------------------------------------------------- */
    /**
     * @notice Receive ETH fees and process through single-slice model
     * @dev Main entry point for fee collection from HolographFactory
     */
    function receiveFee() external payable;

    /**
     * @notice Pull accumulated fees from Doppler Airlock contracts
     * @param airlock Airlock contract address to pull fees from
     * @param token Token address (address(0) for ETH)
     * @param amt Amount to pull from the Airlock
     */
    function collectAirlockFees(address airlock, address token, uint256 amt) external;

    /**
     * @notice Bridge accumulated ETH to remote chain for HLG conversion
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     */
    function bridge(uint256 minGas, uint256 minHlg) external;

    /**
     * @notice Bridge accumulated ERC-20 tokens to remote chain
     * @param token ERC-20 token contract address to bridge
     * @param minGas Minimum gas units for lzReceive execution on destination
     * @param minHlg Minimum HLG tokens expected from swap (slippage protection)
     */
    function bridgeToken(address token, uint256 minGas, uint256 minHlg) external;

    function setTrustedRemote(uint32 eid, bytes32 remote) external;
    function setTreasury(address newTreasury) external;
    function pause() external;
    function unpause() external;
    function getBalances() external view returns (uint256 ethBalance, uint256 hlgBalance);
    function calculateFeeSplit(uint256 amount) external pure returns (uint256 protocolFee, uint256 treasuryFee);
}
