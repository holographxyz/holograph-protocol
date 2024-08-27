// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Admin} from "../../abstract/Admin.sol";
import {Initializable} from "../../abstract/Initializable.sol";
import {IQuoterV2} from "../../interface/IQuoterV2.sol";

contract DropsPriceOracleBaseTestnetSepolia is Admin, Initializable {
  IQuoterV2 public quoterV2; // Immutable reference to the Quoter V2 interface

  address public constant WETH9 = 0x4200000000000000000000000000000000000006; // WETH address on Base Sepolia testnet
  address public constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC address on Base Sepolia testnet

  // Set the pool fee to 0.05% (the lowest option)
  uint24 public constant poolFee = 500;

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

  function setQuoter(address _quoterV2Address) public onlyAdmin {
    quoterV2 = IQuoterV2(_quoterV2Address);
  }

  /**
   * @notice Converts USDC value to native gas token value in wei
   * @dev It is important to note that different USD stablecoins use different decimal places.
   * @param usdAmount in USDC (6 decimal places)
   */
  function convertUsdToWei(uint256 usdAmount) external returns (uint256 weiAmount) {
    // NOTE: The following code is commented out because the QuoterV2 contract is not properly wired up to a functional Uniswap V3 pool on the Sepolia testnet
    // require(address(quoterV2) != address(0), "Quoter not set");
    // IQuoterV2.QuoteExactOutputSingleParams memory params = IQuoterV2.QuoteExactOutputSingleParams({
    //   tokenIn: WETH9, // WETH address
    //   tokenOut: USDC, // USDC address
    //   fee: poolFee, // Representing 0.05% pool fee
    //   amount: usdAmount, // USDC (USDC has 6 decimals)
    //   sqrtPriceLimitX96: 0 // No specific price limit
    // });
    // (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate) = quoterV2
    //   .quoteExactOutputSingle(params);
    // return amountIn; // this is the amount in wei to convert to the USDC value
    weiAmount = 3097578139223040;
  }
}
