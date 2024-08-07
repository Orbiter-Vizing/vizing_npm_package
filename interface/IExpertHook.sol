// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageStruct} from "./IMessageStruct.sol";
import {IMessageSpaceStation} from "./IMessageSpaceStation.sol";

interface IExpertHook {
    function handleLaunch(
        bytes calldata vizingPadCalldata
    ) external returns (bool success, bytes memory);

    function handleLanding(
        IMessageSpaceStation.landingParams calldata params
    ) external returns (bool success, bytes memory);

    function handleLanding(
        IMessageSpaceStation.landingParams calldata params,
        uint256 msgValue
    ) external returns (bool success, bytes memory);
}
