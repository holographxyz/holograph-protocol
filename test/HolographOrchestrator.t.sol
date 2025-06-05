// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HolographOrchestrator, CreateParams} from "src/HolographOrchestrator.sol";
import {CreateParams} from "lib/doppler/src/Airlock.sol";

// Import additional v4-core dependencies not included in AirlockMiner.sol
import {TickMath} from "lib/doppler/lib/v4-core/src/libraries/TickMath.sol";
import {Hooks as HooksLib} from "lib/doppler/lib/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "lib/doppler/lib/v4-core/src/libraries/LPFeeLibrary.sol";
import {IHooks} from "lib/doppler/lib/v4-core/src/interfaces/IHooks.sol";

// Import AirlockMiner which includes Hooks, PoolManager, DERC20, Doppler, Airlock, and UniswapV4Initializer
// This also imports ITokenFactory, but we need to import the other interfaces separately
import "lib/doppler/test/shared/AirlockMiner.sol";
import {IGovernanceFactory} from "lib/doppler/src/interfaces/IGovernanceFactory.sol";
import {IPoolInitializer} from "lib/doppler/src/interfaces/IPoolInitializer.sol";
import {ILiquidityMigrator} from "lib/doppler/src/interfaces/ILiquidityMigrator.sol";
import {IPoolManager} from "lib/doppler/lib/v4-core/src/interfaces/IPoolManager.sol";

// Import DopplerDeployer specifically to avoid conflicts
import {DopplerDeployer} from "lib/doppler/src/UniswapV4Initializer.sol";

contract DopplerHookStub {
    fallback() external payable {}
}

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

    function get() internal pure returns (DopplerAddrs memory) {
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
}

contract V4InitializerStub {
    event Create(address poolOrHook, address asset, address numeraire);
    function deployer() external view returns (address) {
        return address(this);
    }
    function initialize(
        address asset,
        address numeraire,
        uint256 /*numTokensToSell*/,
        bytes32 /*salt*/,
        bytes calldata /*data*/
    ) external returns (address poolOrHook) {
        // deploy a minimal hook stub
        poolOrHook = address(new DopplerHookStub());
        emit Create(poolOrHook, asset, numeraire);
    }
    function exitLiquidity(address) external returns (uint160, address, uint128, uint128, address, uint128, uint128) {
        return (0, address(0), 0, 0, address(0), 0, 0);
    }
}

