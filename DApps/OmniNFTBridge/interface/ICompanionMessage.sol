// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ICompanionMessage {
    function handlerBridgeCompanionMessage(
        bytes calldata companionMessage
    ) external returns (bool);
}
