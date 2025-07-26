// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @notice HolographBridge tests are temporarily disabled and commented out.
 * @dev These tests will be re-enabled when OFT (Omnichain Fungible Token)
 *      support is implemented in a future version. The bridge handles cross-chain
 *      token expansion and coordination via LayerZero.
 *
 * IMPORTANT: We are NOT removing all bridging from the protocol. The FeeRouter
 * still maintains full LayerZero support for bridging Doppler integrator fees
 * from Base to Ethereum. Only token bridging is being deferred to a future version.
 */

/*
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HolographBridge} from "../../src/HolographBridge.sol";
import {HolographFactory} from "../../src/HolographFactory.sol";
import {HolographFactoryProxy} from "../../src/HolographFactoryProxy.sol";
import {HolographERC20} from "../../src/HolographERC20.sol";
import {IHolographBridge} from "../../src/interfaces/IHolographBridge.sol";
import {ChainConfig} from "../../src/structs/BridgeStructs.sol";
import {MockLZEndpoint} from "../mock/MockLZEndpoint.sol";

**
 * @title HolographBridgeTest
 * @notice Comprehensive test suite for HolographBridge cross-chain coordination
 * @dev Tests cross-chain token expansion, peer configuration, and LayerZero integration
 *
contract HolographBridgeTest is Test {

    // ========== Test code omitted - will be restored in a future version ==========
    // Full test suite includes:
    // - Basic functionality tests (constructor, configuration)
    // - Token expansion tests (expandToChain)
    // - Creator authorization tests (tx.origin support)
    // - Admin function tests (pause/unpause, ownership)
    // - Edge cases and integration tests
    // - Fuzz testing for chain configurations
    
}
*/
