// SPDX-License-Identifier: UNLICENSED
/*

  ,,,,,,,,,,,
 [ HOLOGRAPH ]
  '''''''''''
  _____________________________________________________________
 |                                                             |
 |                            / ^ \                            |
 |                            ~~*~~            .               |
 |                         [ '<>:<>' ]         |=>             |
 |               __           _/"\_           _|               |
 |             .:[]:.          """          .:[]:.             |
 |           .'  []  '.        \_/        .'  []  '.           |
 |         .'|   []   |'.               .'|   []   |'.         |
 |       .'  |   []   |  '.           .'  |   []   |  '.       |
 |     .'|   |   []   |   |'.       .'|   |   []   |   |'.     |
 |   .'  |   |   []   |   |  '.   .'  |   |   []   |   |  '.   |
 |.:'|   |   |   []   |   |   |':'|   |   |   []   |   |   |':.|
 |___|___|___|___[]___|___|___|___|___|___|___[]___|___|___|___|
 |XxXxXxXxXxXxXxX[]XxXxXxXxXxXxXxXxXxXxXxXxXxX[]XxXxXxXxXxXxXxX|
 |^^^^^^^^^^^^^^^[]^^^^^^^^^^^^^^^^^^^^^^^^^^^[]^^^^^^^^^^^^^^^|
 |               []                           []               |
 |               []                           []               |
 |    ,          []     ,        ,'      *    []               |
 |~~~~~^~~~~~~~~/##\~~~^~~~~~~~~^^~~~~~~~~^~~/##\~~~~~~~^~~~~~~|
 |_____________________________________________________________|

             - one bridge, infinite possibilities -


 ***************************************************************

 DISCLAIMER: U.S Patent Pending

 LICENSE: Holograph Limited Public License (H-LPL)

 https://holograph.xyz/licenses/h-lpl/1.0.0

 This license governs use of the accompanying software. If you
 use the software, you accept this license. If you do not accept
 the license, you are not permitted to use the software.

 1. Definitions

 The terms "reproduce," "reproduction," "derivative works," and
 "distribution" have the same meaning here as under U.S.
 copyright law. A "contribution" is the original software, or
 any additions or changes to the software. A "contributor" is
 any person that distributes its contribution under this
 license. "Licensed patents" are a contributor’s patent claims
 that read directly on its contribution.

 2. Grant of Rights

 A) Copyright Grant- Subject to the terms of this license,
 including the license conditions and limitations in sections 3
 and 4, each contributor grants you a non-exclusive, worldwide,
 royalty-free copyright license to reproduce its contribution,
 prepare derivative works of its contribution, and distribute
 its contribution or any derivative works that you create.
 B) Patent Grant- Subject to the terms of this license,
 including the license conditions and limitations in section 3,
 each contributor grants you a non-exclusive, worldwide,
 royalty-free license under its licensed patents to make, have
 made, use, sell, offer for sale, import, and/or otherwise
 dispose of its contribution in the software or derivative works
 of the contribution in the software.

 3. Conditions and Limitations

 A) No Trademark License- This license does not grant you rights
 to use any contributors’ name, logo, or trademarks.
 B) If you bring a patent claim against any contributor over
 patents that you claim are infringed by the software, your
 patent license from such contributor is terminated with
 immediate effect.
 C) If you distribute any portion of the software, you must
 retain all copyright, patent, trademark, and attribution
 notices that are present in the software.
 D) If you distribute any portion of the software in source code
 form, you may do so only under this license by including a
 complete copy of this license with your distribution. If you
 distribute any portion of the software in compiled or object
 code form, you may only do so under a license that complies
 with this license.
 E) The software is licensed “as-is.” You bear all risks of
 using it. The contributors give no express warranties,
 guarantees, or conditions. You may have additional consumer
 rights under your local laws which this license cannot change.
 To the extent permitted under your local laws, the contributors
 exclude all implied warranties, including those of
 merchantability, fitness for a particular purpose and
 non-infringement.

 4. (F) Platform Limitation- The licenses granted in sections
 2.A & 2.B extend only to the software or derivative works that
 you create that run on a Holograph system product.

 ***************************************************************

*/

pragma solidity 0.8.11;

import "./abstract/Admin.sol";
import "./abstract/EIP712.sol";
import "./abstract/Initializable.sol";
import "./abstract/Owner.sol";

