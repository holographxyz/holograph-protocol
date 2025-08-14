// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UniswapV3TickMath} from "../src/lib/UniswapV3TickMath.sol";

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}

interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

/**
 * @title CreateHLGWETHPool
 * @notice Creates and manages Uniswap V3 HLG/WETH pools on Sepolia testnet
 * 
 * This script provides functionality for:
 * - Creating new pools with realistic pricing
 * - Adding balanced liquidity (requires both tokens)
 * - Adding single-sided liquidity (HLG-only or WETH-only)
 * - Managing different fee tiers and tick ranges
 * 
 * Environment Variables:
 * - INIT_PRICE_E18: Price scaled by 1e18 (default: 28100000000 = 2.81e-8 WETH/HLG)
 * - FEE_TIER: Fee tier (500, 3000, 10000) (default: 3000)
 * - MINT_HLG: HLG amount to deposit (wei) (default: 0)
 * - MINT_WETH: WETH amount to deposit (wei) (default: 0)
 * - RANGE_SPACINGS: Range width in tick spacings (default: 50)
 * - SLIPPAGE_BPS: Slippage protection in basis points (default: 500)
 * - RECIPIENT: LP NFT recipient (default: tx.origin)
 * 
 * Usage Examples:
 * 
 * # Create pool only (no liquidity)
 * forge script CreateHLGWETHPool --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --broadcast
 * 
 * # Add balanced liquidity
 * MINT_HLG=1000000000000000000000 MINT_WETH=28100000000000 forge script CreateHLGWETHPool --broadcast
 * 
 * # Add HLG-only liquidity  
 * MINT_HLG=50000000000000000000000000 MINT_WETH=0 forge script CreateHLGWETHPool --broadcast
 * 
 * # Create 0.05% fee tier pool
 * FEE_TIER=500 INIT_PRICE_E18=28100000000 forge script CreateHLGWETHPool --broadcast
 */

/// @notice Configuration struct for pool operations
struct PoolConfig {
    uint24 feeTier;           // Fee tier (500, 3000, 10000)
    uint256 priceE18;         // Initial price scaled by 1e18
    uint256 amount0Desired;   // Token0 amount to deposit  
    uint256 amount1Desired;   // Token1 amount to deposit
    uint256 slippageBps;      // Slippage protection in basis points
    address recipient;        // LP NFT recipient
    int24 rangeSpacings;      // Range width in tick spacings
}

