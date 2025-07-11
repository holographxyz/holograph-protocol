// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FeeRouter} from "../../src/FeeRouter.sol";

contract MockLZEndpoint {
    event MessageSent(uint32 dstEid, bytes payload, bytes options);

    // Simple mapping to store cross-chain targets
    address public crossChainTarget;
    address public targetEndpoint; // The endpoint that should call lzReceive

    bool private _sendCalled;
    uint256 private _lastValue;
    bytes private _lastPayload;
    uint32 private _lastEid;

    function setCrossChainTarget(address target) external {
        crossChainTarget = target;
    }

    function setTargetEndpoint(address endpoint) external {
        targetEndpoint = endpoint;
    }

    function send(uint32 eid, bytes calldata payload, bytes calldata /*options*/) external payable {
        _sendCalled = true;
        _lastValue = msg.value;
        _lastPayload = payload;
        _lastEid = eid;

        emit MessageSent(eid, payload, "");

        // Simple cross-chain simulation - call the target directly
        if (crossChainTarget != address(0)) {
            // Determine source EID based on destination
            uint32 srcEid = eid == 30101 ? uint32(30184) : uint32(30101); // ETH_EID : BASE_EID

            // We need to simulate the target endpoint calling lzReceive
            // This is a bit of a hack for testing, but it works
            MockLZEndpoint(targetEndpoint).deliverMessage{value: msg.value}(
                crossChainTarget,
                srcEid,
                payload,
                msg.sender
            );
        }
    }

    // Helper function to deliver the message as if we were the endpoint
    function deliverMessage(address target, uint32 srcEid, bytes calldata payload, address sender) external payable {
        FeeRouter(payable(target)).lzReceive{value: msg.value}(srcEid, payload, sender, "");
    }

    // Test helper functions
    function sendCalled() external view returns (bool) {
        return _sendCalled;
    }

    function lastValue() external view returns (uint256) {
        return _lastValue;
    }

    function lastPayload() external view returns (bytes memory) {
        return _lastPayload;
    }

    function lastEid() external view returns (uint32) {
        return _lastEid;
    }

    function reset() external {
        _sendCalled = false;
        _lastValue = 0;
        delete _lastPayload;
        _lastEid = 0;
    }

    // Mock LayerZero OApp functions
    function setDelegate(address /*delegate*/) external {
        // Mock implementation - do nothing
    }
}
