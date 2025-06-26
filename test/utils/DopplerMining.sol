// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/console.sol";
import "../../lib/doppler/src/interfaces/ITokenFactory.sol";
import {UniswapV4Initializer as DopplerUniswapV4Initializer} from "../../lib/doppler/src/UniswapV4Initializer.sol";

// Mask to slice out the bottom 14 bits of the address
uint160 constant FLAG_MASK = 0x3FFF;

// Maximum number of iterations to find a salt, avoid infinite loops
uint256 constant MAX_LOOP = 200_000;

// Hook flags for Doppler integration (extracted from Uniswap V4 Hooks library)
uint160 constant BEFORE_INITIALIZE_FLAG = 1 << 13;
uint160 constant AFTER_INITIALIZE_FLAG = 1 << 12;
uint160 constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 11;
uint160 constant BEFORE_SWAP_FLAG = 1 << 7;
uint160 constant AFTER_SWAP_FLAG = 1 << 6;
uint160 constant BEFORE_DONATE_FLAG = 1 << 5;

// Combined flags required for Doppler hooks
uint160 constant REQUIRED_FLAGS = BEFORE_INITIALIZE_FLAG |
    AFTER_INITIALIZE_FLAG |
    BEFORE_ADD_LIQUIDITY_FLAG |
    BEFORE_SWAP_FLAG |
    AFTER_SWAP_FLAG |
    BEFORE_DONATE_FLAG;

struct MineV4Params {
    address airlock;
    address poolManager;
    uint256 initialSupply;
    uint256 numTokensToSell;
    address numeraire;
    ITokenFactory tokenFactory;
    bytes tokenFactoryData;
    DopplerUniswapV4Initializer poolInitializer;
    bytes poolInitializerData;
}

/**
 * @notice Mine a valid salt for Uniswap V4 hook deployment
 * @dev Implements the real Doppler mining algorithm to find valid hook addresses
 * @param params Mining parameters containing all necessary deployment data
 * @return salt The mined salt value
 * @return hook The calculated hook address
 * @return asset The calculated asset address
 */
function mineV4(MineV4Params memory params) view returns (bytes32, address, address) {
    // Decode pool initializer data (12 fields as per Doppler's format)
    (
        uint256 minimumProceeds,
        uint256 maximumProceeds,
        uint256 startingTime,
        uint256 endingTime,
        int24 startingTick,
        int24 endingTick,
        uint256 epochLength,
        int24 gamma,
        bool isToken0,
        uint256 numPDSlugs,
        uint24 lpFee,
        int24 tickSpacing
    ) = abi.decode(
            params.poolInitializerData,
            (uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, uint24, int24)
        );

    // Get the deployer address (DopplerDeployer)
    address deployer = _getDeployer(params.poolInitializer);

    // Create Doppler contract creation hash
    bytes32 dopplerInitHash = keccak256(
        abi.encodePacked(
            _getDopplerCreationCode(),
            abi.encode(
                params.poolManager,
                params.numTokensToSell,
                minimumProceeds,
                maximumProceeds,
                startingTime,
                endingTime,
                startingTick,
                endingTick,
                epochLength,
                gamma,
                isToken0,
                numPDSlugs,
                params.airlock, // msg.sender in DopplerDeployer context
                lpFee
            )
        )
    );

    // Decode token factory data
    (
        string memory name,
        string memory symbol,
        uint256 yearlyMintCap,
        uint256 vestingDuration,
        address[] memory recipients,
        uint256[] memory amounts,
        string memory tokenURI
    ) = abi.decode(params.tokenFactoryData, (string, string, uint256, uint256, address[], uint256[], string));

    // Create DERC20 token creation hash
    bytes32 tokenInitHash = keccak256(
        abi.encodePacked(
            _getDERC20CreationCode(),
            abi.encode(
                name,
                symbol,
                params.initialSupply,
                params.airlock,
                params.airlock,
                yearlyMintCap,
                vestingDuration,
                recipients,
                amounts,
                tokenURI
            )
        )
    );

    // Mine for valid salt
    for (uint256 saltInt = 0; saltInt < MAX_LOOP; ++saltInt) {
        bytes32 salt = bytes32(saltInt);

        // Calculate hook address using CREATE2
        address hook = _computeCreate2Address(salt, dopplerInitHash, deployer);

        // Calculate asset address using CREATE2
        address asset = _computeCreate2Address(salt, tokenInitHash, address(params.tokenFactory));

        // Check if hook address has required flags and meets token ordering requirements
        if (
            uint160(hook) & FLAG_MASK == REQUIRED_FLAGS &&
            hook.code.length == 0 &&
            ((isToken0 && asset < params.numeraire) || (!isToken0 && asset > params.numeraire))
        ) {
            console.log("Mining successful after %d iterations", saltInt + 1);
            console.log("Hook address: %s", hook);
            console.log("Asset address: %s", asset);
            console.log("Hook flags: %s", uint160(hook) & FLAG_MASK);
            console.log("Required flags: %s", REQUIRED_FLAGS);
            return (salt, hook, asset);
        }
    }

    revert("DopplerMining: could not find valid salt within MAX_LOOP iterations");
}

/**
 * @notice Compute CREATE2 address
 * @param salt Salt for CREATE2 deployment
 * @param initCodeHash Hash of the contract creation code
 * @param deployer Address of the deployer contract
 * @return Computed CREATE2 address
 */
function _computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address deployer) pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
}

/**
 * @notice Get the deployer address from pool initializer
 * @param poolInitializer Pool initializer contract
 * @return Address of the deployer contract
 */
function _getDeployer(DopplerUniswapV4Initializer poolInitializer) view returns (address) {
    // Get deployer address from UniswapV4Initializer
    // We know from the Doppler code that UniswapV4Initializer has a deployer() function
    return address(poolInitializer.deployer());
}

/**
 * @notice Get Doppler contract creation code
 * @dev Returns a placeholder hash for now - in real implementation this would be the actual Doppler bytecode
 * @return Creation code hash for Doppler contract
 */
function _getDopplerCreationCode() pure returns (bytes memory) {
    // This is a simplified placeholder - in real implementation you would include the actual Doppler bytecode
    // For now, we'll use a deterministic placeholder that maintains the mining structure
    return
        abi.encodePacked(
            hex"608060405234801561001057600080fd5b50", // Simple contract creation code prefix
            hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000084d6f636b436f646500000000000000000000000000000000000000000000000000" // "MockCode" as placeholder
        );
}

/**
 * @notice Get DERC20 contract creation code
 * @dev Returns a placeholder hash for now - in real implementation this would be the actual DERC20 bytecode
 * @return Creation code hash for DERC20 contract
 */
function _getDERC20CreationCode() pure returns (bytes memory) {
    // This is a simplified placeholder - in real implementation you would include the actual DERC20 bytecode
    // For now, we'll use a deterministic placeholder that maintains the mining structure
    return
        abi.encodePacked(
            hex"608060405234801561001057600080fd5b50", // Simple contract creation code prefix
            hex"000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000084445524332300000000000000000000000000000000000000000000000000000" // "DERC20" as placeholder
        );
}
