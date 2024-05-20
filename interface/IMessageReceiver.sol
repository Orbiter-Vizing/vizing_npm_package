// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IMessageReceiver {
    function receiveStandardMessage(
        uint64 srcChainId,
        uint256 srcContract,
        bytes calldata message
    ) external payable;
}
