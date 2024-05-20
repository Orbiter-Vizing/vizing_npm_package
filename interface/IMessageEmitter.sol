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

    function emit2LaunchPad(
        uint64 earliestArrivalTimestamp,
        uint64 latestArrivalTimestamp,
        address relayer,
        address sender,
        uint256 value,
        uint64 destChainid,
        bytes memory additionParams,
        bytes memory message
    ) external payable;

    /// @notice **Highly recommend** to call this function in your frontend program
    /// @notice call this function to packet the message before sending it to the LandingPad contract
    /// @param mode the emitter mode, check MessageTypeLib.sol for more details
    ///        eg: 0x02 for ARBITRARY_ACTIVATE, your message will be activated on the target chain
    /// @param gasLimit the gas limit for executing the specific function on the target contract
    /// @param targetContract the target contract address on the destination chain
    /// @param message the message to be sent to the target contract
    /// @return the packed message
    function PacketMessages(
        bytes1[] memory mode,
        address[] memory targetContract,
        uint24[] memory gasLimit,
        uint64[] memory price,
        bytes[] memory message
    ) external view returns (bytes[] memory);

    /*
        /// @notice similar to PacketMessages, but only pack one message
    */
    function PacketMessage(
        bytes1 mode,
        address targetContract,
        uint24 gasLimit,
        uint64 price,
        bytes memory message
    ) external view returns (bytes memory);

    /*
        /// @notice use this function to send the ERC20 token to the destination chain
        /// @param tokenSymbol The token symbol
        /// @param sender The sender address for the message
        /// @param receiver The receiver address for the message
        /// @param amount The amount of tokens to be sent
        /// see https://docs.vizing.com/docs/DApp/Omni-ERC20-Transfer
    */
    function PacketAdditionParams(
        bytes1 mode,
        bytes1 tokenSymbol,
        address sender,
        address receiver,
        uint256 amount
    ) external pure returns (bytes memory);

    /*
        /// @notice **Highly recommend** to call this function in your frontend program
        /// @notice Estimate how many native token we should spend to exchange the amountOut in the destChainid
        /// @param destChainid The chain id of the destination chain
        /// @param amountOut The value we want to exchange in the destination chain
    */
    function exactOutput(
        uint64 destChainid,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    /*
        /// @notice **Highly recommend** to call this function in your frontend program
        /// @notice Estimate how many native token we could get in the destChainid if we input the amountIn
        /// @param destChainid The chain id of the destination chain
        /// @param amountIn The value we spent in the source chain
    */
    function exactInput(
        uint64 destChainid,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    /*  
        /// @notice **Highly recommend** to call this function in your frontend program
        /// @notice Estimate the gas price we need to encode in message
        /// @param value The native token that value target address will receive in the destination chain
        /// @param destChainid The chain id of the destination chain
        /// @param additionParams The addition params for the message
        ///        if not in expert mode, set to 0 (`new bytes(0)`)
        /// @param message The message we want to send to the destination chain
    */
    function estimateVizingGasFee(
        uint256 value,
        uint64 destChainid,
        bytes calldata additionParams,
        bytes calldata message
    ) external view returns (uint256 vizingGasFee);

    /*
        /// @notice Calculate the amount of native tokens obtained on the target chain
        /// @param value The value we send to vizing on the source chain
    */
    function computeTradeFee(
        uint64 destChainid,
        uint256 value
    ) external view returns (uint256 amountIn);
}