import "./interface/ERC20.sol";
import "./interface/ERC20Burnable.sol";
import "./interface/ERC20Metadata.sol";
import "./interface/ERC20Permit.sol";
import "./interface/ERC20Receiver.sol";
import "./interface/ERC20Safer.sol";
import "./interface/ERC165.sol";
import "./interface/IHolograph.sol";
import "./interface/IHolographer.sol";
import "./interface/IHolographRegistry.sol";
import "./interface/IInitializable.sol";

import "./library/Address.sol";
import "./library/Base64.sol";
import "./library/Booleans.sol";
import "./library/Counters.sol";
import "./library/ECDSA.sol";
import "./library/Strings.sol";

/**
 * @title Holograph Bridgeable ERC-20 Token
 * @author CXIP-Labs
 * @notice A smart contract for minting and managing Holograph Bridgeable ERC20 Tokens.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
contract HolographERC20 is Admin, Owner, Initializable, EIP712, ERC20Permit, ERC20Safer, ERC20Receiver, ERC20Metadata, ERC20Burnable, ERC20, ERC165 {

    using Counters for Counters.Counter;

    /**
     * @dev Configuration for events to trigger for source smart contract.
     */
    uint256 private _eventConfig;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    uint256 private _status;

    mapping(bytes4 => bool) private _supportedInterfaces;

    mapping(address => Counters.Counter) private _nonces;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Initializes the collection.
     * @dev Special function to allow a one time initialisation on deployment. Also configures and deploys royalties.
     */
    function init(bytes memory data) external override returns (bytes4) {
//         (
//             string memory contractName,
//             string memory contractSymbol,
//             uint16 contractBps,
//             uint256 eventConfig,
//             bytes memory initCode
//         ) = abi.decode(data, (string, string, uint16, uint256, bytes));
//         _name = contractName;
//         _symbol = contractSymbol;
//         _bps = contractBps;
//         _eventConfig = eventConfig;
//         try IHolographer(payable(address(this))).getSourceContract() returns (address payable sourceAddress) {
//             require(IInitializable(sourceAddress).init(initCode) == IInitializable.init.selector, "initialization failed");
//         } catch {
//             // we do nothing
//         }
// //         (bool success, bytes memory returnData) = royalties().delegatecall(
// //             abi.encodeWithSignature("init(bytes)", abi.encode(address(this), uint256(contractBps)))
// //         );
// //         (bytes4 selector) = abi.decode(returnData, (bytes4));
// //         require(success && selector == IInitializable.init.selector, "initialization failed");
        return IInitializable.init.selector;
    }

    constructor() Admin(false) Owner(true) EIP712("\x24\x43\x52\x45\x41\x54\x45\x20\xf0\x9f\x8e\xa8\x20\x28\x4d\x69\x6e\x74\x65\x72\x20\x44\x41\x4f\x29", "1") {
        _status = 1;
        _totalSupply = 1000000000000; // 1 trillion
        _name = "\x24\x43\x52\x45\x41\x54\x45\x20\xf0\x9f\x8e\xa8\x20\x28\x4d\x69\x6e\x74\x65\x72\x20\x44\x41\x4f\x29";
        _symbol = "CREATE";
        _balances[super.getOwner()] = _totalSupply;
        emit Transfer(address(0), super.getOwner(), _totalSupply);

        // @dev We pre-set all supported interfaces here to make supportsInterface function calls gas efficient.

        // ERC165
        _supportedInterfaces [ERC165.supportsInterface.selector] = true;

        // ERC20
        _supportedInterfaces [ERC20.allowance.selector] = true;
        _supportedInterfaces [ERC20.approve.selector] = true;
        _supportedInterfaces [ERC20.balanceOf.selector] = true;
        _supportedInterfaces [ERC20.totalSupply.selector] = true;
        _supportedInterfaces [ERC20.transfer.selector] = true;
        _supportedInterfaces [ERC20.transferFrom.selector] = true;
        _supportedInterfaces [
            ERC20.allowance.selector
            ^ ERC20.approve.selector
            ^ ERC20.balanceOf.selector
            ^ ERC20.totalSupply.selector
            ^ ERC20.transfer.selector
            ^ ERC20.transferFrom.selector
        ] = true;

        // ERC20Metadata
        _supportedInterfaces [ERC20Metadata.name.selector] = true;
        _supportedInterfaces [ERC20Metadata.symbol.selector] = true;
        _supportedInterfaces [ERC20Metadata.decimals.selector] = true;
        _supportedInterfaces [
            ERC20Metadata.name.selector
            ^ ERC20Metadata.symbol.selector
            ^ ERC20Metadata.decimals.selector
        ] = true;

        // ERC20Burnable
        _supportedInterfaces [ERC20Burnable.burn.selector] = true;
        _supportedInterfaces [ERC20Burnable.burnFrom.selector] = true;
        _supportedInterfaces [
            ERC20Burnable.burn.selector
            ^ ERC20Burnable.burnFrom.selector
        ] = true;

        // ERC20Safer
        // bytes4(keccak256(abi.encodePacked('safeTransfer(address,uint256)'))) == 0x423f6cef
        _supportedInterfaces [0x423f6cef] = true;
        // bytes4(keccak256(abi.encodePacked('safeTransfer(address,uint256,bytes)'))) == 0xeb795549
        _supportedInterfaces [0xeb795549] = true;
        // bytes4(keccak256(abi.encodePacked('safeTransferFrom(address,address,uint256)'))) == 0x42842e0e
        _supportedInterfaces [0x42842e0e] = true;
        // bytes4(keccak256(abi.encodePacked('safeTransferFrom(address,address,uint256,bytes)'))) == 0xb88d4fde
        _supportedInterfaces [0xb88d4fde] = true;
        _supportedInterfaces [
            bytes4(0x423f6cef)
            ^ bytes4(0xeb795549)
            ^ bytes4(0x42842e0e)
            ^ bytes4(0xb88d4fde)
        ] = true;

        // ERC20Permit
        _supportedInterfaces [ERC20Permit.permit.selector] = true;
        _supportedInterfaces [ERC20Permit.nonces.selector] = true;
        _supportedInterfaces [ERC20Permit.DOMAIN_SEPARATOR.selector] = true;
        _supportedInterfaces [
            ERC20Permit.permit.selector
            ^ ERC20Permit.nonces.selector
            ^ ERC20Permit.DOMAIN_SEPARATOR.selector
        ] = true;
    }

    /**
     * @dev Get the source smart contract.
     */
    function source() private view returns (address) {
        return IHolographer(payable(address(this))).getSourceContract();
    }

    /**
     * @notice Fallback to the source contract.
     * @dev Any function call that is not covered here, will automatically be sent over to the source contract.
     */
    fallback() external {
        address _target = source();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := call(gas(), _target, 0, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    modifier nonReentrant() {
        require(_status != 2, "ERC20: reentrant call");
        _status = 2;
        _;
        _status = 1;
    }

    function decimals() public pure returns (uint8) {
        return 0;
    }

    /**
     * @dev Although EIP-165 is not required for ERC20 contracts, we still decided to implement it.
     *
     * This makes it easier for external smart contracts to easily identify a valid ERC20 token contract.
     */
    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        return _supportedInterfaces [interfaceId];
    }

    function allowance(address account, address spender) public view returns (uint256) {
        return _allowances[account][spender];
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function nonces(address account) public view returns (uint256) {
        return _nonces[account].current();
    }

    function owner() public view returns (address) {
        return super.getOwner();
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[account][msg.sender];
        require(currentAllowance >= amount, "ERC20: amount exceeds allowance");
        unchecked {
            _allowances[account][msg.sender] = currentAllowance - amount;
        }
        _burn(account, amount);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    /**
     * @dev Reserved to be only accessible to current contract owner.
     *
     * This function can communicate with any other smart contract, and interact with them directly.
     * This function cannot modify any internal ERC20 logic of this token.
     * This function cannot be used to manipulate tokens of other accounts.
     * This function will be primarily used to remove spammy tokens and NFTs from the smart contract's balances.
     */
    function externalContractCall(address targetContract, bytes calldata callPayload) public onlyOwner {
        (bool success,/* bytes memory response*/) = _makeExternalCall(targetContract, callPayload);
        require(success, "ERC20: Contract call failed");
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function onERC20Received(address/* account*/, address/* recipient*/, uint256/* amount*/, bytes calldata/* data*/) public pure returns(bytes4) {
        return this.onERC20Received.selector;
    }

    function permit(
        address account,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(block.timestamp <= deadline, "ERC20: expired deadline");
        // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
        //  == 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9
        bytes32 structHash = keccak256(abi.encode(
            0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9,
            account,
            spender,
            amount,
            _useNonce(account),
            deadline
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == account, "ERC20: invalid signature");
        _approve(account, spender, amount);
    }

    function safeTransfer(address recipient, uint256 amount) public returns (bool){
        return safeTransfer(recipient, amount, "");
    }

    function safeTransfer(address recipient, uint256 amount, bytes memory data) public returns (bool) {
        transfer(recipient, amount);
        require(_checkOnERC20Received(msg.sender, recipient, amount, data), "ERC20: non ERC20Receiver");
        return true;
    }

    function safeTransferFrom(address account, address recipient, uint256 amount) public returns (bool){
        return safeTransferFrom(account, recipient, amount, "");
    }

    function safeTransferFrom(address account, address recipient, uint256 amount, bytes memory data) public returns (bool){
        transferFrom(account, recipient, amount);
        require(_checkOnERC20Received(account, recipient, amount, data), "ERC20: non ERC20Receiver");
        return true;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address account, address recipient, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[account][msg.sender];
        require(currentAllowance >= amount, "ERC20: amount exceeds allowance");
        unchecked {
            _allowances[account][msg.sender] = currentAllowance - amount;
        }
        _transfer(account, recipient, amount);
        return true;
    }

    /**
     * @dev Reserved to be only accessible to current contract owner.
     *
     * This function withdraws the smart contract's specific ERC20 token to a specified recipient.
     * This function cannot be used to manipulate tokens of other accounts.
     * This function cannot withdraw ERC20 tokens from any other wallet/contract, only the smart contract's balance.
     */
    function withdrawERC20 (address token, address recipient, uint256 amount) public onlyOwner {
        require(!Address.isZero(token), "ERC20: token is zero address");
        require(!Address.isZero(recipient), "ERC20: recipient is zero address");
        require(amount > 0, "ERC20: amount is zero");
        require(_transferERC20(token, recipient, amount), "ERC20: transfer function failed");
    }

    /**
     * @dev Reserved to be only accessible to current contract owner.
     *
     * This function withdraws the smart contract's ETH balance to specified recipient.
     * This function cannot be used to manipulate tokens of other accounts.
     * This function cannot withdraw ETH from any other balance, only the smart contract's balance.
     */
    function withdrawETH (address payable recipient, uint256 amount) public onlyOwner {
        require(!Address.isZero(recipient), "ERC20: recipient is zero address");
        if (amount == 0) {
            amount = address(this).balance;
        } else {
            require(amount <= address(this).balance, "ERC20: amount too high");
        }
        require(amount > 0, "ERC20: amount too low");
        _transferETH(recipient, amount);
    }

    function _approve(address account, address spender, uint256 amount) internal {
        require(!Address.isZero(account), "ERC20: account is zero address");
        require(!Address.isZero(spender), "ERC20: spender is zero address");
        _allowances[account][spender] = amount;
        emit Approval(account, spender, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(!Address.isZero(account), "ERC20: account is zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _checkOnERC20Received(address account, address recipient, uint256 amount, bytes memory data) internal nonReentrant returns (bool) {
        if (Address.isContract(recipient)) {
            try ERC20Receiver(recipient).onERC20Received(msg.sender, account, amount, data) returns(bytes4 retval) {
                return retval == ERC20Receiver.onERC20Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC20: non ERC20Receiver");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _makeExternalCall(address target, bytes calldata payload) internal nonReentrant returns (bool, bytes memory) {
        return target.call(payload);
    }

    function _transfer(address account, address recipient, uint256 amount) internal {
        require(!Address.isZero(account), "ERC20: account is zero address");
        require(!Address.isZero(recipient), "ERC20: recipient is zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _balances[recipient] += amount;
        emit Transfer(account, recipient, amount);
    }

    function _transferERC20(address token, address recipient, uint256 amount) internal nonReentrant returns (bool) {
        return ERC20(token).transfer(recipient, amount);
    }

    function _transferETH(address payable recipient, uint256 amount) internal nonReentrant {
        recipient.transfer(amount);
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     *
     * _Available since v4.1._
     */
    function _useNonce(address account) internal returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[account];
        current = nonce.current();
        nonce.increment();
    }

}
