// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageStruct} from "./IMessageStruct.sol";
import {IMessageSpaceStation} from "./IMessageSpaceStation.sol";

interface IExpertHook {
    struct TokenTradeFeeConfig {
        uint128 molecular;
        uint128 denominator;
    }

    struct TokenBase {
        bytes1 symbol;
        uint8 decimals;
        uint256 maxPrice;
    }

    struct TokenInfo {
        TokenBase base;
        mapping(uint64 destChainId => TokenTradeFeeConfig) tradeFeeMap;
    }

    // event VizingPadSet(address _vizingPadLaunch, address _vizingPadLanding);
    // event DefaultGasLimitSet(uint24 gasLimit);

    function setVizingPadAddress(
        address _vizingPadLaunch,
        address _vizingPadLanding
    ) external;

    function setManager(
        bytes32 role,
        address[] calldata accounts,
        bool[] calldata states
    ) external;

    function setDefaultGasLimit(uint24 gasLimit) external;

    function setGlobalTradeFee(uint128 molecular, uint128 denominator) external;

    function withdraw(address token, uint256 amount) external;

    function isETH(address token) external view returns (bool);

    function computeTotalAmont(
        uint64 destChainid,
        address token,
        uint256 expectAmountReceive
    ) external view returns (uint256 totalAmount);

    function setTokenInfoBase(
        bytes1 symbol,
        address tokenAddress,
        uint8 decimals,
        uint256 maxPrice
    ) external;

    function setTokenTradeFeeMap(
        address tokenAddress,
        uint64[] calldata chainId,
        uint128[] calldata molecular,
        uint128[] calldata denominator
    ) external;

    function getTokenInfoBase(
        address tokenAddress
    ) external view returns (TokenBase memory);

    function getTokenAddressBySymbol(
        bytes1 symbol
    ) external view returns (address tokenAddress);

    function handleLaunch(
        bytes calldata vizingPadCalldata
    ) external returns (bool success, bytes memory);

    function handleLanding(
        IMessageSpaceStation.landingParams calldata params
    ) external returns (bool success, bytes memory);
}

interface IExpertHookTransfer {
    function tokenTransferByHook(
        address token,
        address reveiver,
        uint256 amount
    ) external payable;
}

contract ExpertHookTransfer is IExpertHookTransfer {
    function tokenTransferByHook(
        address token,
        address reveiver,
        uint256 amount
    ) external payable virtual {
        _tokenTransferByHook(token, reveiver, amount);
    }

    function _tokenTransferByHook(
        address token,
        address reveiver,
        uint256 amount
    ) internal virtual {}
}
