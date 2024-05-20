// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageStruct} from "./IMessageStruct.sol";
import {IMessageDashboard} from "./IMessageDashboard.sol";
import {IMessageEvent} from "../interface/IMessageEvent.sol";
import {IMessageChannel} from "../interface/IMessageChannel.sol";
import {IMessageSimulation} from "../interface/IMessageSimulation.sol";

interface IMessageSpaceStation is
    IMessageStruct,
    IMessageDashboard,
    IMessageEvent,
    IMessageChannel,
    IMessageSimulation
{}
