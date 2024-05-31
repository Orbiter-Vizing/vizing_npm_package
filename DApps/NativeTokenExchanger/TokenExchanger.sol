// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {MessageTypeLib} from "@vizing/contracts/library/MessageTypeLib.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenExchanger is Ownable, VizingOmni {
    uint24 private constant GAS_LIMIT = 30000;

    mapping(uint64 => address) public mirrorExchanger;

    constructor(
        address _vizingPad
    ) Ownable(msg.sender) VizingOmni(_vizingPad) {}

    function exchangeAssetExactInput(
        uint64 destinationChainId,
        address tokenReceiver
    ) external payable {
        // Reserve half of msg.value as VizingGasfee.
        // In a production environment, developers need to call LaunchPad.estimateGas to fetch VizingGasfee.
        uint256 amountIn = uint256(msg.value / 2);

        uint256 amountOut = _exactInput(destinationChainId, amountIn);

        bytes memory messageEncoded = abi.encode(tokenReceiver, amountOut);

        address targetContract = mirrorExchanger[destinationChainId];

        bytes memory metadata = _packetMessage(
            bytes1(0x01), // STANDARD_ACTIVATE
            targetContract,
            GAS_LIMIT,
            _fetchPrice(targetContract, destinationChainId),
            messageEncoded
        );

        LaunchPad.Launch{value: msg.value}(
            0,
            0,
            address(0),
            msg.sender,
            amountOut,
            destinationChainId,
            new bytes(0),
            metadata
        );
    }

    function exchangeAssetExactOutput(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 amountOut
    ) external payable {
        uint256 amountIn = _exactOutput(destinationChainId, amountOut);

        require(msg.value > amountIn, "Invalid amount");

        bytes memory messageEncoded = abi.encode(tokenReceiver, amountOut);

        address targetContract = mirrorExchanger[destinationChainId];

        bytes memory metadata = _packetMessage(
            bytes1(0x01), // STANDARD_ACTIVATE
            targetContract,
            GAS_LIMIT,
            _fetchPrice(targetContract, destinationChainId),
            messageEncoded
        );

        LaunchPad.Launch{value: msg.value}(
            0,
            0,
            address(0),
            msg.sender,
            amountOut,
            destinationChainId,
            new bytes(0),
            metadata
        );
    }

    function _receiveMessage(
        uint64 /*srcChainId*/,
        uint256 /*srcContract*/,
        bytes calldata message
    ) internal virtual override {
        (address tokenReceiver, uint256 amountOut) = abi.decode(
            message,
            (address, uint256)
        );

        require(msg.value == amountOut, "Invalid amount");
        // send ether to tokenReceiver
        (bool sent, ) = payable(tokenReceiver).call{value: msg.value}("");
        require(sent, "Failed to send ether");
    }

    function setMirrorExchangers(
        uint64[] calldata chainIds,
        address[] calldata exchangers
    ) external onlyOwner {
        require(chainIds.length == exchangers.length, "Invalid length");

        for (uint256 i = 0; i < chainIds.length; i++) {
            mirrorExchanger[chainIds[i]] = exchangers[i];
        }
    }

    function exactInput(
        uint64 destChainid,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        return _exactInput(destChainid, amountIn);
    }

    function exactOutput(
        uint64 destChainid,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        return _exactOutput(destChainid, amountOut);
    }
}
