// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageStruct} from "./IMessageStruct.sol";

interface IMessageSimulation is IMessageStruct {
    /// @dev for sequencer to simulate the landing message, call this function before call Landing
    /// @param params the landing message params
    /// check the revert message "SimulateResult" to get the result of the simulation
    /// for example, if the result is [true, false, true], it means the first and third message is valid, the second message is invalid
    function SimulateLanding(landingParams[] calldata params) external payable;

    /// @dev call this function off-chain to estimate the gas of excute the landing message
    /// @param params the landing message params
    /// @return the result of the estimation, true is valid, false is invalid
    function EstimateExecuteGas(
        landingParams[] calldata params
    ) external returns (bool[] memory);
}
