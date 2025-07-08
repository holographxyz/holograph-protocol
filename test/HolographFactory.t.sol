// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HolographFactory, CreateParams} from "src/HolographFactory.sol";

// Doppler interfaces
import {ITokenFactory} from "lib/doppler/src/interfaces/ITokenFactory.sol";
import {IGovernanceFactory} from "lib/doppler/src/interfaces/IGovernanceFactory.sol";
import {IPoolInitializer} from "lib/doppler/src/interfaces/IPoolInitializer.sol";
import {ILiquidityMigrator} from "lib/doppler/src/interfaces/ILiquidityMigrator.sol";

library DopplerAddrBook {
    struct DopplerAddrs {
        address airlock;
        address tokenFactory;
        address governanceFactory;
        address v4Initializer;
        address migrator;
        address poolManager;
        address dopplerDeployer;
    }

    function get(bool useMainnet) internal pure returns (DopplerAddrs memory) {
        return useMainnet ? getMainnet() : getTestnet();
    }

    function getTestnet() internal pure returns (DopplerAddrs memory) {
        // Updated addresses matching create-token.ts
        return
            DopplerAddrs({
                airlock: 0x3411306Ce66c9469BFF1535BA955503c4Bde1C6e,
                tokenFactory: 0xc69Ba223c617F7D936B3cf2012aa644815dBE9Ff,
                governanceFactory: 0x9dBFaaDC8c0cB2c34bA698DD9426555336992e20,
                v4Initializer: 0x8E891d249f1ECbfFA6143c03EB1B12843aef09d3,
                migrator: 0x04a898f3722c38F9Def707bD17DC78920EFA977C,
                poolManager: 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408,
                dopplerDeployer: 0x60a039e4aDD40ca95e0475c11e8A4182D06C9Aa0
            });
    }

    function getMainnet() internal pure returns (DopplerAddrs memory) {
        return
            DopplerAddrs({
                airlock: 0x660eAaEdEBc968f8f3694354FA8EC0b4c5Ba8D12,
                tokenFactory: 0xFAafdE6a5b658684cC5eb0C5c2c755B00A246F45,
                governanceFactory: 0xb4deE32EB70A5E55f3D2d861F49Fb3D79f7a14d9,
                v4Initializer: 0x77EbfBAE15AD200758E9E2E61597c0B07d731254,
                migrator: 0x5F3bA43D44375286296Cb85F1EA2EBfa25dde731,
                poolManager: 0x498581fF718922c3f8e6A244956aF099B2652b2b,
                dopplerDeployer: 0x5CadB034267751a364dDD4d321C99E07A307f915
            });
    }
}

/// @dev minimal stub for LayerZero
contract LZEndpointStub {
    event MessageSent(uint32 dstEid, bytes payload);

    function send(uint32 dstEid, bytes calldata payload, bytes calldata) external payable {
        emit MessageSent(dstEid, payload);
    }
}

/// @dev simple FeeRouter that just sums amounts
contract FeeRouterMock {
    uint256 public total;
    event FeeReceived(uint256 amount);

    function routeFeeETH() external payable {
        total += msg.value;
        emit FeeReceived(msg.value);
    }

    function receiveFee() external payable {
        total += msg.value;
        emit FeeReceived(msg.value);
    }

    receive() external payable {
        total += msg.value;
        emit FeeReceived(msg.value);
    }
}

