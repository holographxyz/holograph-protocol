// SPDX-License-Identifier: UNLICENSED

SOLIDITY_COMPILER_VERSION

struct DeploymentConfig {
    bytes32 contractType;
    uint32 chainType;
    bytes32 salt;
    bytes byteCode;
    bytes initCode;
}
