// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./IMessageSpaceStation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMessageEmitter {
    function minArrivalTime() external view returns (uint64);

    function maxArrivalTime() external view returns (uint64);

    function minGasLimit() external view returns (uint24);

    function maxGasLimit() external view returns (uint24);

    function defaultBridgeMode() external view returns (bytes1);

    function selectedRelayer() external view returns (address);
}
