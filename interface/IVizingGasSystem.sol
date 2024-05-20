// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVizingGasSystem {
    struct PriceConfig {
        FeeConfig feeConfig;
        NativeTokenTradeFeeConfig tradeFee;
        mapping(address => NativeTokenTradeFeeConfig) tradeFeeConfigMap;
        mapping(address => uint64) dAppConfigMap;
    }

    struct ExchangeRate {
        uint56 molecular;
        uint56 denominator;
        uint8 molecularDecimal;
        uint8 denominatorDecimal;
    }

    struct FeeConfig {
        uint64 basePrice;
        uint64 reserve;
        uint56 molecular;
        uint56 denominator;
        uint8 molecularDecimal;
        uint8 denominatorDecimal;
    }

    struct NativeTokenTradeFeeConfig {
        uint128 molecular;
        uint128 denominator;
    }

    event GlobalBasePriceSet(uint64 price);

    event DefaultGasLimitSet(uint24 gasLimit);

    event ChainPriceConfigSet(uint64 chainid, uint64 basePrice);

    event DAppPriceConfigSet(uint64 chainid, address dApp, uint64 basePrice);

    function setManager(
        bytes32 role,
        address[] calldata accounts,
        bool[] calldata states
    ) external;

    function transferOwnership(address newOwner) external;

    function setGlobalBasePrice(uint64 price) external;

    function setDefaultGasLimit(uint24 gasLimit) external;

    function setChainPriceConfig(uint64 chainid, uint64 basePrice) external;

    function setTokenFeeConfig(uint128 molecular, uint128 denominator) external;

    function batchSetTokenFeeConfig(
        uint64[] calldata destChainid,
        uint128[] calldata molecular,
        uint128[] calldata denominator
    ) external;

    function batchSetTradeFeeConfigMap(
        uint64[] calldata destChainid,
        address[] calldata dApps,
        uint128[] calldata molecular,
        uint128[] calldata denominator
    ) external;

    function getTradeFeeConfigMap(
        uint64 chainid,
        address dApp
    ) external view returns (NativeTokenTradeFeeConfig memory);

    function getTokenFeeConfig(
        uint64 chainid
    ) external view returns (NativeTokenTradeFeeConfig memory);

    function getDAppConfigMap(
        uint64 chainid,
        address dApp
    ) external view returns (uint64 basePrice);

    function batchSetChainPriceConfig(
        uint64[] calldata chainid,
        uint64[] calldata basePrice
    ) external;

    function setDAppPriceConfig(
        uint64 chainid,
        address dApp,
        uint64 basePrice
    ) external;

    function setAmountInThreshold(uint256 newValue) external;

    function batchSetAmountInThreshold(
        uint64[] calldata chainid,
        uint256[] calldata newValue
    ) external;

    function getAmountInThreshold(
        uint64 chainid
    ) external view returns (uint256);

    function batchSetDAppPriceConfigInDiffChain(
        uint64[] calldata chainid,
        address[] calldata dApps,
        uint64[] calldata basePrices
    ) external;

    function batchSetDAppPriceConfigInSameChain(
        uint64 chainid,
        address[] calldata dApps,
        uint64[] calldata basePrices
    ) external;

    function setExchangeRate(
        uint64 chainid,
        ExchangeRate calldata exchangeRate
    ) external;

    function batchSetExchangeRate(
        uint64[] calldata chainid,
        ExchangeRate[] calldata exchangeRates
    ) external;
}
