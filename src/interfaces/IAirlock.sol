// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CreateParams} from "lib/doppler/src/Airlock.sol";

interface IAirlock {
    function create(
        CreateParams calldata params
    ) external returns (address asset, address pool, address governance, address timelock, address migrationPool);
}
