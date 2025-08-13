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

    uint24 constant FEE_TIER = 3000; // 0.3%
    int24 constant TICK_SPACING = 60; // for 0.3%
    int24 constant MIN_TICK = -887220; // rounded to spacing
    int24 constant MAX_TICK = 887220; // rounded to spacing

    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(pk);

        // Determine token order (token0 < token1)
        (address token0, address token1) = HLG < WETH ? (HLG, WETH) : (WETH, HLG);

        // Compute sqrtPriceX96 from INIT_PRICE_E18 (token1 per token0, both assumed 18 decimals)
        uint256 priceE18 = _envOrUint("INIT_PRICE_E18", 1e15); // default 0.001 WETH per 1 HLG
        uint160 sqrtPriceX96 = _encodeSqrtPriceX96FromPriceE18(priceE18);

        // Create & initialize pool if needed
        address existing = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(token0, token1, FEE_TIER);
        address pool = existing;
        if (pool == address(0)) {
            pool = INonfungiblePositionManager(NPM).createAndInitializePoolIfNecessary(
                token0, token1, FEE_TIER, sqrtPriceX96
            );
        }

        // Optionally mint initial liquidity
        uint256 amt0 = _envOrUint("MINT_HLG", 0); // interpreted as token0 if token0==HLG
        uint256 amt1 = _envOrUint("MINT_WETH", 0); // interpreted as token1 if token1==WETH
        uint256 slippageBps = _envOrUint("SLIPPAGE_BPS", 500); // 5%
        address recipient = _envOrAddress("RECIPIENT", tx.origin);

        if (amt0 > 0 || amt1 > 0) {
            (uint256 amount0Desired, uint256 amount1Desired) = token0 == HLG ? (amt0, amt1) : (amt1, amt0);
            // Approvals
            IERC20(token0).approve(NPM, amount0Desired);
            IERC20(token1).approve(NPM, amount1Desired);

            // Min amounts (simple slippage protection)
            uint256 amount0Min = (amount0Desired * (10_000 - slippageBps)) / 10_000;
            uint256 amount1Min = (amount1Desired * (10_000 - slippageBps)) / 10_000;

            INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: FEE_TIER,
                tickLower: MIN_TICK,
                tickUpper: MAX_TICK,
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
        // Calculate sqrt(priceE18 * 1e18) to maintain precision
        uint256 sqrtValue = _sqrt(priceE18 * 1e18);
        // 2^96
        uint256 Q96 = 0x1000000000000000000000000; // 2**96
        // sqrtValue is sqrt(priceE18 * 1e18), so divide by 1e9 to get sqrt(priceE18)
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
}
