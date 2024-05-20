// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageStruct} from "./IMessageStruct.sol";

interface IMessageChannel is IMessageStruct {
    /*
        /// @notice LaunchPad is the function that user or DApps send omni-chain message to other chain
        ///         Once the message is sent, the Relay will validate the message and send it to the target chain
        /// @dev 1. we will call the LaunchPad.Launch function to emit the message
        /// @dev 2. the message will be sent to the destination chain
        /// @param earliestArrivalTimestamp The earliest arrival time for the message
        ///        set to 0, vizing will forward the information ASAP.
        /// @param latestArrivalTimestamp The latest arrival time for the message
        ///        set to 0, vizing will forward the information ASAP.
        /// @param relayer the specify relayer for your message
        ///        set to 0, all the relayers will be able to forward the message
        /// @param sender The sender address for the message
        ///        most likely the address of the EOA, the user of some DApps
        /// @param value native token amount, will be sent to the target contract
        /// @param destChainid The destination chain id for the message
        /// @param additionParams The addition params for the message
        ///        if not in expert mode, set to 0 (`new bytes(0)`)
        /// @param message Arbitrary information
        ///
        ///    bytes                         
        ///   message  = abi.encodePacked(
        ///         byte1           uint256         uint24        uint64        bytes
        ///     messageType, activateContract, executeGasLimit, maxFeePerGas, signature
        ///   )
        ///        
    */
    function Launch(
        uint64 earliestArrivalTimestamp,
        uint64 latestArrivalTimestamp,
        address relayer,
        address sender,
        uint256 value,
        uint64 destChainid,
        bytes calldata additionParams,
        bytes calldata message
    ) external payable;

    ///
    ///    bytes                          byte1           uint256         uint24        uint64        bytes
    ///   message  = abi.encodePacked(messageType, activateContract, executeGasLimit, maxFeePerGas, signature)
    ///
    function launchMultiChain(
        launchEnhanceParams calldata params
    ) external payable;

    /// @notice batch landing message to the chain, execute the landing message
    /// @dev trusted relayer will call this function to send omni-chain message to the Station
    /// @param params the landing message params
    /// @param proofs the  proof of the validated message
    function Landing(
        landingParams[] calldata params,
        bytes[][] calldata proofs
    ) external payable;

    /// @notice similar to the Landing function, but with gasLimit
    function LandingSpecifiedGas(
        landingParams[] calldata params,
        uint24 gasLimit,
        bytes[][] calldata proofs
    ) external payable;

    /// @dev feel free to call this function before pass message to the Station,
    ///      this method will return the protocol fee that the message need to pay, longer message will pay more
    function estimateGas(
        uint256[] calldata value,
        uint64[] calldata destChainid,
        bytes[] calldata additionParams,
        bytes[] calldata message
    ) external view returns (uint256);

    function estimateGas(
        uint256 value,
        uint64 destChainid,
        bytes calldata additionParams,
        bytes calldata message
    ) external view returns (uint256);

    function estimatePrice(
        address sender,
        uint64 destChainid
    ) external view returns (uint64);

    function gasSystemAddr() external view returns (address);

    /// @dev get the message launch nonce of the sender on the specific chain
    /// @param chainId the chain id of the sender
    /// @param sender the address of the sender
    function GetNonceLaunch(
        uint64 chainId,
        address sender
    ) external view returns (uint32);

    /// @dev get the message landing nonce of the sender on the specific chain
    /// @param chainId the chain id of the sender
    /// @param sender the address of the sender
    function GetNonceLanding(
        uint64 chainId,
        address sender
    ) external view returns (uint32);

    /// @dev get the version of the Station
    /// @return the version of the Station, like "v1.0.0"
    function Version() external view returns (string memory);

    /// @dev get the chainId of current Station
    /// @return chainId, defined in the L2SupportLib.sol
    function Chainid() external view returns (uint64);

    function minArrivalTime() external view returns (uint64);

    function maxArrivalTime() external view returns (uint64);

    function expertLandingHook(bytes1 hook) external view returns (address);

    function expertLaunchHook(bytes1 hook) external view returns (address);
}
