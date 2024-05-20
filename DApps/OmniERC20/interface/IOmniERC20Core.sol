// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IOmniERC20Core {
    event TransferToChain(
        address indexed tokenSender,
        uint256 amount,
        uint64 destinationChainId
    );

    function transferToChain(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 amount
    ) external payable;

    function transferToChain(
        uint64 destinationChainId,
        uint256 amount,
        bytes calldata additionalParams,
        bytes calldata packedMessage
    ) external payable;

    function estimateTransferToChainFee(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 amount
    ) external view returns (uint256 gasFee);

    function estimateTransferToChainFee(
        uint64 destinationChainId,
        bytes calldata additionalParams,
        bytes calldata packedMessage
    ) external view returns (uint256 gasFee);

    function receiveTransferFromOtherChain(
        address tokenReceiver,
        uint256 amount
    ) external;

    function fetchTransferSignature(
        address tokenReceiver,
        uint256 amount
    ) external view returns (bytes memory signature);

    function fetchTransferMessage(
        address destinationOmniERC20,
        uint24 gasLimit,
        uint64 price,
        bytes calldata signature
    ) external view returns (bytes memory message);

    function fetchTransferPrice(
        address destinationOmniERC20,
        uint64 destChainid
    ) external view returns (uint64 price);
}
