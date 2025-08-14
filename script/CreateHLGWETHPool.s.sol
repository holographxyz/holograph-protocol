// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

/// @notice Creates and initializes the Uniswap v3 HLG/WETH pool on Sepolia, then optionally mints initial liquidity.
/// Env vars (optional but recommended):
/// - INIT_PRICE_E18: token1-per-token0 price scaled by 1e18 (default: 1e15 = 0.001 WETH per 1 HLG)
/// - MINT_HLG: amount of HLG (wei) to deposit as token0 liquidity (optional; if 0, skip mint)
/// - MINT_WETH: amount of WETH (wei) to deposit as token1 liquidity (optional; if 0, skip mint)
/// - SLIPPAGE_BPS: min-out slippage in bps for mint (default: 500)
/// - RECIPIENT: address to receive the LP NFT (default: tx.origin)
/// - DEPLOYER_PK: private key for broadcasting
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

        // Determine token order (token0 < token1)
        (address token0, address token1) = HLG < WETH ? (HLG, WETH) : (WETH, HLG);

        // Compute sqrtPriceX96 from INIT_PRICE_E18 (token1 per token0, both assumed 18 decimals)
        // Default to a realistic price for Sepolia: ~2.81e-8 WETH per 1 HLG
        uint256 priceE18 = _envOrUint("INIT_PRICE_E18", 28100000000); // 2.81e-8 WETH per 1 HLG
        uint160 sqrtPriceX96 = _encodeSqrtPriceX96FromPriceE18(priceE18);

        // Create & initialize pool if needed
        // Allow creating a fresh pool at a different fee tier by setting FEE_TIER env
        uint24 feeTier = uint24(_envOrUint("FEE_TIER", 3000));
        int24 tickSpacing = _tickSpacingForFee(feeTier);
        int24 minTick = _minTickForSpacing(tickSpacing);
        int24 maxTick = _maxTickForSpacing(tickSpacing);

        address existing = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(token0, token1, feeTier);
        address pool = existing;
        if (pool == address(0)) {
            pool = INonfungiblePositionManager(NPM).createAndInitializePoolIfNecessary(
                token0, token1, feeTier, sqrtPriceX96
            );
        }

        // Optionally mint initial liquidity
        uint256 amt0 = _envOrUint("MINT_HLG", 0); // interpreted as token0 if token0==HLG
        uint256 amt1 = _envOrUint("MINT_WETH", 0); // interpreted as token1 if token1==WETH
        uint256 slippageBps = _envOrUint("SLIPPAGE_BPS", 500); // 5%
        address recipient = _envOrAddress("RECIPIENT", tx.origin);

        if (amt0 > 0 || amt1 > 0) {
            (uint256 amount0Desired, uint256 amount1Desired) = token0 == HLG ? (amt0, amt1) : (amt1, amt0);
            // Approvals - only approve non-zero amounts
            if (amount0Desired > 0) IERC20(token0).approve(NPM, amount0Desired);
            if (amount1Desired > 0) IERC20(token1).approve(NPM, amount1Desired);

            // Min amounts (simple slippage protection) - allow zero minimums
            uint256 amount0Min = amount0Desired > 0 ? (amount0Desired * (10_000 - slippageBps)) / 10_000 : 0;
            uint256 amount1Min = amount1Desired > 0 ? (amount1Desired * (10_000 - slippageBps)) / 10_000 : 0;

            // Determine current pool tick
            (, int24 currentTick, , , , ,) = IUniswapV3Pool(pool).slot0();

            // Choose tick range based on single- or dual-sided liquidity
            int24 tickLower;
            int24 tickUpper;

            int24 rangeSpacings = _envOrInt("RANGE_SPACINGS", DEFAULT_RANGE_SPACINGS);
            if (rangeSpacings <= 0) {
                rangeSpacings = DEFAULT_RANGE_SPACINGS;
            }

            int24 currentFloored = _floorToSpacing(currentTick, tickSpacing);

            if (amount1Desired == 0 && amount0Desired > 0) {
                // Token0-only (HLG) — place entirely ABOVE current price so only token0 is required at mint
                // For token0-only: current price must be BELOW the range => set lower/upper above current
                tickLower = _clampToBounds(_add(currentFloored, _oneSpacing(tickSpacing)), minTick, maxTick);
                tickUpper = _clampToBounds(_add(tickLower, _mulSpacing(rangeSpacings, tickSpacing)), minTick, maxTick);
            } else if (amount0Desired == 0 && amount1Desired > 0) {
                // Token1-only (WETH) — place entirely BELOW current price so only token1 is required at mint
                // For token1-only: current price must be ABOVE the range => set upper/lower below current
                tickUpper = _clampToBounds(_add(currentFloored, -_oneSpacing(tickSpacing)), minTick, maxTick);
                tickLower = _clampToBounds(_add(tickUpper, -_mulSpacing(rangeSpacings, tickSpacing)), minTick, maxTick);
            } else {
                // Balanced liquidity — straddle current price
                tickLower = _clampToBounds(_add(currentFloored, -_mulSpacing(rangeSpacings, tickSpacing)), minTick, maxTick);
                tickUpper = _clampToBounds(_add(currentFloored, _mulSpacing(rangeSpacings, tickSpacing)), minTick, maxTick);
            }

            INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: feeTier,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                recipient: recipient,
                deadline: block.timestamp + 1 hours
            });

            INonfungiblePositionManager(NPM).mint(params);
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

    // ----- Tick math helpers -----
    function _tickSpacingForFee(uint24 fee) internal pure returns (int24) {
        if (fee == 100) return 1;      // 0.01%
        if (fee == 500) return 10;     // 0.05%
        if (fee == 3000) return 60;    // 0.3%
        if (fee == 10000) return 200;  // 1%
        revert("unsupported fee tier");
    }

    function _oneSpacing(int24 spacing) internal pure returns (int24) {
        return spacing;
    }

    function _mulSpacing(int24 count, int24 spacing) internal pure returns (int24) {
        int256 r = int256(spacing) * int256(count);
        require(r >= type(int24).min && r <= type(int24).max, "tick mul overflow");
        return int24(r);
    }

    function _add(int24 a, int24 b) internal pure returns (int24) {
        int256 r = int256(a) + int256(b);
        require(r >= type(int24).min && r <= type(int24).max, "tick add overflow");
        return int24(r);
    }

    function _floorToSpacing(int24 tick, int24 spacing) internal pure returns (int24) {
        int24 rem = tick % spacing;
        if (rem == 0) return tick;
        if (rem > 0) return tick - rem;
        // rem < 0
        return tick - rem - spacing;
    }

    function _clampToBounds(int24 tick, int24 minTick, int24 maxTick) internal pure returns (int24) {
        if (tick < minTick) return minTick;
        if (tick > maxTick) return maxTick;
        return tick;
    }

    function _minTickForSpacing(int24 spacing) internal pure returns (int24) {
        // Global Uniswap v3 absolute min tick is -887272
        // Legal ticks are multiples of spacing within [-887272, 887272]
        // Using Solidity's division rounding toward zero yields the nearest legal multiple above -887272
        int24 q = int24((int256(-887272) / int256(spacing)) * int256(spacing));
        // q will be -887220 for spacing=60, which is correct
        return q;
    }

    function _maxTickForSpacing(int24 spacing) internal pure returns (int24) {
        int24 minTick = _minTickForSpacing(spacing);
        return int24(-minTick);
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
