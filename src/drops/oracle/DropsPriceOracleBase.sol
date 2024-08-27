// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";
import {IQuoterV2} from "../../interface/IQuoterV2.sol";

contract DropsPriceOracleBase is Admin, Initializable {
  IQuoterV2 public quoterV2; // Immutable reference to the Quoter V2 interface

  address public constant WETH9 = 0x4200000000000000000000000000000000000006; // WETH address on Base mainnet
  address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC address on Base mainnet

  // Set the pool fee to 0.3% (the lowest option)
  uint24 public constant poolFee = 3000;

  constructor() {}

  /**
   * @notice Used internally to initialize the contract instead of through a constructor
   * @dev This function is called by the deployer/factory when creating a contract
   */
  function init(bytes memory) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    assembly {
      sstore(_adminSlot, origin())
    }

    _setInitialized();
    return Initializable.init.selector;
  }

  function setQuoter(IQuoterV2 _quoterV2) public onlyAdmin {
    quoterV2 = _quoterV2;
  }

  /**
   * @notice Converts USDC value to native gas token value in wei
   * @dev It is important to note that different USD stablecoins use different decimal places.
   * @param usdAmount in USDC (6 decimal places)
   */
  function convertUsdToWei(uint256 usdAmount) external returns (uint256 weiAmount) {
    require(address(quoterV2) != address(0), "Quoter not set");
    IQuoterV2.QuoteExactOutputSingleParams memory params = IQuoterV2.QuoteExactOutputSingleParams({
      tokenIn: WETH9, // WETH address
      tokenOut: USDC, // USDC address
      fee: poolFee, // Representing 0.3% pool fee
      amount: usdAmount, // USDC (USDC has 6 decimals)
      sqrtPriceLimitX96: 0 // No specific price limit
    });

    (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate) = quoterV2
      .quoteExactOutputSingle(params);

    return amountIn; // this is the amount in wei to convert to the USDC value
  }
}
