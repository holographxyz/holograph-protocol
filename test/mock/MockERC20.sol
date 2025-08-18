// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // Support ERC20Burnable-style burn from msg.sender
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /// @notice Override transfer to allow transfers to address(0) for burning
    function transfer(address to, uint256 value) public override returns (bool) {
        if (to == address(0)) {
            // Burn tokens by reducing total supply
            _burn(_msgSender(), value);
            return true;
        }
        return super.transfer(to, value);
    }

    /// @notice Override transferFrom to allow transfers to address(0) for burning
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (to == address(0)) {
            // Burn tokens by reducing total supply
            address spender = _msgSender();
            _spendAllowance(from, spender, value);
            _burn(from, value);
            return true;
        }
        return super.transferFrom(from, to, value);
    }
}
