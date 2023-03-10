// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Test} from "forge-std/Test.sol";
import {IERC721AUpgradeable} from "../../contracts/old_drops/interfaces/IERC721AUpgradeable.sol";

import {IHolographERC721Drop} from "../../contracts/old_drops/interfaces/IHolographERC721Drop.sol";
import {HolographERC721Drop} from "../../contracts/old_drops/HolographERC721Drop.sol";
import {HolographFeeManager} from "../../contracts/old_drops/HolographFeeManager.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {MockUser} from "./utils/MockUser.sol";
import {IMetadataRenderer} from "../../contracts/drops/interface/IMetadataRenderer.sol";
import {HolographERC721DropProxy} from "../../contracts/old_drops/HolographERC721DropProxy.sol";

contract HolographERC721DropTest is Test {
  HolographERC721Drop holographNFTBase;
  MockUser mockUser;
  DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();
  HolographFeeManager public feeManager;
  address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
  address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS = payable(address(0x21303));
  address payable public constant HOLOGRAPH_TREASURY_ADDRESS = payable(address(0x999));
  address public constant mediaContract = address(0x123456);

  function setUp() public {}
}