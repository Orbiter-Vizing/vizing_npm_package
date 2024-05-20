// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVizingGasSystemChannel {
    /*
        /// @notice Estimate how many native token we should spend to exchange the amountOut in the destChainid
        /// @param destChainid The chain id of the destination chain
        /// @param amountOut The value we want to receive in the destination chain
        /// @return amountIn the native token amount on the source chain we should spend
    */
    function exactOutput(
        uint64 destChainid,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    /*
        /// @notice Estimate how many native token we could get in the destChainid if we input the amountIn
        /// @param destChainid The chain id of the destination chain
        /// @param amountIn The value we spent in the source chain
        /// @return amountOut the native token amount the destination chain will receive
    */
    function exactInput(
        uint64 destChainid,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    /*
        /// @notice Estimate the gas fee we should pay to vizing
        /// @param destChainid The chain id of the destination chain
        /// @param message The message we want to send to the destination chain
    */
    function estimateGas(
        uint256 amountOut,
        uint64 destChainid,
        bytes calldata message
    ) external view returns (uint256);

    /*
        /// @notice Estimate the gas fee & native token we should pay to vizing
        /// @param amountOut amountOut in the destination chain
        /// @param destChainid The chain id of the destination chain
        /// @param message The message we want to send to the destination chain
    */
    function batchEstimateTotalFee(
        uint256[] calldata amountOut,
        uint64[] calldata destChainid,
        bytes[] calldata message
    ) external view returns (uint256 totalFee);

    /*
        /// @notice Estimate the total fee we should pay to vizing
        /// @param value The value we spent in the source chain
        /// @param destChainid The chain id of the destination chain
        /// @param message The message we want to send to the destination chain
    */
    function estimateTotalFee(
        uint256 value,
        uint64 destChainid,
        bytes calldata message
    ) external view returns (uint256 totalFee);

    /*
        /// @notice Estimate the gas price we need to encode in message
        /// @param sender most likely the address of the DApp, which forward the message from user
        /// @param destChainid The chain id of the destination chain
    */
    function estimatePrice(
        address targetContract,
        uint64 destChainid
    ) external view returns (uint64);

    /*
        /// @notice Estimate the gas price we need to encode in message
        /// @param destChainid The chain id of the destination chain
    */
    function estimatePrice(uint64 destChainid) external view returns (uint64);

    /*
        /// @notice Calculate the fee for the native token transfer
        /// @param amount The value we spent in the source chain
    */
    function computeTradeFee(
        uint64 destChainid,
        uint256 amountOut
    ) external view returns (uint256 fee);

    /*
        /// @notice Calculate the fee for the native token transfer
        /// @param amount The value we spent in the source chain
    */
    function computeTradeFee(
        address targetContract,
        uint64 destChainid,
        uint256 amountOut
    ) external view returns (uint256 fee);
}
