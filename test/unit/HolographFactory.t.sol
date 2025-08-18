// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HolographFactory} from "../../src/HolographFactory.sol";
import {HolographFactoryProxy} from "../../src/HolographFactoryProxy.sol";
import {HolographERC20} from "../../src/HolographERC20.sol";
import {ITokenFactory} from "../../src/interfaces/external/doppler/ITokenFactory.sol";

/**
 * @title HolographFactoryTest
 * @notice Comprehensive test suite for HolographFactory implementing ITokenFactory
 * @dev Tests the new architecture with proxy pattern and clone deployments
 */
contract HolographFactoryTest is Test {
    HolographFactory public factory;
    HolographFactory public factoryImpl;
    HolographERC20 public erc20Implementation;

    address public owner = address(this);
    address public airlock = address(0x1234);
    address public user = address(0x5678);

    // Test token parameters
    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint256 constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 constant YEARLY_MINT_CAP = 15e15; // 1.5% yearly inflation
    uint256 constant VESTING_DURATION = 365 days;
    string constant TOKEN_URI = "https://test.token.uri";

    bytes32 constant TEST_SALT = bytes32(uint256(12345));

    event TokenDeployed(
        address indexed token,
        string name,
        string symbol,
        uint256 initialSupply,
        address indexed recipient,
        address indexed owner,
        address creator
    );

    event AirlockAuthorizationSet(address indexed airlock, bool authorized);

    function setUp() public {
        // Deploy ERC20 implementation for cloning
        erc20Implementation = new HolographERC20();

        // Deploy factory implementation
        factoryImpl = new HolographFactory(address(erc20Implementation));

        // Deploy proxy
        HolographFactoryProxy proxy = new HolographFactoryProxy(address(factoryImpl));

        // Cast proxy to factory interface
        factory = HolographFactory(address(proxy));

        // Initialize factory
        factory.initialize(owner);

        // Authorize test airlock
        factory.setAirlockAuthorization(airlock, true);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Basic Functionality                          */
    /* -------------------------------------------------------------------------- */

    function test_Constructor() public {
        assertEq(factory.erc20Implementation(), address(erc20Implementation));
        assertEq(factory.owner(), owner);
    }

    function test_AuthorizeAirlock() public {
        address newAirlock = address(0x9999);

        vm.expectEmit(true, false, false, true);
        emit AirlockAuthorizationSet(newAirlock, true);

        factory.setAirlockAuthorization(newAirlock, true);
        assertTrue(factory.isAuthorizedAirlock(newAirlock));
    }

    function test_UnauthorizeAirlock() public {
        factory.setAirlockAuthorization(airlock, false);
        assertFalse(factory.isAuthorizedAirlock(airlock));
    }

    function test_RevertOnZeroAddressAirlock() public {
        vm.expectRevert(HolographFactory.ZeroAddress.selector);
        factory.setAirlockAuthorization(address(0), true);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Token Creation                               */
    /* -------------------------------------------------------------------------- */

    function test_CreateToken() public {
        bytes memory tokenData = _encodeTokenData(
            TOKEN_NAME, TOKEN_SYMBOL, YEARLY_MINT_CAP, VESTING_DURATION, new address[](0), new uint256[](0), TOKEN_URI
        );

        vm.prank(airlock, airlock);
        // We can't predict the exact token address, so don't check it
        vm.expectEmit(false, true, true, true);
        emit TokenDeployed(address(0), TOKEN_NAME, TOKEN_SYMBOL, INITIAL_SUPPLY, user, owner, airlock);

        address token = factory.create(INITIAL_SUPPLY, user, owner, TEST_SALT, tokenData);

        // Verify token properties
        HolographERC20 holographToken = HolographERC20(token);
        assertEq(holographToken.name(), TOKEN_NAME);
        assertEq(holographToken.symbol(), TOKEN_SYMBOL);
        assertEq(holographToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(holographToken.balanceOf(user), INITIAL_SUPPLY);
        assertEq(holographToken.owner(), owner);
        assertEq(holographToken.yearlyMintRate(), YEARLY_MINT_CAP);
        assertEq(holographToken.vestingDuration(), VESTING_DURATION);
        assertEq(holographToken.tokenURI(), TOKEN_URI);

        // Verify factory tracking
        assertTrue(factory.isDeployedToken(token));

        // Verify creator tracking (airlock is the caller, tx.origin is the creator)
        assertTrue(factory.isTokenCreator(token, airlock));
    }

    function test_CreateTokenWithVesting() public {
        address[] memory recipients = new address[](2);
        recipients[0] = address(0x1111);
        recipients[1] = address(0x2222);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50_000e18;
        amounts[1] = 25_000e18;

        bytes memory tokenData = _encodeTokenData(
            TOKEN_NAME, TOKEN_SYMBOL, YEARLY_MINT_CAP, VESTING_DURATION, recipients, amounts, TOKEN_URI
        );

        vm.prank(airlock, airlock);
        address token = factory.create(INITIAL_SUPPLY, user, owner, TEST_SALT, tokenData);

        HolographERC20 holographToken = HolographERC20(token);

        // Check vesting setup (implementation depends on vesting logic in HolographERC20)
        assertEq(holographToken.vestingDuration(), VESTING_DURATION);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Access Control                               */
    /* -------------------------------------------------------------------------- */

    function test_RevertOnUnauthorizedCaller() public {
        bytes memory tokenData = _encodeTokenData(
            TOKEN_NAME, TOKEN_SYMBOL, YEARLY_MINT_CAP, VESTING_DURATION, new address[](0), new uint256[](0), TOKEN_URI
        );

        vm.prank(user); // Unauthorized caller
        vm.expectRevert(HolographFactory.UnauthorizedCaller.selector);

        factory.create(INITIAL_SUPPLY, user, owner, TEST_SALT, tokenData);
    }

    function test_RevertOnInvalidTokenData() public {
        vm.prank(airlock, airlock);
        vm.expectRevert(HolographFactory.InvalidTokenData.selector);

        factory.create(
            INITIAL_SUPPLY,
            user,
            owner,
            TEST_SALT,
            "" // Empty token data
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                              Admin Functions                              */
    /* -------------------------------------------------------------------------- */

    function test_RevertOnNonOwnerAirlockAuth() public {
        vm.prank(user);
        vm.expectRevert(); // Modern OpenZeppelin uses custom errors
        factory.setAirlockAuthorization(address(0x9999), true);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Creator Tracking                             */
    /* -------------------------------------------------------------------------- */

    function test_CreatorTracking() public {
        bytes memory tokenData = _encodeTokenData(
            TOKEN_NAME, TOKEN_SYMBOL, YEARLY_MINT_CAP, VESTING_DURATION, new address[](0), new uint256[](0), TOKEN_URI
        );

        vm.prank(airlock, airlock);
        address token = factory.create(INITIAL_SUPPLY, user, owner, TEST_SALT, tokenData);

        // Verify creator tracking
        assertTrue(factory.isTokenCreator(token, airlock));
        assertFalse(factory.isTokenCreator(token, user));
        assertFalse(factory.isTokenCreator(token, owner));
        assertFalse(factory.isTokenCreator(token, address(this)));
    }

    function test_CreatorTrackingWithTxOrigin() public {
        bytes memory tokenData = _encodeTokenData(
            TOKEN_NAME, TOKEN_SYMBOL, YEARLY_MINT_CAP, VESTING_DURATION, new address[](0), new uint256[](0), TOKEN_URI
        );

        // Simulate a more realistic scenario where tx.origin differs from msg.sender
        vm.prank(airlock, user); // airlock calls, but user is tx.origin
        address token = factory.create(INITIAL_SUPPLY, user, owner, TEST_SALT, tokenData);

        // Verify that tx.origin (user) is tracked as creator, not msg.sender (airlock)
        assertTrue(factory.isTokenCreator(token, user));
        assertFalse(factory.isTokenCreator(token, airlock));
    }

    function test_CreatorTrackingForNonexistentToken() public {
        address nonexistentToken = address(0x9999);
        assertFalse(factory.isTokenCreator(nonexistentToken, user));
        assertFalse(factory.isTokenCreator(nonexistentToken, airlock));
    }

    /* -------------------------------------------------------------------------- */
    /*                              Fuzz Testing                                */
    /* -------------------------------------------------------------------------- */

    function testFuzz_CreateWithDifferentSupplies(uint256 supply) public {
        vm.assume(supply > 0 && supply <= type(uint128).max); // Reasonable bounds

        bytes memory tokenData = _encodeTokenData(
            TOKEN_NAME, TOKEN_SYMBOL, YEARLY_MINT_CAP, VESTING_DURATION, new address[](0), new uint256[](0), TOKEN_URI
        );

        vm.prank(airlock, airlock);
        address token = factory.create(supply, user, owner, TEST_SALT, tokenData);

        HolographERC20 holographToken = HolographERC20(token);
        assertEq(holographToken.totalSupply(), supply);
        assertEq(holographToken.balanceOf(user), supply);
    }

    function testFuzz_CreateWithDifferentSalts(bytes32 salt) public {
        bytes memory tokenData = _encodeTokenData(
            TOKEN_NAME, TOKEN_SYMBOL, YEARLY_MINT_CAP, VESTING_DURATION, new address[](0), new uint256[](0), TOKEN_URI
        );

        vm.prank(airlock, airlock);
        address token = factory.create(INITIAL_SUPPLY, user, owner, salt, tokenData);

        assertTrue(factory.isDeployedToken(token));
        assertTrue(token != address(0));
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper Functions                             */
    /* -------------------------------------------------------------------------- */

    function _encodeTokenData(
        string memory name,
        string memory symbol,
        uint256 yearlyMintCap,
        uint256 vestingDuration,
        address[] memory recipients,
        uint256[] memory amounts,
        string memory tokenURI
    ) internal pure returns (bytes memory) {
        return abi.encode(name, symbol, yearlyMintCap, vestingDuration, recipients, amounts, tokenURI);
    }
}
