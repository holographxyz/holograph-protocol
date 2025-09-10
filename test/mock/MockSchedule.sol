// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../src/StakingRewards.sol";

contract MockSchedule is StakingRewards {
    constructor(address _hlg, address _owner) StakingRewards(_hlg, _owner) {}

    function setSchedules(uint256 addAmt, uint256 remAmt, uint256 eligible) external {
        scheduledAdditionsNextEpoch = addAmt;
        scheduledRemovalsNextEpoch = remAmt;
        eligibleTotal = eligible;
    }

    function forceSync() external {
        _advanceEpoch();
    }
}
