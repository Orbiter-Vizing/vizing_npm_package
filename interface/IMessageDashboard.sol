// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageStruct} from "./IMessageStruct.sol";

interface IMessageDashboard is IMessageStruct {
    /// @dev Only owner can call this function to stop or restart the engine
    /// @param stop true is stop, false is start
    function PauseEngine(bool stop) external;

    /// @notice return the states of the engine
    /// @return 0x01 is stop, 0x02 is start
    function engineState() external view returns (uint8);

    /// @notice return the states of the engine & Landing Pad
    function padState() external view returns (uint8, uint8);

    // function mptRoot() external view returns (bytes32);

    /// @dev withdraw the protocol fee from the contract, only owner can call this function
    /// @param amount the amount of the withdraw protocol fee
    function Withdraw(uint256 amount, address to) external;

    /// @dev set the payment system address, only owner can call this function
    /// @param gasSystemAddress the address of the payment system
    function setGasSystem(address gasSystemAddress) external;

    function setExpertLaunchHooks(
        bytes1[] calldata ids,
        address[] calldata hooks
    ) external;

    function setExpertLandingHooks(
        bytes1[] calldata ids,
        address[] calldata hooks
    ) external;

    /// notice reset the permission of the contract, only owner can call this function
    function roleConfiguration(
        bytes32 role,
        address[] calldata accounts,
        bool[] calldata states
    ) external;

    function stationAdminSetRole(
        bytes32 role,
        address[] calldata accounts,
        bool[] calldata states
    ) external;

    /// @notice transfer the ownership of the contract, only owner can call this function
    function transferOwnership(address newOwner) external;
}
