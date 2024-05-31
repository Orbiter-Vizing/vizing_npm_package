// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// import {VizingOmniUpgradeable} from "@vizing/contracts/VizingOmni-upgradeable.sol";
import {VizingOmniUpgradeable} from "../../VizingOmni-upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IExpertHook, ExpertHookTransfer} from "../../interface/IExpertHook.sol";

import "hardhat/console.sol"; // just for debugging

contract SimultaneousTokenTransfer is
    Ownable,
    VizingOmniUpgradeable,
    ExpertHookTransfer
{
    using SafeERC20 for IERC20;

    error Transfer_To_Hook();

    uint24 private constant GAS_LIMIT = 80000;

    bytes1 constant ERC20_HANDLER = 0x03;
    bytes1 constant BRIDGE_MODE = 0x01;

    uint64 public immutable override minArrivalTime;
    uint64 public immutable override maxArrivalTime;
    address public immutable override selectedRelayer;

    mapping(uint64 => address) public mirrorMessage;

    address vizingPad;

    receive() external payable {}

    constructor(address _vizingPad) Ownable(msg.sender) {
        __VizingOmniInit(_vizingPad);
    }

    function setMirrorMessage(
        uint64 chainId,
        address messageContract
    ) external onlyOwner {
        mirrorMessage[chainId] = messageContract;
    }

    function computeTotalAmont(
        uint64 destChainid,
        address token,
        uint256 amount
    ) public view returns (uint256 totalAmount) {
        totalAmount = IExpertHook(LaunchPad.expertLaunchHook(ERC20_HANDLER))
            .computeTotalAmont(destChainid, token, amount);
    }

    function bridgeMessageWithTokenTransfer(
        uint64 destChainId,
        address token,
        uint256 amount,
        string memory sendMessage
    ) external payable {
        uint256 totalAmount = computeTotalAmont(destChainId, token, amount);
        bool isETH = IExpertHook(LaunchPad.expertLaunchHook(ERC20_HANDLER))
            .isETH(token);
        _tokenHandlingStrategy(
            token,
            msg.sender,
            address(this),
            totalAmount,
            isETH
        );

        // additionParams encode
        bytes memory additionParams = _packetAdditionParams(
            ERC20_HANDLER,
            IExpertHook(LaunchPad.expertLaunchHook(ERC20_HANDLER))
                .getTokenInfoBase(token)
                .symbol,
            msg.sender,
            address(this),
            amount
        );

        bytes memory encodeMessage = abi.encode(sendMessage);
        bytes memory message = _packetMessage(
            BRIDGE_MODE,
            mirrorMessage[destChainId],
            GAS_LIMIT,
            _fetchPrice(destChainId),
            encodeMessage
        );

        uint256 padValue = isETH ? msg.value - totalAmount : msg.value;

        this.Launch{value: padValue}(
            msg.sender,
            destChainId,
            additionParams,
            message
        );
    }

    function Launch(
        address sender,
        uint64 destinationChainId,
        bytes calldata additionParams,
        bytes calldata metadata
    ) public payable {
        require(msg.sender == address(this), "invalid sender");
        LaunchPad.Launch{value: msg.value}(
            0,
            0,
            address(0),
            sender,
            0,
            destinationChainId,
            additionParams,
            metadata
        );
    }

    function _tokenHandlingStrategy(
        address token,
        address sender,
        address reveiver,
        uint256 amount,
        bool isETH
    ) private {
        if (!isETH) {
            require(
                IERC20(token).allowance(sender, reveiver) >= amount,
                "Token allowance too low"
            );
            IERC20(token).safeTransferFrom(sender, reveiver, amount);
        }
    }

    function fetchTransferFee(
        uint64 destChainid,
        address token,
        uint256 amount,
        string memory sendMessage
    ) public view returns (uint256) {
        // additionParams encode
        bytes memory additionParams = _packetAdditionParams(
            ERC20_HANDLER,
            IExpertHook(LaunchPad.expertLaunchHook(ERC20_HANDLER))
                .getTokenInfoBase(token)
                .symbol,
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

    function _tokenTransferByHook(
        address token,
        address reveiver,
        uint256 amount
    ) internal virtual override {
        require(
            msg.sender == LaunchPad.expertLaunchHook(ERC20_HANDLER),
            "expertLaunchHook"
        );
        if (
            IExpertHook(LaunchPad.expertLaunchHook(ERC20_HANDLER)).isETH(token)
        ) {
            (bool sent, ) = payable(reveiver).call{value: amount}("");
            if (!sent) {
                revert Transfer_To_Hook();
            }
        } else {
            IERC20(token).safeTransfer(reveiver, amount);
        }
    }

    function _receiveMessage(
        uint64,
        /*srcChainId*/ uint256,
        /*srcContract*/ bytes calldata message
    ) internal virtual override {
        string memory m = abi.decode(message, (string));
        console.logString(m);
    }
}
