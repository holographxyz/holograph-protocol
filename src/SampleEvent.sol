HOLOGRAPH_LICENSE_HEADER

SOLIDITY_COMPILER_VERSION

contract SampleEvent {

    event Packet (uint16 chainId, bytes payload);

    constructor() {
    }

    function sample(bytes memory data) external {
        emit Packet(1, data);
    }

}