contract HolographFactoryTest is Test {
    // Constants matching create-token.ts
    uint256 private constant INITIAL_SUPPLY = 100_000e18;
    uint256 private constant MIN_PROCEEDS = 100e18;
    uint256 private constant MAX_PROCEEDS = 10_000e18;
    uint256 private constant AUCTION_DURATION = 3 days;
    uint256 private constant EPOCH_LENGTH = 400;
    int24 private constant GAMMA = 800;
    int24 private constant START_TICK = 6_000;
    int24 private constant END_TICK = 60_000;
    uint24 private constant LP_FEE = 3000;
    int24 private constant TICK_SPACING = 8;
    
    // Hook flags for salt mining (matching create-token.ts)
    uint256 private constant BEFORE_INITIALIZE_FLAG = 1 << 13;
    uint256 private constant AFTER_INITIALIZE_FLAG = 1 << 12;
    uint256 private constant BEFORE_ADD_LIQUIDITY_FLAG = 1 << 11;
    uint256 private constant BEFORE_SWAP_FLAG = 1 << 7;
    uint256 private constant AFTER_SWAP_FLAG = 1 << 6;
    uint256 private constant BEFORE_DONATE_FLAG = 1 << 5;
    
    uint256 private constant REQUIRED_FLAGS = 
        BEFORE_INITIALIZE_FLAG |
        AFTER_INITIALIZE_FLAG |
        BEFORE_ADD_LIQUIDITY_FLAG |
        BEFORE_SWAP_FLAG |
        AFTER_SWAP_FLAG |
        BEFORE_DONATE_FLAG;
    
    uint256 private constant FLAG_MASK = 0x3fff;
    uint256 private constant MAX_SALT_ITERATIONS = 200_000;

    DopplerAddrBook.DopplerAddrs private doppler;
    HolographFactory private factory;
    FeeRouterMock private feeRouter;
    LZEndpointStub private lzEndpoint;
    address private creator = address(0xCAFE);

    function setUp() public {
        // Choose network based on MAINNET environment variable (defaults to testnet)
        bool useMainnet = vm.envOr("MAINNET", false);
        doppler = DopplerAddrBook.get(useMainnet);

        if (useMainnet) {
            vm.chainId(8453);
            vm.createSelectFork(vm.rpcUrl("base"));
            console.log("=== USING BASE MAINNET ===");
        } else {
            vm.chainId(84532);
            vm.createSelectFork(vm.rpcUrl("baseSepolia"));
            console.log("=== USING BASE SEPOLIA TESTNET ===");
        }

        console.log("Doppler addresses:");
        console.log("  Airlock: %s", doppler.airlock);
        console.log("  TokenFactory: %s", doppler.tokenFactory);
        console.log("  GovernanceFactory: %s", doppler.governanceFactory);
        console.log("  V4Initializer: %s", doppler.v4Initializer);
        console.log("  Migrator: %s", doppler.migrator);
        console.log("  PoolManager: %s", doppler.poolManager);
        console.log("  DopplerDeployer: %s", doppler.dopplerDeployer);

        lzEndpoint = new LZEndpointStub();
        feeRouter = new FeeRouterMock();
        factory = new HolographFactory(address(lzEndpoint), doppler.airlock, address(feeRouter));
        vm.deal(creator, 1 ether);
    }

    function computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address deployer) internal pure override returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            initCodeHash
        )))));
    }

    function mineValidSalt(
        bytes memory tokenFactoryData,
        bytes memory poolInitializerData,
        uint256 initialSupply,
        uint256 numTokensToSell,
        address numeraire
    ) internal view returns (bytes32) {
        console.log("Mining valid salt...");
        
        // Decode pool initializer data
        (
            uint256 minimumProceeds,
            uint256 maximumProceeds,
            uint256 startingTime,
            uint256 endingTime,
            int24 startingTick,
            int24 endingTick,
            uint256 epochLength,
            int24 gamma,
            bool isToken0,
            uint256 numPDSlugs,
            uint24 lpFee,
            int24 tickSpacing
        ) = abi.decode(
            poolInitializerData,
            (uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, uint24, int24)
        );
        
        // Prepare Doppler constructor arguments
        bytes memory dopplerConstructorArgs = abi.encode(
            doppler.poolManager,
            numTokensToSell,
            minimumProceeds,
            maximumProceeds,
            startingTime,
            endingTime,
            startingTick,
            endingTick,
            epochLength,
            gamma,
            isToken0,
            numPDSlugs,
            doppler.v4Initializer,
            lpFee
        );
        
        // Prepare token constructor arguments
        (
            string memory name,
            string memory symbol,
            uint256 yearlyMintCap,
            uint256 vestingDuration,
            address[] memory recipients,
            uint256[] memory amounts,
            string memory tokenURI
        ) = abi.decode(
            tokenFactoryData,
            (string, string, uint256, uint256, address[], uint256[], string)
        );
        
        bytes memory tokenConstructorArgs = abi.encode(
            name,
            symbol,
            initialSupply,
            doppler.airlock,
            doppler.airlock,
            yearlyMintCap,
            vestingDuration,
            recipients,
            amounts,
            tokenURI
        );
        
        // Get real bytecode from artifacts
        bytes memory dopplerBytecode = vm.getCode("lib/doppler/out/Doppler.sol/Doppler.json");
        bytes memory derc20Bytecode = vm.getCode("lib/doppler/out/DERC20.sol/DERC20.json");
        
        // Calculate init code hashes
        bytes32 dopplerInitHash = keccak256(abi.encodePacked(dopplerBytecode, dopplerConstructorArgs));
        bytes32 tokenInitHash = keccak256(abi.encodePacked(derc20Bytecode, tokenConstructorArgs));
        
        // Mine salt
        for (uint256 saltNum = 0; saltNum < MAX_SALT_ITERATIONS; saltNum++) {
            if (saltNum % 10000 == 0) {
                console.log("Mining progress: %s/%s", saltNum, MAX_SALT_ITERATIONS);
            }
            
            bytes32 salt = bytes32(saltNum);
            address hookAddress = computeCreate2Address(salt, dopplerInitHash, doppler.dopplerDeployer);
            address assetAddress = computeCreate2Address(salt, tokenInitHash, doppler.tokenFactory);
            
            // Check hook flags
            uint256 hookFlags = uint256(uint160(hookAddress)) & FLAG_MASK;
            if (hookFlags != REQUIRED_FLAGS) {
                continue;
            }
            
            // Check if hook address is available (should have no code)
            if (hookAddress.code.length > 0) {
                continue;
            }
            
            // Check token ordering
            uint256 assetBigInt = uint256(uint160(assetAddress));
            uint256 numeraireBigInt = uint256(uint160(numeraire));
            bool correctOrdering = isToken0 ? assetBigInt < numeraireBigInt : assetBigInt > numeraireBigInt;
            
            if (!correctOrdering) {
                continue;
            }
            
            console.log("Found valid salt: %s", saltNum);
            console.log("Hook address: %s", hookAddress);
            console.log("Asset address: %s", assetAddress);
            console.log("Hook flags: %s (required: %s)", hookFlags, REQUIRED_FLAGS);
            console.log("Token ordering: isToken0=%s, asset < numeraire: %s", isToken0, assetBigInt < numeraireBigInt);
            return salt;
        }
        
        revert("Could not find valid salt");
    }

    function test_tokenLaunch_withRealSaltMining() public {
        console.log("=== TESTING TOKEN LAUNCH WITH REAL SALT MINING ===");
        console.log("This test uses actual bytecode for proper salt mining");

        // 1. Prepare token factory data (matching create-token.ts)
        bytes memory tokenFactoryData = abi.encode(
            "Test Token", // name
            "TEST", // symbol
            uint256(0), // yearlyMintCap
            uint256(0), // vestingDuration
            new address[](0), // recipients
            new uint256[](0), // amounts
            "" // tokenURI
        );

        // 2. Prepare governance factory data (matching create-token.ts)
        bytes memory governanceData = abi.encode(
            "Test Token DAO", // name
            uint256(7200), // voting delay
            uint256(50400), // voting period
            uint256(0) // proposal threshold
        );

        // 3. Set auction timing with buffer (matching create-token.ts)
        uint256 auctionStart = block.timestamp + 600; // 10 minutes from now
        uint256 auctionEnd = auctionStart + AUCTION_DURATION;

        console.log("Auction timing:");
        console.log("  Start: %s", auctionStart);
        console.log("  End: %s", auctionEnd);
        console.log("  Duration: %s seconds", AUCTION_DURATION);

        // 4. Prepare pool initializer data (matching create-token.ts)
        bytes memory poolInitializerData = abi.encode(
            MIN_PROCEEDS, // minimumProceeds
            MAX_PROCEEDS, // maximumProceeds
            auctionStart, // startingTime
            auctionEnd, // endingTime
            START_TICK, // startingTick
            END_TICK, // endingTick
            EPOCH_LENGTH, // epochLength
            GAMMA, // gamma
            false, // isToken0
            uint256(8), // numPDSlugs
            LP_FEE, // lpFee
            TICK_SPACING // tickSpacing
        );

        // 5. Mine a valid salt using real bytecode
        bytes32 salt = mineValidSalt(
            tokenFactoryData,
            poolInitializerData,
            INITIAL_SUPPLY,
            INITIAL_SUPPLY,
            address(0) // numeraire (ETH)
        );

        console.log("Using mined salt: %s", uint256(salt));

        // 6. Assemble CreateParams (matching create-token.ts)
        CreateParams memory createParams;
        createParams.initialSupply = INITIAL_SUPPLY;
        createParams.numTokensToSell = INITIAL_SUPPLY;
        createParams.numeraire = address(0);
        createParams.tokenFactoryData = tokenFactoryData;
        createParams.governanceFactoryData = governanceData;
        createParams.poolInitializerData = poolInitializerData;
        createParams.liquidityMigratorData = "";
        createParams.integrator = address(0);
        createParams.salt = salt;

        // Use assembly to set interface fields to avoid type conflicts
        address tokenFactory = doppler.tokenFactory;
        address governanceFactory = doppler.governanceFactory;
        address poolInitializer = doppler.v4Initializer;
        address liquidityMigrator = doppler.migrator;

        assembly {
            mstore(add(createParams, 0x60), tokenFactory)
            mstore(add(createParams, 0xa0), governanceFactory)
            mstore(add(createParams, 0xe0), poolInitializer)
            mstore(add(createParams, 0x120), liquidityMigrator)
        }

        // 7. Execute token creation (should succeed with proper salt mining)
        console.log("=== EXECUTING TOKEN CREATION ===");
        vm.prank(creator);

        address tokenAddress = factory.createToken(createParams);

        console.log("Token creation successful!");
        console.log("Token address: %s", tokenAddress);
        
        // Verify the token was actually deployed
        assertTrue(tokenAddress != address(0), "Token address should not be zero");
        assertTrue(tokenAddress.code.length > 0, "Token should have deployed code");
        
        console.log("Test completed successfully - token deployed with real salt mining!");
    }

    function test_addressesAreCorrect() public {
        console.log("=== VERIFYING DOPPLER ADDRESSES ===");

        // Verify that all addresses have code deployed (they should be valid contracts)
        assertTrue(doppler.airlock.code.length > 0, "Airlock should have code");
        assertTrue(doppler.tokenFactory.code.length > 0, "TokenFactory should have code");
        assertTrue(doppler.governanceFactory.code.length > 0, "GovernanceFactory should have code");
        assertTrue(doppler.v4Initializer.code.length > 0, "V4Initializer should have code");
        assertTrue(doppler.migrator.code.length > 0, "Migrator should have code");
        assertTrue(doppler.poolManager.code.length > 0, "PoolManager should have code");
        assertTrue(doppler.dopplerDeployer.code.length > 0, "DopplerDeployer should have code");

        console.log("All Doppler addresses verified successfully");
    }

    function test_factoryDeployment() public {
        console.log("=== TESTING FACTORY DEPLOYMENT ===");

        // Verify factory was deployed correctly
        assertTrue(address(factory).code.length > 0, "Factory should have code");

        // Verify factory has correct airlock address
        // Note: This would require a getter function in HolographFactory
        console.log("Factory deployed successfully at: %s", address(factory));
        console.log("Factory deployment test completed");
    }
}
