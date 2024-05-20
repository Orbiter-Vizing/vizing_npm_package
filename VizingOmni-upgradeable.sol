// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MessageEmitterUpgradeable} from "./MessageEmitter-upgradeable.sol";
import {MessageReceiverUpgradeable} from "./MessageReceiver-upgradeable.sol";

abstract contract VizingOmniUpgradeable is
    MessageEmitterUpgradeable,
    MessageReceiverUpgradeable
{
    function __VizingOmniInit(address _vizingPad) internal {
        MessageEmitterUpgradeable.__LaunchPadInit(_vizingPad);
        MessageReceiverUpgradeable.__LandingPadInit(_vizingPad);
    }
}
