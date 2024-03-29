// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../src/Test.sol";

contract StdUtilsTest is Test {
  function testBound() public {
    assertEq(bound(5, 0, 4), 0);
    assertEq(bound(0, 69, 69), 69);
    assertEq(bound(0, 68, 69), 68);
    assertEq(bound(10, 150, 190), 174);
    assertEq(bound(300, 2800, 3200), 3107);
    assertEq(bound(9999, 1337, 6666), 4669);
  }

  function testBound_WithinRange() public {
    assertEq(bound(51, 50, 150), 51);
    assertEq(bound(51, 50, 150), bound(bound(51, 50, 150), 50, 150));
    assertEq(bound(149, 50, 150), 149);
    assertEq(bound(149, 50, 150), bound(bound(149, 50, 150), 50, 150));
  }

  function testBound_EdgeCoverage() public {
    assertEq(bound(0, 50, 150), 50);
    assertEq(bound(1, 50, 150), 51);
    assertEq(bound(2, 50, 150), 52);
    assertEq(bound(3, 50, 150), 53);
    assertEq(bound(type(uint256).max, 50, 150), 150);
    assertEq(bound(type(uint256).max - 1, 50, 150), 149);
    assertEq(bound(type(uint256).max - 2, 50, 150), 148);
    assertEq(bound(type(uint256).max - 3, 50, 150), 147);
  }

  function testBound_DistributionIsEven(uint256 min, uint256 size) public {
    size = (size % 100) + 1;
    min = bound(min, UINT256_MAX / 2, UINT256_MAX / 2 + size);
    uint256 max = min + size - 1;
    uint256 result;

    for (uint256 i = 1; i <= size * 4; ++i) {
      // x > max
      result = bound(max + i, min, max);
      assertEq(result, min + ((i - 1) % size));
      // x < min
      result = bound(min - i, min, max);
      assertEq(result, max - ((i - 1) % size));
    }
  }

  function testBound(uint256 num, uint256 min, uint256 max) public {
    if (min > max) (min, max) = (max, min);

    uint256 result = bound(num, min, max);

    assertGe(result, min);
    assertLe(result, max);
    assertEq(result, bound(result, min, max));
    if (num >= min && num <= max) assertEq(result, num);
  }

  function testBoundUint256Max() public {
    assertEq(bound(0, type(uint256).max - 1, type(uint256).max), type(uint256).max - 1);
    assertEq(bound(1, type(uint256).max - 1, type(uint256).max), type(uint256).max);
  }

  function testCannotBoundMaxLessThanMin() public {
    vm.expectRevert(bytes("StdUtils bound(uint256,uint256,uint256): Max is less than min."));
    bound(5, 100, 10);
  }

  function testCannotBoundMaxLessThanMin(uint256 num, uint256 min, uint256 max) public {
    vm.assume(min > max);
    vm.expectRevert(bytes("StdUtils bound(uint256,uint256,uint256): Max is less than min."));
    bound(num, min, max);
  }

  function testGenerateCreateAddress() external {
    address deployer = 0x6C9FC64A53c1b71FB3f9Af64d1ae3A4931A5f4E9;
    uint256 nonce = 14;
    address createAddress = computeCreateAddress(deployer, nonce);
    assertEq(createAddress, 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
  }

  function testGenerateCreate2Address() external {
    bytes32 salt = bytes32(uint256(31415));
    bytes32 initcodeHash = keccak256(abi.encode(0x6080));
    address deployer = 0x6C9FC64A53c1b71FB3f9Af64d1ae3A4931A5f4E9;
    address create2Address = computeCreate2Address(salt, initcodeHash, deployer);
    assertEq(create2Address, 0xB147a5d25748fda14b463EB04B111027C290f4d3);
  }

  function testAssumeNoPrecompilesL1(address addr) external {
    assumeNoPrecompiles(addr, stdChains.Mainnet.chainId);
    assertTrue(addr < address(1) || addr > address(9));
  }
}
