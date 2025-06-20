// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../lib/doppler/src/interfaces/ITokenFactory.sol";
import "./MockERC20.sol";

contract MockTokenFactory is ITokenFactory {
    function create(
        uint256 initialSupply,
        address,
        address,
        bytes32 salt,
        bytes calldata data
    ) external returns (address) {
        // Extract name and symbol from data
        (string memory name, string memory symbol) = abi.decode(data, (string, string));

        // Create a new token
        MockERC20 token = new MockERC20(name, symbol);
        token.mint(msg.sender, initialSupply);

        return address(token);
    }
}
