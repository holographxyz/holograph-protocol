HOLOGRAPH_LICENSE_HEADER

SOLIDITY_COMPILER_VERSION

import "./abstract/Initializable.sol";

import "./interface/ERC20Holograph.sol";
import "./interface/HolographedERC20.sol";
import "./interface/IInitializable.sol";

import "./library/Strings.sol";

/**
 * @title Holograph token (aka hToken), used to wrap and bridge native tokens across blockchains.
 * @author CXIP-Labs
 * @notice A smart contract for minting and managing Holograph Bridgeable ERC20 Tokens.
 * @dev The entire logic and functionality of the smart contract is self-contained.
 */
contract hToken is Initializable, HolographedERC20  {

    /*
     * @dev Address of initial creator/owner of the contract.
     */
    address private _owner;

    /*
     * @dev Address of Holograph ERC20 standards enforcer smart contract.
     */
    address private _holographer;

    /*
     * @dev Dummy variable to prevent empty functions from making "switch to pure" warnings.
     */
    bool private _success;

    /*
     * @dev Just a dummy value for now to test transferring of data.
     */
    mapping(address => bytes32) private _walletSalts;

    modifier onlyHolographer() {
        require(msg.sender == _holographer, "holographer only function");
        _;
    }

    /**
     * @notice Constructor is empty and not utilised.
     * @dev To make exact CREATE2 deployment possible, constructor is left empty. We utilize the "init" function instead.
     */
    constructor() {}

    /**
     * @notice Initializes the collection.
     * @dev Special function to allow a one time initialisation on deployment. Also configures and deploys royalties.
     */
    function init(bytes memory data) external override returns (bytes4) {
        require(!_isInitialized(), "ERC20: already initialized");
        _holographer = msg.sender;
        (address owner) = abi.decode(data, (address));
        _owner = owner;
        _setInitialized();
        return IInitializable.init.selector;
    }

    /*
     * @dev Sample mint where anyone can mint any token, with a custom URI
     */
    function mint(address/* msgSender*/, address to, uint256 amount) external onlyHolographer {
        ERC20Holograph(_holographer).sourceMint(to, amount);
    }

    function test(address msgSender) external view onlyHolographer returns (string memory) {
        return string(abi.encodePacked("it works! ", Strings.toHexString(msgSender)));
    }

    function bridgeIn(uint32/* _chainId*/, address/* _from*/, address _to, uint256/* _amount*/, bytes calldata _data) external onlyHolographer returns (bool) {
        (bytes32 salt) = abi.decode(_data, (bytes32));
        _walletSalts[_to] = salt;
        return true;
    }

    function bridgeOut(uint32/* _chainId*/, address/* _from*/, address _to, uint256/* _amount*/) external view onlyHolographer returns (bytes memory _data) {
        _data = abi.encode(_walletSalts[_to]);
    }

    function afterApprove(address/* _owner*/, address/* _to*/, uint256/* _amount*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function beforeApprove(address/* _owner*/, address/* _to*/, uint256/* _amount*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function afterOnERC20Received(address/* _token*/, address/* _from*/, address/* _to*/, uint256/* _amount*/, bytes calldata/* _data*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function beforeOnERC20Received(address/* _token*/, address/* _from*/, address/* _to*/, uint256/* _amount*/, bytes calldata/* _data*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function afterBurn(address/* _owner*/, uint256/* _amount*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function beforeBurn(address/* _owner*/, uint256/* _amount*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function afterMint() external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function beforeMint() external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function afterSafeTransfer(address/* _from*/, address/* _to*/, uint256/* _amount*/, bytes calldata/* _data*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function beforeSafeTransfer(address/* _from*/, address/* _to*/, uint256/* _amount*/, bytes calldata/* _data*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function afterTransfer(address/* _from*/, address/* _to*/, uint256/* _amount*/, bytes calldata/* _data*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

    function beforeTransfer(address/* _from*/, address/* _to*/, uint256/* _amount*/, bytes calldata/* _data*/) external onlyHolographer returns (bool success) {
        _success = true;
        return _success;
    }

}
