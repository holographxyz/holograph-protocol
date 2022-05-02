HOLOGRAPH_LICENSE_HEADER

SOLIDITY_COMPILER_VERSION

import "./abstract/Admin.sol";
import "./abstract/Initializable.sol";

import "./interface/IHolograph.sol";
import "./interface/IHolographRegistry.sol";
import "./interface/IInitializable.sol";

/*
 * @dev This contract is the source code for all hTokens.
 */
contract hTokenSource is Admin, Initializable {

    address[] private _approvedWrappers;

    /*
     * @dev Constructor is left empty and only the admin address is set.
     */
    constructor() Admin(true) {}

    /*
     * @dev Initialize contract with chain id and holograph reference
     */
    function init(bytes memory data) external override returns (bytes4) {
        require(!_isInitialized(), "HOLOGRAPHER: already initialized");
        (address[] memory approvedWrappers) = abi.decode(data, (address[]));
        _approvedWrappers = approvedWrappers;
        _setInitialized();
        return IInitializable.init.selector;
    }

    function isOnOriginChain() public view returns (bool) {
        address holograph;
        uint32 originChain;
        assembly {
            holograph := sload(/* slot */precomputeslot('eip1967.Holograph.Bridge.holograph'))
            originChain := sload(/* slot */precomputeslot('eip1967.Holograph.Bridge.originChain'))
        }
        uint32 currentChain = IHolograph(holograph).getChainType();
        return originChain == currentChain;
    }

}