contract CreateHLGWETHPool is Script {
    // Uniswap v3 Sepolia (from Uniswap docs)
    address constant UNISWAP_V3_FACTORY = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
    address constant NPM = 0x1238536071E1c677A632429e3655c799b22cDA52;
    address constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

    // HLG Sepolia
    address constant HLG = 0x5Ff07042d14E60EC1de7a860BBE968344431BaA1;

    // Fee tier and tick spacing will be derived at runtime from env to allow new pools
    // Default fee tier: 3000 (0.3%). Recommended for production: 500 (0.05%).

    // Default range width in multiples of tick spacing (configurable via env RANGE_SPACINGS)
    int24 constant DEFAULT_RANGE_SPACINGS = 50; // 50 * 60 = 3000 ticks

    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(pk);

        // Parse configuration from environment
        PoolConfig memory config = _parseConfig();
        
        // Determine token order (token0 < token1)
        (address token0, address token1) = HLG < WETH ? (HLG, WETH) : (WETH, HLG);
        
        console.log("=== Uniswap V3 Pool Creation ===");
        console.log("Token0 (lower address):", token0);
        console.log("Token1 (higher address):", token1);
        console.log("Fee tier:", config.feeTier);
        console.log("Initial price (E18):", config.priceE18);
        
        // Create or get existing pool
        address pool = _createOrGetPool(token0, token1, config);
        
        // Add liquidity if requested
        if (config.amount0Desired > 0 || config.amount1Desired > 0) {
            console.log("\n=== Adding Liquidity ===");
            
            // Determine liquidity strategy
            if (config.amount0Desired > 0 && config.amount1Desired > 0) {
                console.log("Strategy: Balanced liquidity");
                _addBalancedLiquidity(pool, token0, token1, config);
            } else if (config.amount0Desired > 0) {
                console.log("Strategy: Token0-only (single-sided above current price)");
                _addToken0OnlyLiquidity(pool, token0, token1, config);
            } else {
                console.log("Strategy: Token1-only (single-sided below current price)");
                _addToken1OnlyLiquidity(pool, token0, token1, config);
            }
        } else {
            console.log("\n=== Pool Created (No Liquidity Added) ===");
            console.log("Pool address:", pool);
        }

        vm.stopBroadcast();
    }

    // sqrtPriceX96 = floor(sqrt(price1_per_0) * 2^96), where price is scaled by 1e18
    function _encodeSqrtPriceX96FromPriceE18(uint256 priceE18) internal pure returns (uint160) {
        // priceE18 = price * 1e18  => sqrt(priceE18) = sqrt(price) * 1e9
        // sqrtPriceX96 = sqrt(price) * 2^96 = (sqrt(priceE18) * 2^96) / 1e9
        uint256 sqrtValue = _sqrt(priceE18);
        uint256 Q96 = 0x1000000000000000000000000; // 2**96
        uint256 result = (sqrtValue * Q96) / 1e9;
        require(result > 0 && result <= type(uint160).max, "sqrtPriceX96 overflow");
        return uint160(result);
    }

    // Integer sqrt using Babylonian method
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    // ========================================================================
    // Configuration and Setup Functions  
    // ========================================================================

    /**
     * @notice Parse pool configuration from environment variables
     * @return config Complete pool configuration
     */
    function _parseConfig() internal view returns (PoolConfig memory config) {
        // Basic configuration
        config.feeTier = uint24(_envOrUint("FEE_TIER", 3000));
        config.priceE18 = _envOrUint("INIT_PRICE_E18", 28100000000); // 2.81e-8 WETH per HLG
        config.slippageBps = _envOrUint("SLIPPAGE_BPS", 500); // 5%
        config.recipient = _envOrAddress("RECIPIENT", tx.origin);
        config.rangeSpacings = _envOrInt("RANGE_SPACINGS", DEFAULT_RANGE_SPACINGS);
        
        // Parse amounts - handle HLG/WETH mapping to token0/token1
        uint256 hlgAmount = _envOrUint("MINT_HLG", 0);
        uint256 wethAmount = _envOrUint("MINT_WETH", 0);
        
        if (HLG < WETH) {
            // HLG is token0, WETH is token1
            config.amount0Desired = hlgAmount;
            config.amount1Desired = wethAmount;
        } else {
            // WETH is token0, HLG is token1  
            config.amount0Desired = wethAmount;
            config.amount1Desired = hlgAmount;
        }
        
        // Validate configuration
        require(config.feeTier == 500 || config.feeTier == 3000 || config.feeTier == 10000, 
                "Invalid fee tier (supported: 500, 3000, 10000)");
        require(config.rangeSpacings > 0, "Range spacings must be positive");
    }

    /**
     * @notice Create pool if it doesn't exist, or return existing pool
     * @param token0 Lower address token  
     * @param token1 Higher address token
     * @param config Pool configuration
     * @return pool Pool address
     */
    function _createOrGetPool(
        address token0, 
        address token1, 
        PoolConfig memory config
    ) internal returns (address pool) {
        // Check if pool already exists
        address existing = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(token0, token1, config.feeTier);
        
        if (existing != address(0)) {
            console.log("Using existing pool:", existing);
            return existing;
        }
        
        // Create new pool
        console.log("Creating new pool...");
        uint160 sqrtPriceX96 = _encodeSqrtPriceX96FromPriceE18(config.priceE18);
        
        pool = INonfungiblePositionManager(NPM).createAndInitializePoolIfNecessary(
            token0, token1, config.feeTier, sqrtPriceX96
        );
        
        console.log("New pool created:", pool);
    }

    // ========================================================================
    // Liquidity Addition Functions
    // ========================================================================

    /**
     * @notice Add balanced liquidity that straddles current price
     * @param pool Pool address
     * @param token0 Token0 address
     * @param token1 Token1 address  
     * @param config Pool configuration
     */
    function _addBalancedLiquidity(
        address pool,
        address token0, 
        address token1,
        PoolConfig memory config
    ) internal {
        int24 tickSpacing = UniswapV3TickMath.tickSpacingForFee(config.feeTier);
        (, int24 currentTick, , , , ,) = IUniswapV3Pool(pool).slot0();
        
        (int24 tickLower, int24 tickUpper) = UniswapV3TickMath.calculateBalancedRange(
            currentTick, tickSpacing, config.rangeSpacings
        );
        
        console.log("Current tick:", vm.toString(currentTick));
        console.log("Tick range:", vm.toString(tickLower), "to", vm.toString(tickUpper));
        
        _mintPosition(pool, token0, token1, config, tickLower, tickUpper);
    }

    /**
     * @notice Add token0-only liquidity above current price
     * @param pool Pool address
     * @param token0 Token0 address
     * @param token1 Token1 address
     * @param config Pool configuration  
     */
    function _addToken0OnlyLiquidity(
        address pool,
        address token0,
        address token1, 
        PoolConfig memory config
    ) internal {
        int24 tickSpacing = UniswapV3TickMath.tickSpacingForFee(config.feeTier);
        (, int24 currentTick, , , , ,) = IUniswapV3Pool(pool).slot0();
        
        (int24 tickLower, int24 tickUpper) = UniswapV3TickMath.calculateSingleSidedRange(
            currentTick, tickSpacing, true, config.rangeSpacings
        );
        
        console.log("Current tick:", vm.toString(currentTick));
        console.log("Token0-only range:", vm.toString(tickLower), "to", vm.toString(tickUpper));
        console.log("(Range is ABOVE current price, only token0 required)");
        
        _mintPosition(pool, token0, token1, config, tickLower, tickUpper);
    }

    /**
     * @notice Add token1-only liquidity below current price
     * @param pool Pool address
     * @param token0 Token0 address
     * @param token1 Token1 address
     * @param config Pool configuration
     */
    function _addToken1OnlyLiquidity(
        address pool,
        address token0,
        address token1,
        PoolConfig memory config
    ) internal {
        int24 tickSpacing = UniswapV3TickMath.tickSpacingForFee(config.feeTier);
        (, int24 currentTick, , , , ,) = IUniswapV3Pool(pool).slot0();
        
        (int24 tickLower, int24 tickUpper) = UniswapV3TickMath.calculateSingleSidedRange(
            currentTick, tickSpacing, false, config.rangeSpacings
        );
        
        console.log("Current tick:", vm.toString(currentTick));
        console.log("Token1-only range:", vm.toString(tickLower), "to", vm.toString(tickUpper));
        console.log("(Range is BELOW current price, only token1 required)");
        
        _mintPosition(pool, token0, token1, config, tickLower, tickUpper);
    }

    /**
     * @notice Mint LP position with given tick range
     * @param pool Pool address
     * @param token0 Token0 address  
     * @param token1 Token1 address
     * @param config Pool configuration
     * @param tickLower Lower tick of range
     * @param tickUpper Upper tick of range
     */
    function _mintPosition(
        address pool,
        address token0,
        address token1, 
        PoolConfig memory config,
        int24 tickLower,
        int24 tickUpper
    ) internal {
        // Approve tokens for NPM (only approve non-zero amounts)
        if (config.amount0Desired > 0) {
            IERC20(token0).approve(NPM, config.amount0Desired);
        }
        if (config.amount1Desired > 0) {
            IERC20(token1).approve(NPM, config.amount1Desired);
        }
        
        // Calculate minimum amounts with slippage protection
        uint256 amount0Min = config.amount0Desired > 0 ? 
            (config.amount0Desired * (10_000 - config.slippageBps)) / 10_000 : 0;
        uint256 amount1Min = config.amount1Desired > 0 ? 
            (config.amount1Desired * (10_000 - config.slippageBps)) / 10_000 : 0;
        
        // Create mint parameters
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: config.feeTier,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: config.amount0Desired,
            amount1Desired: config.amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: config.recipient,
            deadline: block.timestamp + 1 hours
        });
        
        console.log("Minting position...");
        console.log("Amount0 desired:", config.amount0Desired);
        console.log("Amount1 desired:", config.amount1Desired);
        console.log("Amount0 min:", amount0Min);
        console.log("Amount1 min:", amount1Min);
        
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = 
            INonfungiblePositionManager(NPM).mint(params);
        
        console.log("Position minted successfully!");
        console.log("Token ID:", tokenId);
        console.log("Liquidity:", liquidity);
        console.log("Amount0 used:", amount0);
        console.log("Amount1 used:", amount1);
        console.log("Recipient:", config.recipient);
    }

    // ========================================================================
    // Utility Functions
    // ========================================================================

    function _envOrUint(string memory key, uint256 defaultValue) internal view returns (uint256) {
        try vm.envUint(key) returns (uint256 v) {
            return v;
        } catch {
            return defaultValue;
        }
    }

    function _envOrAddress(string memory key, address defaultValue) internal view returns (address) {
        try vm.envAddress(key) returns (address a) {
            return a;
        } catch {
            return defaultValue;
        }
    }
    
    function _envOrInt(string memory key, int24 defaultValue) internal view returns (int24) {
        try vm.envInt(key) returns (int256 v) {
            require(v >= type(int24).min && v <= type(int24).max, "int24 overflow");
            return int24(v);
        } catch {
            return defaultValue;
        }
    }
}
