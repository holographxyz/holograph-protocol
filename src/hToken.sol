HOLOGRAPH_LICENSE_HEADER

SOLIDITY_COMPILER_VERSION

import "./abstract/Admin.sol";
import "./abstract/Initializable.sol";

import "./interface/IHolograph.sol";
import "./interface/IHolographRegistry.sol";
import "./interface/IInitializable.sol";

/*
 * @dev This contract is a binder. It puts together all the variables to make the underlying contracts functional and be bridgeable.
 */
contract hToken is Admin, Initializable {

    /*
     * @dev Constructor is left empty and only the admin address is set.
     */
    constructor() Admin(true) {}

    /*
     * @dev Initialize contract with chain id and holograph reference
     */
    function init(bytes memory data) external override returns (bytes4) {
        require(!_isInitialized(), "HOLOGRAPHER: already initialized");
        (bytes memory encoded, bytes memory initCode) = abi.decode(data, (bytes, bytes));
        (uint32 originChain, address holograph) = abi.decode(encoded, (uint32, address));
        bytes32 hTokenSource = bytes32(abi.encodePacked("hToken", originChain));
        assembly {
            sstore(precomputeslot('eip1967.Holograph.Bridge.originChain'), originChain)
            sstore(precomputeslot('eip1967.Holograph.Bridge.holograph'), holograph)
            sstore(precomputeslot('eip1967.Holograph.Bridge.hTokenSource'), hTokenSource)
        }
        (bool success, bytes memory returnData) = getHTokenSource().delegatecall(
            abi.encodeWithSignature("init(bytes)", initCode)
        );
        (bytes4 selector) = abi.decode(returnData, (bytes4));
        require(success && selector == IInitializable.init.selector, "initialization failed");
        _setInitialized();
        return IInitializable.init.selector;
    }

    /*
     * @dev Returns the original chain that contract was deployed on.
     */
    function getOriginChain() public view returns (uint32 originChain) {
        assembly {
            originChain := sload(/* slot */precomputeslot('eip1967.Holograph.Bridge.originChain'))
        }
    }

    /*
     * @dev Returns address of hToken smart contract source code.
     */
    function getHTokenSource() public view returns (address payable) {
        address holograph;
        bytes32 hTokenSource;
        assembly {
            holograph := sload(/* slot */precomputeslot('eip1967.Holograph.Bridge.holograph'))
            hTokenSource := sload(/* slot */precomputeslot('eip1967.Holograph.Bridge.hTokenSource'))
        }
        return payable(
            IHolographRegistry(
                IHolograph(
                    holograph
                ).getRegistry()
            ).getContractTypeAddress(hTokenSource)
        );
    }

    /*
     * @dev Purposefully reverts, to prevent accidental native token direct transfers.
     */
    receive() external payable {
        revert("HOLOGRAPH: don't send directly");
    }

    /*
     * @dev Hard-coded registry address and contract type are put inside the fallback to make sure that the contract cannot be modified.
     * @dev This takes the underlying address source code, runs it, and uses current address for storage.
     */
    fallback() external payable {
        address hTokenSource = getHTokenSource();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), hTokenSource, 0, calldatasize(), 0, 0)
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

}
