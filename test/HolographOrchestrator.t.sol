// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HolographOrchestrator} from "src/HolographOrchestrator.sol";
import {ITokenFactory} from "src/interfaces/ITokenFactory.sol";
import {IPoolInitializer} from "src/interfaces/IPoolInitializer.sol";
import {ILiquidityMigrator} from "src/interfaces/ILiquidityMigrator.sol";
import {IGovernanceFactory} from "src/interfaces/IGovernanceFactory.sol";

import {Airlock as DopplerAirlock, CreateParams} from "lib/doppler/src/Airlock.sol";

import "doppler/test/shared/AirlockMiner.sol";

library DopplerAddrBook {
    struct DopplerAddrs {
        address airlock;
        address tokenFactory;
        address governanceFactory;
        address v4Initializer;
        address migrator;
        address poolManager;
    }

    function get() internal pure returns (DopplerAddrs memory) {
        return
            DopplerAddrs({
                poolManager: 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408,
                airlock: 0x881c18352182E1C918DBfc54539e744Dc90274a8,
                tokenFactory: 0xBdd732390Dbb0E8D755D1002211E967EF8b8B326,
                governanceFactory: 0x61e307223Cb5444B72Ea42992Da88B895589d0F3,
                v4Initializer: 0x20a7DB1f189B5592F756Bf41AD1E7165bD62963C,
                migrator: 0xBD1B28D7E61733A8983d924c704B1A09d897a870
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
    uint24 private constant DEFAULT_FEE = 0;
    int24 private constant DEFAULT_TICK_SPACING = 8;

    DopplerAddrBook.DopplerAddrs private doppler;
    HolographOrchestrator private orchestrator;
    FeeRouterMock private feeRouter;
    LZEndpointStub private lzEndpoint;
    address private creator = address(0xCAFE);

    function setUp() public {
        doppler = DopplerAddrBook.get();
        vm.createSelectFork(vm.rpcUrl("baseSepolia"));

        lzEndpoint = new LZEndpointStub();
        feeRouter = new FeeRouterMock();
        orchestrator = new HolographOrchestrator(address(lzEndpoint), doppler.airlock, address(feeRouter));
        orchestrator.setLaunchFee(LAUNCH_FEE);
        vm.deal(creator, 1 ether);
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

        // 3) poolInitializer data (Doppler V4Test)
        bytes memory poolInitializerData = abi.encode(
            uint160(0), // sqrtPriceX96 (ignored by miner)
            DEFAULT_MINIMUM_PROCEEDS,
            DEFAULT_MAXIMUM_PROCEEDS,
            block.timestamp,
            block.timestamp + 3 days,
            DEFAULT_START_TICK,
            DEFAULT_END_TICK,
            DEFAULT_EPOCH_LENGTH,
            DEFAULT_GAMMA,
            false, // isToken0
            8 // numPDSlugs
        );

        uint256 initialSupply = 1e23;
        uint256 numTokensToSell = 1e23;

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

        (bytes32 salt, address hook, address asset) = mineV4(params);
        console.log("hook: ", hook);
        console.log("asset: ", asset);
        console.log("salt: ");
        console.logBytes32(salt);

        // 4) assemble CreateParams
        CreateParams memory createParams = CreateParams({
            initialSupply: DEFAULT_NUM_TOKENS_TO_SELL,
            numTokensToSell: DEFAULT_NUM_TOKENS_TO_SELL,
            numeraire: address(0),
            tokenFactory: ITokenFactory(doppler.tokenFactory),
            tokenFactoryData: tokenFactoryData,
            governanceFactory: IGovernanceFactory(doppler.governanceFactory),
            governanceFactoryData: governanceData,
            poolInitializer: IPoolInitializer(doppler.v4Initializer),
            poolInitializerData: poolInitializerData,
            liquidityMigrator: ILiquidityMigrator(doppler.migrator),
            liquidityMigratorData: "",
            integrator: address(0),
            salt: salt
        });

        // Use the existing Airlock deployed on Base Sepolia
        DopplerAirlock airlock = DopplerAirlock(payable(doppler.airlock));

        // Now call create on the live Airlock
        airlock.create(createParams);

        // // 5) low-level call to see revert reason
        // bytes memory callData = abi.encodeWithSelector(orchestrator.createToken.selector, createParams);
        // vm.prank(creator);
        // (bool ok, bytes memory returndata) = address(orchestrator).call{value: LAUNCH_FEE}(callData);

        // console.log("createToken success? ", ok);
        // console.logBytes(returndata);

        // assertTrue(ok, "createToken reverted; see console above for selector/data");
    }
}
