// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HolographOrchestrator} from "src/HolographOrchestrator.sol";
import {ITokenFactory} from "src/interfaces/ITokenFactory.sol";
import {IPoolInitializer} from "src/interfaces/IPoolInitializer.sol";
import {ILiquidityMigrator} from "src/interfaces/ILiquidityMigrator.sol";
import {IGovernanceFactory} from "src/interfaces/IGovernanceFactory.sol";
import {Hooks} from "@v4-core/libraries/Hooks.sol";
import {PoolManager} from "@v4-core/PoolManager.sol";
import {ITokenFactory} from "src/interfaces/ITokenFactory.sol";
import {UniswapV4Initializer} from "doppler/src/UniswapV4Initializer.sol";
import {DERC20} from "doppler/src/DERC20.sol";
import {Doppler} from "doppler/src/Doppler.sol";
import {Airlock} from "doppler/src/Airlock.sol";
import {UniswapV4Initializer} from "doppler/src/UniswapV4Initializer.sol";

import {Airlock as DopplerAirlock, CreateParams} from "lib/doppler/src/Airlock.sol";

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
            // DopplerAddrs({
            //     airlock: 0x0d2f38d807bfAd5C18e430516e10ab560D300caF,
            //     tokenFactory: 0x4B0EC16Eb40318Ca5A4346f20F04A2285C19675B,
            //     governanceFactory: 0x65dE470Da664A5be139A5D812bE5FDa0d76CC951,
            //     v4Initializer: 0xA36715dA46Ddf4A769f3290f49AF58bF8132ED8E,
            //     migrator: 0xC541FBddfEEf798E50d257495D08efe00329109A,
            //     poolManager: 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
            // });
            DopplerAddrs({
                poolManager: 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408,
                airlock: 0x881c18352182E1C918DBfc54539e744Dc90274a8,
                tokenFactory: 0xBdd732390Dbb0E8D755D1002211E967EF8b8B326,
                dopplerDeployer: 0x3BEF7AE36503228891081e357bDB49B8F7627A4f,
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
    uint24 private constant DEFAULT_FEE = 3000;
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

        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(DEFAULT_START_TICK);

        // full initializer data for UniswapV4Initializer (includes fee & tickSpacing)
        bytes memory poolInitializerData = abi.encode(
            DEFAULT_MINIMUM_PROCEEDS,
            DEFAULT_MAXIMUM_PROCEEDS,
            block.timestamp,
            block.timestamp + 3 days,
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

        MineV4Params memory params = MineV4Params({
            airlock: doppler.airlock,
            poolManager: doppler.poolManager,
            initialSupply: initialSupply,
            numTokensToSell: numTokensToSell,
            numeraire: address(0),
            tokenFactory: ITokenFactory(doppler.tokenFactory),
            tokenFactoryData: tokenFactoryData,
            poolInitializer: UniswapV4Initializer(doppler.v4Initializer),
            poolInitializerData: poolInitializerDataMiner
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

        DopplerAirlock airlock = DopplerAirlock(payable(doppler.airlock));

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

// mask to slice out the bottom 14 bit of the address
uint160 constant FLAG_MASK = 0x3FFF;

// Maximum number of iterations to find a salt, avoid infinite loops
uint256 constant MAX_LOOP = 100_000;

uint160 constant flags = uint160(
    Hooks.BEFORE_INITIALIZE_FLAG |
        Hooks.AFTER_INITIALIZE_FLAG |
        Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
        Hooks.BEFORE_SWAP_FLAG |
        Hooks.AFTER_SWAP_FLAG |
        Hooks.BEFORE_DONATE_FLAG
);

struct MineV4Params {
    address airlock;
    address poolManager;
    uint256 initialSupply;
    uint256 numTokensToSell;
    address numeraire;
    ITokenFactory tokenFactory;
    bytes tokenFactoryData;
    UniswapV4Initializer poolInitializer;
    bytes poolInitializerData;
}

function mineV4(MineV4Params memory params) view returns (bytes32, address, address) {
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
            params.poolInitializerData,
            (uint256, uint256, uint256, uint256, int24, int24, uint256, int24, bool, uint256, uint24, int24)
        );

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
                params.poolInitializer,
                lpFee
            )
        )
    );

    (
        string memory name,
        string memory symbol,
        uint256 yearlyMintCap,
        uint256 vestingDuration,
        address[] memory recipients,
        uint256[] memory amounts,
        string memory tokenURI
    ) = abi.decode(params.tokenFactoryData, (string, string, uint256, uint256, address[], uint256[], string));

    bytes32 tokenInitHash = keccak256(
        abi.encodePacked(
            type(DERC20).creationCode,
            abi.encode(
                name,
                symbol,
                params.initialSupply,
                params.airlock,
                params.airlock,
                yearlyMintCap,
                vestingDuration,
                recipients,
                amounts,
                tokenURI
            )
        )
    );

    console.log("deployer: ", address(params.poolInitializer.deployer()));

    for (uint256 salt; salt < 200_000; ++salt) {
        address hook = computeCreate2Address(
            bytes32(salt),
            dopplerInitHash,
            address(params.poolInitializer.deployer())
        );
        address asset = computeCreate2Address(bytes32(salt), tokenInitHash, address(params.tokenFactory));

        if (
            uint160(hook) & FLAG_MASK == flags &&
            hook.code.length == 0 &&
            ((isToken0 && asset < params.numeraire) || (!isToken0 && asset > params.numeraire))
        ) {
            console.log("Found salt: %s", salt);
            return (bytes32(salt), hook, asset);
        }
    }

    revert("AirlockMiner: could not find salt");
}

function computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address deployer) pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
}
