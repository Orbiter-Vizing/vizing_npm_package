// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// import {VizingOmniUpgradeable} from "@vizing/contracts/VizingOmni-upgradeable.sol";
import {VizingOmniUpgradeable} from "../../VizingOmni-upgradeable.sol";
import {VizingERC20HandlerUpgradeable} from "../../extensions/VizingERC20Handler-upgradeable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol"; // just for debugging

contract SimultaneousTokenTransfer is
    Ownable,
    VizingOmniUpgradeable,
    VizingERC20HandlerUpgradeable
{
    using SafeERC20 for IERC20;
    uint24 private constant GAS_LIMIT = 80000;
    bytes1 constant BRIDGE_MODE = 0x01;
    uint64 public immutable override minArrivalTime;
    uint64 public immutable override maxArrivalTime;
    address public immutable override selectedRelayer;

    mapping(uint64 => address) public mirrorMessage;

    receive() external payable {}

    constructor(address _vizingPad) Ownable(msg.sender) {
        __VizingOmniInit(_vizingPad);
        __VizingERC20HandlerInit(_vizingPad);
    }

    function setMirrorMessage(
        uint64 chainId,
        address messageContract
    ) external onlyOwner {
        mirrorMessage[chainId] = messageContract;
    }

    function bridgeMessageWithTokenTransfer(
        uint64 destChainId,
        address token,
        uint256 amount,
        string memory sendMessage
    ) external payable {
        address tokenSender = address(this);
        {
            // step 1: Approve ERC20 token to VizingERC20Receiver
            // Warming: please confirm the amount of approvement, **DO NOT USE** uint256 MAX
            if (token != NATIVE_ADDRESS) {
                IERC20(token).safeTransferFrom(msg.sender, tokenSender, amount);
                IERC20(token).approve(_vizingERC20Receiver(), amount);
            }
        }

        // step 2: Encode ERC20 transfer params
        bytes memory additionParams = _packetAdditionParams(
            token,
            tokenSender,
            amount
        );

        // setp 3: Encode message, basicly your business logic
        bytes memory message = _packetMessage(
            BRIDGE_MODE,
            mirrorMessage[destChainId],
            GAS_LIMIT,
            _fetchPrice(destChainId),
            abi.encode(sendMessage)
        );

        uint256 valueOut = token == NATIVE_ADDRESS ? amount : 0;

        // step 4: Send Omni-chain message to Vizing LaunchPad
        LaunchPad.Launch{value: msg.value}(
            minArrivalTime,
            maxArrivalTime,
            selectedRelayer,
            msg.sender,
            valueOut,
            destChainId,
            additionParams,
            message
        );
    }

    function computeTokenAmountIn(
        uint64 destChainid,
        address token,
        uint256 amount
    ) external view returns (uint256) {
        return _computeTokenAmountIn(destChainid, token, amount);
    }

    function fetchTransferFee(
        uint64 destChainid,
        address token,
        uint256 amount,
        string memory sendMessage
    ) public view returns (uint256) {
        // additionParams encode
        bytes memory additionParams = _packetAdditionParams(
            token,
            msg.sender,
            address(this),
            amount
        );
        bytes memory encodeMessage = abi.encode(sendMessage);
        bytes memory message = _packetMessage(
            BRIDGE_MODE,
            mirrorMessage[destChainid],
            GAS_LIMIT,
            _fetchPrice(destChainid),
            encodeMessage
        );
        return _estimateVizingGasFee(0, destChainid, additionParams, message);
    }

    function _receiveMessage(
        uint64,
        /*srcChainId*/ uint256,
        /*srcContract*/ bytes calldata message
    ) internal virtual override {
        // string memory m = abi.decode(message, (string));
        // console.logString(m);
    }
}
