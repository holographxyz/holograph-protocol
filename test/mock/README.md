# Mock Contracts

This directory contains mock contracts for testing the Holograph fee management system. These contracts simulate external dependencies and provide controlled environments for testing.

## Available Mock Contracts

### MockERC20.sol

Standard ERC20 token implementation with minting capabilities.

**Features:**

- Standard ERC20 functionality (transfer, approve, etc.)
- Public `mint()` function for test setup
- 18 decimal places
- Used to simulate HLG token behavior

### MockLZEndpoint.sol

Simulates LayerZero V2 endpoint for cross-chain messaging.

**Features:**

- Cross-chain message simulation via `send()` function
- Configurable target endpoints and cross-chain targets
- Automatic message delivery simulation
- Event emission for message tracking
- Used to test FeeRouter cross-chain functionality

### MockWETH.sol

WETH9-compatible wrapper contract extending MockERC20.

**Features:**

- Inherits all MockERC20 functionality
- `deposit()` function to wrap ETH into WETH
- `withdraw()` function to unwrap WETH back to ETH
- Used to simulate WETH behavior in swap operations

### MockSwapRouter.sol

Simulates Uniswap V3 SwapRouter for token swapping.

**Features:**

- Implements `exactInputSingle()` function
- Realistic conversion rate: 0.000000139 WETH = 1 HLG (1 WETH = 7,194,245 HLG)
- Slippage protection via `amountOutMinimum`
- Only supports WETH → HLG swaps
- Includes ISwapRouter interface definition

## Usage

Import the required mock contracts in your test files:

```solidity
import {MockERC20} from "../mock/MockERC20.sol";
import {MockLZEndpoint} from "../mock/MockLZEndpoint.sol";
import {MockWETH} from "../mock/MockWETH.sol";
import {MockSwapRouter, ISwapRouter} from "../mock/MockSwapRouter.sol";
```

## Design Philosophy

These mock contracts are designed to:

- Provide deterministic behavior for reliable testing
- Simulate real-world contract interactions
- Enable edge case testing
- Maintain simplicity while covering essential functionality
- Support both unit and integration testing
