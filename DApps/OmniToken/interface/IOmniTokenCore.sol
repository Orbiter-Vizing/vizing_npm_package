// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IOmniTokenCore {
    struct activateRawMsg {
        uint64[] destChainid;
        uint64 earliestArrivalTimestamp;
        uint64 latestArrivalTimestamp;
        address sender;
        address relayer;
        bytes1[] mode;
        address[] targetContarct;
        uint24[] gasLimit;
        bytes[] message;
        bytes[] additionParams;
    }

    function mint(address toAddress, uint256 amount) external payable;

    function bridgeTransfer(
        uint64 destChainId,
        address receiver,
        uint256 amount
    ) external payable;

    function bridgeTransferReceiver(address toAddress, uint256 amount) external;

    function bridgeMint(
        uint64 destChainId,
        address receiver,
        uint256 amount,
        uint256 gasTip
    ) external payable;

    function simpleBridgeMint(
        uint64 destChainId,
        address receiver,
        uint256 amount,
        uint256 gasTip
    ) external payable;

    function fetchOmniTokenTransferFee(
        uint64 destChainId,
        address receiver,
        uint256 amount
    ) external view returns (uint256);

    function fetchOmniTokenMintFee(
        uint256 value,
        uint64 destChainId,
        address receiver,
        uint256 amount
    ) external view returns (uint256);
}