contract OrchestratorLaunchTest is Test {
    // ── constants ─────────────────────────────────────────────────────────
    uint256 private constant LAUNCH_FEE = 0.1 ether;
    uint256 private constant DEFAULT_NUM_TOKENS_TO_SELL = 100_000e18;
    uint256 private constant DEFAULT_MINIMUM_PROCEEDS = 100e18;
    uint256 private constant DEFAULT_MAXIMUM_PROCEEDS = 10_000e18;
    uint256 private constant DEFAULT_EPOCH_LENGTH = 400 seconds;
    int24 private constant DEFAULT_GAMMA = 800;
    int24 private constant DEFAULT_START_TICK = 6_000;
    int24 private constant DEFAULT_END_TICK = 60_000;
    uint24 private constant DEFAULT_FEE = 3000;
    int24 private constant DEFAULT_TICK_SPACING = 8;

    DopplerAddrBook.DopplerAddrs private doppler;
    HolographOrchestrator private orchestrator;
    FeeRouterMock private feeRouter;
    LZEndpointStub private lzEndpoint;
    address private creator = address(0xCAFE);

    function setUp() public {
        doppler = DopplerAddrBook.get();

        // Base mainnet has chain ID 8453
        vm.chainId(8453);
        // Use the fork URL from the command line
        vm.createSelectFork(vm.rpcUrl("base"));

        lzEndpoint = new LZEndpointStub();
        feeRouter = new FeeRouterMock();
        orchestrator = new HolographOrchestrator(address(lzEndpoint), doppler.airlock, address(feeRouter));
        orchestrator.setLaunchFee(LAUNCH_FEE);
        vm.deal(creator, 1 ether);

        bool useV4Stub = vm.envOr("USE_V4_STUB", false);
        if (useV4Stub) {
            // patch initializer itself to stub implementation eliminating internal PoolManager logic
            V4InitializerStub initStub = new V4InitializerStub();
            vm.etch(doppler.v4Initializer, address(initStub).code);
        }
    }

    function test_tokenLaunch_endToEnd() public {
        // 1) tokenFactory data
        bytes memory tokenFactoryData = abi.encode(
            "Test Token",
            "TEST",
            0,
            0,
            new address[](0),
            new uint256[](0),
            "TOKEN_URI"
        );

        // 2) governanceFactory data
        bytes memory governanceData = abi.encode("DAO", 7200, 50_400, 0);

        // Store current timestamp to ensure mining and deployment use the same values
        uint256 currentTime = block.timestamp;

        // 12-field blob expected by UniswapV4Initializer & DopplerDeployer
        bytes memory poolInitializerData = abi.encode(
            DEFAULT_MINIMUM_PROCEEDS,
            DEFAULT_MAXIMUM_PROCEEDS,
            currentTime, // Use stored timestamp
            currentTime + 3 days, // Use stored timestamp
            DEFAULT_START_TICK,
            DEFAULT_END_TICK,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_GAMMA,
            false, // isToken0
            8, // numPDSlugs
            3000,
            8
        );

        uint256 initialSupply = 1e23;
        uint256 numTokensToSell = 1e23;

        // Check if we're using the V4 stub mode
        bool useV4Stub = vm.envOr("USE_V4_STUB", false);

        bytes32 salt;
        address hook;
        address asset;

        if (useV4Stub) {
            // In stub mode, we don't need to mine for hook flags since the stub bypasses validation
            // Use a simple fixed salt
            salt = bytes32(uint256(1));

            // Calculate what the hook address would be with this salt for logging
            MineV4Params memory stubParams = MineV4Params({
                airlock: doppler.airlock,
                poolManager: doppler.poolManager,
                initialSupply: initialSupply,
                numTokensToSell: numTokensToSell,
                numeraire: address(0),
                tokenFactory: ITokenFactory(doppler.tokenFactory),
                tokenFactoryData: tokenFactoryData,
                poolInitializer: UniswapV4Initializer(doppler.v4Initializer),
                poolInitializerData: poolInitializerData
            });

            (, hook, asset) = mineV4WithFixedSalt(stubParams, 1);

            console.log("=== USING V4 STUB MODE ===");
            console.log("Using fixed salt: %s", uint256(salt));
            console.log("Calculated hook: %s", hook);
            console.log("Calculated asset: %s", asset);
        } else {
            // In real mode, mine for a valid salt with proper hook flags
            MineV4Params memory params = MineV4Params({
                airlock: doppler.airlock,
                poolManager: doppler.poolManager,
                initialSupply: initialSupply,
                numTokensToSell: numTokensToSell,
                numeraire: address(0),
                tokenFactory: ITokenFactory(doppler.tokenFactory),
                tokenFactoryData: tokenFactoryData,
                poolInitializer: UniswapV4Initializer(doppler.v4Initializer),
                poolInitializerData: poolInitializerData
            });

            // Use the doppler mineV4 function
            (salt, hook, asset) = mineV4(params);

            console.log("=== MINING RESULTS ===");
            console.log("Mined salt: %s", uint256(salt));
            console.log("Calculated hook: %s", hook);
            console.log("Calculated asset: %s", asset);
        }

        // 4) assemble CreateParams
        CreateParams memory createParams;
        createParams.initialSupply = DEFAULT_NUM_TOKENS_TO_SELL;
        createParams.numTokensToSell = DEFAULT_NUM_TOKENS_TO_SELL;
        createParams.numeraire = address(0);
        createParams.tokenFactory = ITokenFactory(doppler.tokenFactory);
        createParams.tokenFactoryData = tokenFactoryData;
        createParams.governanceFactoryData = governanceData;
        createParams.poolInitializerData = poolInitializerData;
        createParams.liquidityMigratorData = "";
        createParams.integrator = address(0);

        // DEBUG: Check salt before setting it
        console.log("=== SETTING CREATEPARAMS SALT ===");
        console.log("Salt from mining (bytes32): ");
        console.logBytes32(salt);
        console.log("Salt from mining (uint256): %s", uint256(salt));

        createParams.salt = salt;

        // Use inline assembly for the interface fields that have type conflicts
        //
        // WHY ASSEMBLY IS NEEDED:
        // The CreateParams struct expects interface types imported from doppler's internal "src/interfaces/" path,
        // but we import the same interfaces from "lib/doppler/src/interfaces/". Even though these are identical files,
        // Solidity's type system treats them as incompatible types. Assembly bypasses this type checking by directly
        // manipulating memory addresses.
        //
        // CREATEPARAMS STRUCT MEMORY LAYOUT:
        // Each field occupies 32 bytes (0x20) in memory, regardless of actual size
        // 0x00: initialSupply        (uint256)       ✓ Set normally
        // 0x20: numTokensToSell      (uint256)       ✓ Set normally
        // 0x40: numeraire            (address)       ✓ Set normally
        // 0x60: tokenFactory         (ITokenFactory) ✓ Set normally (no conflict)
        // 0x80: tokenFactoryData     (bytes)         ✓ Set normally
        // 0xA0: governanceFactory    (IGovernanceFactory) ❌ TYPE CONFLICT → Use assembly
        // 0xC0: governanceFactoryData(bytes)         ✓ Set normally
        // 0xE0: poolInitializer      (IPoolInitializer)   ❌ TYPE CONFLICT → Use assembly
        // 0x100: poolInitializerData (bytes)         ✓ Set normally
        // 0x120: liquidityMigrator   (ILiquidityMigrator) ❌ TYPE CONFLICT → Use assembly
        // 0x140: liquidityMigratorData(bytes)        ✓ Set normally
        // 0x160: integrator          (address)       ✓ Set normally
        // 0x180: salt                (bytes32)       ✓ Set normally
        address govFactory = doppler.governanceFactory;
        address poolInit = doppler.v4Initializer;
        address liquidityMig = doppler.migrator;

        assembly {
            // mstore(memoryLocation, value) stores 32 bytes at the specified memory location

            // Store governanceFactory at offset 0xA0 (160 decimal)
            // Calculation: 0xA0 = 5 fields × 32 bytes = field #6 (governanceFactory)
            mstore(add(createParams, 0xa0), govFactory)

            // Store poolInitializer at offset 0xE0 (224 decimal)
            // Calculation: 0xE0 = 7 fields × 32 bytes = field #8 (poolInitializer)
            mstore(add(createParams, 0xe0), poolInit)

            // Store liquidityMigrator at offset 0x120 (288 decimal)
            // Calculation: 0x120 = 9 fields × 32 bytes = field #10 (liquidityMigrator)
            mstore(add(createParams, 0x120), liquidityMig)
        }

        // 5) low-level call to see revert reason
        bytes memory callData = abi.encodeWithSelector(orchestrator.createToken.selector, createParams);
        vm.prank(creator);
        (bool ok, bytes memory returndata) = address(orchestrator).call{value: LAUNCH_FEE}(callData);

        console.log("createToken success? ", ok);
        console.logBytes(returndata);

        assertTrue(ok, "createToken reverted; see console above for selector/data");
    }

    function mineV4WithFixedSalt(
        MineV4Params memory params,
        uint256 fixedSalt
    ) internal view returns (bytes32 salt, address hook, address asset) {
        // Decode the same way as mining function
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
            int24 tickSpacing // This parameter exists in the data but is NOT used in Doppler constructor
        ) = abi.decode(
                params.poolInitializerData,
                (uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, uint24, int24)
            );

        // Calculate the same way as mining but with a fixed salt
        bytes32 dopplerInitHash = keccak256(
            abi.encodePacked(
                type(Doppler).creationCode,
                abi.encode(
                    params.poolManager,
                    params.numTokensToSell,
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
                    address(params.poolInitializer), // This is msg.sender in DopplerDeployer.deploy
                    lpFee
                )
            )
        );

        address dopplerDeployer = 0x5CadB034267751a364dDD4d321C99E07A307f915;

        hook = computeCreate2Address(bytes32(fixedSalt), dopplerInitHash, dopplerDeployer);

        // Calculate asset address too - decode tokenFactoryData
        bytes32 tokenInitHash = keccak256(
            abi.encodePacked(
                type(DERC20).creationCode,
                abi.encode(
                    params.initialSupply, // initialSupply
                    params.airlock, // recipient (airlock)
                    params.airlock, // owner (airlock)
                    params.tokenFactoryData // data (encoded params for DERC20)
                )
            )
        );

        asset = computeCreate2Address(bytes32(fixedSalt), tokenInitHash, address(params.tokenFactory));

        salt = bytes32(fixedSalt);
    }

    function test_debugCreate2() public {
        // Set up the same parameters as the main test
        uint256 timestamp = block.timestamp;

        // Decode the pool initializer data to get the exact parameters
        bytes memory poolInitializerData = abi.encode(
            100000000000000000000000, // minimumProceeds
            10000000000000000000000000, // maximumProceeds
            timestamp + 3600, // startingTime
            timestamp + 7200, // endingTime
            6000, // startingTick
            -6000, // endingTick
            1800, // epochLength
            50, // gamma
            true, // isToken0
            3, // numPDSlugs
            3000, // lpFee
            8 // tickSpacing
        );

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

        // Calculate the exact same way as mining
        address poolManager = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        uint256 numTokensToSell = 100000000000000000000000;
        address poolInitializer = 0x77EbfBAE15AD200758E9E2E61597c0B07d731254;

        bytes32 dopplerInitHash = keccak256(
            abi.encodePacked(
                type(Doppler).creationCode,
                abi.encode(
                    poolManager,
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
                    poolInitializer, // This is msg.sender in DopplerDeployer.deploy
                    lpFee
                )
            )
        );

        address dopplerDeployer = 0x5CadB034267751a364dDD4d321C99E07A307f915;
        uint256 salt = 1;

        address predictedHook = computeCreate2Address(bytes32(salt), dopplerInitHash, dopplerDeployer);

        console.log("=== CREATE2 DEBUG TEST ===");
        console.log("Deployer: %s", dopplerDeployer);
        console.log("Salt: %s", salt);
        console.log("Init hash:");
        console.logBytes32(dopplerInitHash);
        console.log("Predicted hook: %s", predictedHook);

        // Now try to deploy and see what we actually get
        vm.prank(poolInitializer);
        try DopplerDeployer(dopplerDeployer).deploy(numTokensToSell, bytes32(salt), poolInitializerData) returns (
            Doppler actualHook
        ) {
            console.log("Actual hook: %s", address(actualHook));
            console.log("Addresses match: %s", address(actualHook) == predictedHook);
        } catch (bytes memory error) {
            console.log("Deployment failed with error:");
            console.logBytes(error);
            // Try to extract the address from the error
            if (error.length >= 36) {
                address failedAddress;
                assembly {
                    failedAddress := mload(add(error, 36))
                }
                console.log("Failed at address: %s", failedAddress);
                console.log("Predicted vs failed: %s vs %s", predictedHook, failedAddress);
            }
        }
    }

    function test_compareMiningVsDeployment() public {
        console.log("=== MINING vs DEPLOYMENT PARAMETER COMPARISON ===");

        // Use the EXACT same parameters as the actual failing test
        uint256 numTokensToSell = 100_000e18;
        uint256 minimumProceeds = 100e18;
        uint256 maximumProceeds = 10_000e18;
        // Use the actual timestamps from the failing test
        uint256 startingTime = 1748974036;
        uint256 endingTime = 1749233236;
        int24 startingTick = 6000;
        int24 endingTick = 60000;
        uint256 epochLength = 400;
        int24 gamma = 800;
        bool isToken0 = false;
        uint256 numPDSlugs = 8;
        uint24 lpFee = 3000;

        // Use the actual PoolManager address from our test environment
        address testPoolManager = address(0x498581fF718922c3f8e6A244956aF099B2652b2b);

        // MINING CALCULATION
        console.log("=== MINING PARAMETERS ===");

        // In mining, we use the UniswapV4Initializer as the initializer
        address miningInitializer = address(0x77EbfBAE15AD200758E9E2E61597c0B07d731254);
        console.log("Mining initializer: %s", miningInitializer);

        bytes32 miningInitHash = keccak256(
            abi.encodePacked(
                type(Doppler).creationCode,
                abi.encode(
                    testPoolManager,
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
                    miningInitializer,
                    lpFee
                )
            )
        );

        address miningDeployer = address(0x5CadB034267751a364dDD4d321C99E07A307f915);

        // Test salt 1 which failed in the actual test
        bytes32 testSalt = bytes32(uint256(1));
        address miningPredicted = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), miningDeployer, testSalt, miningInitHash))))
        );

        // Also test salt 27142 which was mined successfully
        bytes32 minedSalt = bytes32(uint256(27142));
        address minedPredicted = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), miningDeployer, minedSalt, miningInitHash))))
        );

        console.log("Mining predicted for salt 1: %s", miningPredicted);
        console.log("Mining predicted for salt 27142: %s", minedPredicted);
        console.log("Mining init hash:");
        console.logBytes32(miningInitHash);
        console.log("Expected init hash: 0xe28cd72803de5555f19f6eb167a37010ae25a495e3d5d395d60a10ccf80e77f9");
        console.log(
            "Hashes match: %s",
            miningInitHash == 0xe28cd72803de5555f19f6eb167a37010ae25a495e3d5d395d60a10ccf80e77f9
        );

        // Check flags for both salts
        uint256 salt1Flags = uint256(uint160(miningPredicted)) & 0xFFFF;
        uint256 salt27142Flags = uint256(uint160(minedPredicted)) & 0xFFFF;
        uint256 requiredFlags = 0x38e0;

        console.log("Salt 1 flags: 0x%s", salt1Flags);
        console.log("Salt 27142 flags: 0x%s", salt27142Flags);
        console.log("Required flags: 0x38e0");
        console.log("Salt 1 has required flags: %s", (salt1Flags & requiredFlags) == requiredFlags);
        console.log("Salt 27142 has required flags: %s", (salt27142Flags & requiredFlags) == requiredFlags);

        // From the actual test, salt 1 predicted: 0x96742bE36e2c67D4703eEec8339F50d210d16119
        console.log("Expected salt 1 from test: 0x96742bE36e2c67D4703eEec8339F50d210d16119");
        console.log("Our salt 1 calculation matches: %s vs %s", miningPredicted, minedPredicted);

        // From the actual test, salt 27142 predicted: 0xaBD20F4F49E603592E55f6F311B14138A57Fb8e0
        console.log("Expected salt 27142 from test: 0xaBD20F4F49E603592E55f6F311B14138A57Fb8e0");
        console.log("Our salt 27142 calculation matches: %s vs %s", minedPredicted, minedPredicted);
    }

    function test_directDopplerDeployment() public {
        console.log("=== DIRECT DOPPLER DEPLOYMENT TEST ===");

        // Use the EXACT same timestamp from the failing test run
        // From the logs, we can see: startingTime: 1748975724, endingTime: 1749234924
        uint256 currentTime = 1748975724; // Use the exact timestamp from the failing test
        bytes memory poolInitializerData = abi.encode(
            DEFAULT_MINIMUM_PROCEEDS,
            DEFAULT_MAXIMUM_PROCEEDS,
            currentTime,
            1749234924, // Use exact endingTime from logs
            DEFAULT_START_TICK,
            DEFAULT_END_TICK,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_GAMMA,
            false, // isToken0
            8, // numPDSlugs
            3000,
            8
        );

        uint256 numTokensToSell = DEFAULT_NUM_TOKENS_TO_SELL;

        // Use the salt that we mined successfully: 4907 (0x132b)
        bytes32 testSalt = bytes32(uint256(4907));

        console.log("Using salt: %s", uint256(testSalt));
        console.log("Using numTokensToSell: %s", numTokensToSell);
        console.log("Using startingTime: %s", currentTime);
        console.log("Using endingTime: %s", uint256(1749234924));

        // Try to call DopplerDeployer directly
        address dopplerDeployer = doppler.dopplerDeployer;
        console.log("DopplerDeployer address: %s", dopplerDeployer);

        // Calculate what we expect with the exact same parameters
        console.log("=== DEBUGGING PARAMETER DIFFERENCES ===");
        console.log("Our doppler.poolManager: %s", doppler.poolManager);

        // Check what the DopplerDeployer actually has as poolManager
        address actualPoolManager = address(DopplerDeployer(dopplerDeployer).poolManager());
        console.log("DopplerDeployer.poolManager(): %s", actualPoolManager);
        console.log("PoolManager addresses match: %s", doppler.poolManager == actualPoolManager);

        bytes32 expectedInitHash = keccak256(
            abi.encodePacked(
                type(Doppler).creationCode,
                abi.encode(
                    actualPoolManager, // Use the ACTUAL poolManager from DopplerDeployer
                    numTokensToSell,
                    DEFAULT_MINIMUM_PROCEEDS,
                    DEFAULT_MAXIMUM_PROCEEDS,
                    currentTime,
                    1749234924, // Use exact endingTime from logs
                    DEFAULT_START_TICK,
                    DEFAULT_END_TICK,
                    DEFAULT_EPOCH_LENGTH,
                    DEFAULT_GAMMA,
                    false, // isToken0
                    8, // numPDSlugs
                    doppler.v4Initializer, // msg.sender in deploy
                    3000 // lpFee
                )
            )
        );

        console.log("Our calculated init hash:");
        console.logBytes32(expectedInitHash);
        console.log("Expected init hash from logs: 0xf5b588066b3a02fb2c3c133642d50cdd6d90c2c784ab7bfe6ea29429a73a7a9e");
        console.log(
            "Init hashes match: %s",
            expectedInitHash == 0xf5b588066b3a02fb2c3c133642d50cdd6d90c2c784ab7bfe6ea29429a73a7a9e
        );

        address expectedHook = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), dopplerDeployer, testSalt, expectedInitHash))))
        );

        console.log("Our calculated hook: %s", expectedHook);

        // Manual CREATE2 verification
        console.log("=== MANUAL CREATE2 VERIFICATION ===");
        console.log("Deployer: %s", dopplerDeployer);
        console.log("Salt: %s", uint256(testSalt));
        console.log("Init hash:");
        console.logBytes32(expectedInitHash);

        bytes32 create2Hash = keccak256(abi.encodePacked(bytes1(0xff), dopplerDeployer, testSalt, expectedInitHash));
        console.log("CREATE2 hash:");
        console.logBytes32(create2Hash);

        address manualHook = address(uint160(uint256(create2Hash)));
        console.log("Manual CREATE2 result: %s", manualHook);
        console.log("Manual matches calculated: %s", manualHook == expectedHook);

        // Call as if we're the UniswapV4Initializer
        vm.prank(doppler.v4Initializer);
        try DopplerDeployer(dopplerDeployer).deploy(numTokensToSell, testSalt, poolInitializerData) returns (
            Doppler actualDoppler
        ) {
            console.log("SUCCESS! Deployed Doppler at: %s", address(actualDoppler));
            console.log("Calculation matches deployment: %s", address(actualDoppler) == expectedHook);

            // Check if this address has the right flags
            uint256 hookFlags = uint256(uint160(address(actualDoppler))) & 0xFFFF;
            uint256 requiredFlags = 0x38e0;
            console.log("Deployed hook flags: 0x%s", hookFlags);
            console.log("Required flags: 0x38e0");
            console.log("Has required flags: %s", (hookFlags & requiredFlags) == requiredFlags);
        } catch (bytes memory error) {
            console.log("FAILED to deploy Doppler directly");
            console.logBytes(error);

            // Try to extract the hook address from the error
            if (error.length >= 36) {
                address failedAddress;
                assembly {
                    failedAddress := mload(add(error, 36))
                }
                console.log("Failed at hook address: %s", failedAddress);
                console.log("Failed hook matches calculation: %s", failedAddress == expectedHook);
            }
        }
    }

    function test_withOwnDopplerDeployer() public {
        console.log("=== TESTING WITH OUR OWN DOPPLER DEPLOYER ===");

        // Deploy our own DopplerDeployer
        DopplerDeployer ourDeployer = new DopplerDeployer(PoolManager(doppler.poolManager));
        console.log("Our deployed DopplerDeployer: %s", address(ourDeployer));

        // Use exact same parameters as failing test
        uint256 currentTime = 1748975724;
        bytes memory poolInitializerData = abi.encode(
            DEFAULT_MINIMUM_PROCEEDS,
            DEFAULT_MAXIMUM_PROCEEDS,
            currentTime,
            1749234924,
            DEFAULT_START_TICK,
            DEFAULT_END_TICK,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_GAMMA,
            false, // isToken0
            8, // numPDSlugs
            3000,
            8
        );

        uint256 numTokensToSell = DEFAULT_NUM_TOKENS_TO_SELL;
        bytes32 testSalt = bytes32(uint256(4907));

        // Calculate expected address with our deployer
        bytes32 expectedInitHash = keccak256(
            abi.encodePacked(
                type(Doppler).creationCode,
                abi.encode(
                    doppler.poolManager,
                    numTokensToSell,
                    DEFAULT_MINIMUM_PROCEEDS,
                    DEFAULT_MAXIMUM_PROCEEDS,
                    currentTime,
                    1749234924,
                    DEFAULT_START_TICK,
                    DEFAULT_END_TICK,
                    DEFAULT_EPOCH_LENGTH,
                    DEFAULT_GAMMA,
                    false, // isToken0
                    8, // numPDSlugs
                    address(this), // msg.sender will be this test contract
                    3000 // lpFee
                )
            )
        );

        address expectedHook = address(
            uint160(
                uint256(keccak256(abi.encodePacked(bytes1(0xff), address(ourDeployer), testSalt, expectedInitHash)))
            )
        );

        console.log("Expected hook with our deployer: %s", expectedHook);

        // Try deployment with our deployer
        try ourDeployer.deploy(numTokensToSell, testSalt, poolInitializerData) returns (Doppler actualDoppler) {
            console.log("SUCCESS! Our deployer worked: %s", address(actualDoppler));
            console.log("Address matches prediction: %s", address(actualDoppler) == expectedHook);

            // Check flags
            uint256 hookFlags = uint256(uint160(address(actualDoppler))) & 0xFFFF;
            uint256 requiredFlags = 0x38e0;
            console.log("Hook flags: 0x%s", hookFlags);
            console.log("Has required flags: %s", (hookFlags & requiredFlags) == requiredFlags);
        } catch (bytes memory error) {
            console.log("Our deployer also failed:");
            console.logBytes(error);
        }
    }
}
