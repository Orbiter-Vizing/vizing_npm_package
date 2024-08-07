// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import {VizingERC20HandlerUpgradeable} from "./VizingERC20Handler-upgradeable.sol";
abstract contract VizingERC20Handler is VizingERC20HandlerUpgradeable {
    constructor(address _vizingPad) {
        __VizingERC20HandlerInit(_vizingPad);
    }
}
