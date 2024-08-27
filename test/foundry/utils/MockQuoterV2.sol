// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../../../src/interface/IQuoterV2.sol";

contract MockQuoterV2 is IQuoterV2 {
  uint256 public mockedAmountIn;
  uint160 public mockedSqrtPriceX96After;
  uint32 public mockedInitializedTicksCrossed;
  uint256 public mockedGasEstimate;

  function setMockedQuote(
    uint256 _amountIn,
    uint160 _sqrtPriceX96After,
    uint32 _initializedTicksCrossed,
    uint256 _gasEstimate
  ) public {
    mockedAmountIn = _amountIn;
    mockedSqrtPriceX96After = _sqrtPriceX96After;
    mockedInitializedTicksCrossed = _initializedTicksCrossed;
    mockedGasEstimate = _gasEstimate;
  }

  function quoteExactOutputSingle(
    QuoteExactOutputSingleParams calldata params
  )
    external
    override
    returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)
  {
    return (mockedAmountIn, mockedSqrtPriceX96After, mockedInitializedTicksCrossed, mockedGasEstimate);
  }
}
