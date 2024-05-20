// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageStruct} from "./IMessageStruct.sol";

interface IMessageEvent is IMessageStruct {
    /// @notice Throws event after a  message which attempts to omni-chain is submitted to LaunchPad contract
    event SuccessfulLaunchMessage(
        uint32 indexed nonce,
        uint64 earliestArrivalTimestamp,
        uint64 latestArrivalTimestamp,
        address relayer,
        address sender,
        address srcContract,
        uint256 value,
        uint64 destChainid,
        bytes additionParams,
        bytes message
    );

    /// @notice Throws event after a  message which attempts to omni-chain is submitted to LaunchPad contract
    event SuccessfulLaunchMultiMessages(
        uint32[] indexed nonce,
        uint64 earliestArrivalTimestamp,
        uint64 latestArrivalTimestamp,
        address relayer,
        address sender,
        address srcContract,
        uint256[] value,
        uint64[] destChainid,
        bytes[] additionParams,
        bytes[] message
    );

    /// @notice Throws event after a omni-chain message is submitted from source chain to target chain
    event SuccessfulLanding(bytes32 indexed messageId, landingParams params);

    /// @notice Throws event after protocol state is changed, such as pause or resume
    event EngineStateRefreshing(bool indexed isPause);

    /// @notice Throws event after protocol fee calculation is changed
    event PaymentSystemChanging(address indexed gasSystemAddress);

    /// @notice Throws event after successful withdrawa
    event WithdrawRequest(address indexed to, uint256 amount);
}
