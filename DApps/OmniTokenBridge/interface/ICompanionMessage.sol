// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface ICompanionMessage {
    function bridgeConvertTokenReceiver(
        bytes calldata companionMessage
    ) external returns (bool);
}
