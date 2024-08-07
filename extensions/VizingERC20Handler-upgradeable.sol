// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IMessageChannel} from "../interface/IMessageChannel.sol";
import {MessageTypeLib} from "../library/MessageTypeLib.sol";
interface IExpertHook {
    function isETH(address token) external view returns (bool);

    function computeTokenAmountIn(
        uint64 destChainid,
        address token,
        uint256 expectAmountReceive
    ) external view returns (uint256 totalAmount);

    function getTokenInfoBase(
        address tokenAddress
    ) external view returns (TokenBase memory);

    struct TokenBase {
        bytes1 symbol;
        uint8 decimals;
        uint256 maxPrice;
    }
}

abstract contract VizingERC20HandlerUpgradeable {
    struct Context {
        address user;
        uint96 rsv;
    }

    using SafeERC20 for IERC20;

    bytes1 internal constant ERC20_HANDLER = MessageTypeLib.ERC20_HANDLER;

    address internal constant NATIVE_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    IMessageChannel internal _handlerVizingPad;

    function __VizingERC20HandlerInit(address _vizingPad) internal virtual {
        _handlerVizingPad = IMessageChannel(_vizingPad);
    }

    /*
        /// @notice use this function to send the ERC20 token to the destination chain
        /// @param tokenSymbol The token symbol
        /// @param user The sender address of the message
        /// @param tokenSender The handler address of the message
        /// @param amount The amount of tokens to be sent
        /// see https://docs.vizing.com/docs/DApp/Omni-ERC20-Transfer
    */
    function _packetAdditionParams(
        address token,
        address tokenSender,
        uint256 amount
    ) internal view virtual returns (bytes memory) {
        return _packetAdditionParams(token, msg.sender, tokenSender, amount);
    }

    function _packetAdditionParams(
        address token,
        address user,
        address tokenSender,
        uint256 amount
    ) internal view virtual returns (bytes memory) {
        return
            _packetERC20HandlerAdditionParams(token, user, tokenSender, amount);
    }

    function _packetERC20HandlerAdditionParams(
        address token,
        address user,
        address tokenSender,
        uint256 amount
    ) internal view virtual returns (bytes memory) {
        bytes1 tokenSymbol = IExpertHook(_vizingERC20Receiver())
            .getTokenInfoBase(token)
            .symbol;
        return
            abi.encodePacked(
                ERC20_HANDLER,
                tokenSymbol,
                user,
                tokenSender,
                amount
            );
    }

    /*
        /// @notice **Highly recommend** to call this function in your frontend program
        /// @param destChainid The chain id of the destination chain
        /// @param token The token address on the source chain
        /// @param amount The amount of tokens to be sent
        /// see https://docs.vizing.com/docs/DApp/Omni-ERC20-Transfer
    */
    function _computeTokenAmountIn(
        uint64 destChainid,
        address token,
        uint256 amount
    ) internal view virtual returns (uint256 totalAmount) {
        totalAmount = IExpertHook(_vizingERC20Receiver()).computeTokenAmountIn(
            destChainid,
            token,
            amount
        );
        return totalAmount;
    }

    /**
     * @notice approve the erc20 token to VizingERC20Receiver before cross chain transfer
     */
    function _vizingERC20Receiver() internal view returns (address) {
        return _handlerVizingPad.expertLaunchHook(ERC20_HANDLER);
    }
}
