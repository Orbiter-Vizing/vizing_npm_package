// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IMessageStruct {
    struct launchParams {
        uint64 earliestArrivalTimestamp;
        uint64 latestArrivalTimestamp;
        address relayer;
        address sender;
        uint256 value;
        uint64 destChainid;
        bytes additionParams;
        bytes message;
    }

    struct landingParams {
        bytes32 messageId;
        uint64 earliestArrivalTimestamp;
        uint64 latestArrivalTimestamp;
        uint64 srcChainid;
        bytes32 srcTxHash;
        uint256 srcContract;
        uint32 srcChainNonce;
        uint256 sender;
        uint256 value;
        bytes additionParams;
        bytes message;
    }

    struct launchEnhanceParams {
        uint64 earliestArrivalTimestamp;
        uint64 latestArrivalTimestamp;
        address relayer;
        address sender;
        uint256[] value;
        uint64[] destChainid;
        bytes[] additionParams;
        bytes[] message;
    }

    struct RollupMessageStruct {
        SignedMessageBase base;
        IMessageStruct.launchParams params;
    }

    struct SignedMessageBase {
        uint64 srcChainId;
        uint24 nonceLaunch;
        bytes32 srcTxHash;
        bytes32 destTxHash;
        uint64 srcTxTimestamp;
        uint64 destTxTimestamp;
    }
}
