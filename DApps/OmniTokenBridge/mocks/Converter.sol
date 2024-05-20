// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import {IColor} from "../VizingTokenBridge.sol";
import {IOminiTokenBridge} from "../interface/IOminiTokenBridge.sol";

contract Converter is IColor {
    function bridgeConvertTokenReceiver(
        bytes calldata
    ) external pure returns (bool) {
        return true;
    }

    function revertTokenwithBridge(
        uint256 amount,
        address toAddress,
        uint64 destChainId,
        address token,
        bytes calldata permitData,
        bytes calldata companionMessage,
        address bridge
    ) external payable {
        IOminiTokenBridge(bridge).bridgeAsset{value: msg.value}(
            destChainId,
            toAddress,
            amount,
            token,
            permitData,
            companionMessage
        );
    }
}
