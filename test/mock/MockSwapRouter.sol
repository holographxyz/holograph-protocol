// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockWETH} from "./MockWETH.sol";
import {MockERC20} from "./MockERC20.sol";

// Import the interface for type safety
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract MockSwapRouter {
    MockWETH public immutable WETH;
    MockERC20 public immutable HLG;

    // Realistic exchange rate: 0.000000139 WETH = 1 HLG
    // Therefore: 1 WETH = 7,194,245 HLG (1 / 0.000000139 ≈ 7,194,244.6)
    uint256 public constant EXCHANGE_RATE = 7194245;

    constructor(address _weth, address _hlg) {
        WETH = MockWETH(_weth);
        HLG = MockERC20(_hlg);
    }

    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut) {
        require(params.tokenIn == address(WETH), "Only WETH input supported");
        require(params.tokenOut == address(HLG), "Only HLG output supported");

        // Transfer WETH from sender
        WETH.transferFrom(msg.sender, address(this), params.amountIn);

        // Calculate HLG output using realistic rate: 1 WETH = 7,194,245 HLG
        // This reflects the real-world rate of 0.000000139 WETH per 1 HLG
        amountOut = params.amountIn * EXCHANGE_RATE;
        require(amountOut >= params.amountOutMinimum, "Insufficient output");

        // Mint HLG to recipient
        HLG.mint(params.recipient, amountOut);

        return amountOut;
    }
}
