// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageStruct} from "./interface/IMessageStruct.sol";
import {IMessageChannel} from "./interface/IMessageChannel.sol";
import {IMessageEmitter} from "./interface/IMessageEmitter.sol";
import {IMessageReceiver} from "./interface/IMessageReceiver.sol";
import {IVizingGasSystemChannel} from "./interface/IVizingGasSystemChannel.sol";

abstract contract MessageEmitter is IMessageEmitter {
    /// @dev bellow are the default parameters for the OmniToken,
    ///      we **Highly recommended** to use immutable variables to store these parameters
    /// @notice minArrivalTime the minimal arrival timestamp for the omni-chain message
    /// @notice maxArrivalTime the maximal arrival timestamp for the omni-chain message
    /// @notice minGasLimit the minimal gas limit for target chain execute omni-chain message
    /// @notice maxGasLimit the maximal gas limit for target chain execute omni-chain message
    /// @notice defaultBridgeMode the default mode for the omni-chain message,
    ///        in OmniToken, we use MessageTypeLib.ARBITRARY_ACTIVATE (0x02), target chain will **ACTIVATE** the message
    /// @notice selectedRelayer the specify relayer for your message
    ///        set to 0, all the relayers will be able to forward the message
    /// see https://docs.vizing.com/docs/BuildOnVizing/Contract

    function minArrivalTime() external view virtual override returns (uint64) {}

    function maxArrivalTime() external view virtual override returns (uint64) {}

    function minGasLimit() external view virtual override returns (uint24) {}

    function maxGasLimit() external view virtual override returns (uint24) {}

    function defaultBridgeMode()
        external
        view
        virtual
        override
        returns (bytes1)
    {}

    function selectedRelayer()
        external
        view
        virtual
        override
        returns (address)
    {}

    IMessageChannel public LaunchPad;

    constructor(address _LaunchPad) {
        __LaunchPadInit(_LaunchPad);
    }

    /*
        /// rewrite set LaunchPad address function
        /// @notice call this function to reset the LaunchPad contract address
        /// @param _LaunchPad The new LaunchPad contract address
    */
    function __LaunchPadInit(address _LaunchPad) internal virtual {
        LaunchPad = IMessageChannel(_LaunchPad);
    }

    /*
        /// @notice call this function to packet the message before sending it to the LandingPad contract
        /// @param mode the emitter mode, check MessageTypeLib.sol for more details
        ///        eg: 0x02 for ARBITRARY_ACTIVATE, your message will be activated on the target chain
        /// @param gasLimit the gas limit for executing the specific function on the target contract
        /// @param targetContract the target contract address on the destination chain
        /// @param message the message to be sent to the target contract
        /// @return the packed message
        /// see https://docs.vizing.com/docs/BuildOnVizing/Contract
    */
    function _packetMessage(
        bytes1 mode,
        address targetContract,
        uint24 gasLimit,
        uint64 price,
        bytes memory message
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                mode,
                uint256(uint160(targetContract)),
                gasLimit,
                price,
                message
            );
    }

    /*
        /// @notice use this function to send the ERC20 token to the destination chain
        /// @param tokenSymbol The token symbol
        /// @param sender The sender address for the message
        /// @param receiver The receiver address for the message
        /// @param amount The amount of tokens to be sent
        /// see https://docs.vizing.com/docs/DApp/Omni-ERC20-Transfer
    */
    function _packetAdditionParams(
        bytes1 mode,
        bytes1 tokenSymbol,
        address sender,
        address receiver,
        uint256 amount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(mode, tokenSymbol, sender, receiver, amount);
    }

    /*
        /// @notice Calculate the amount of native tokens obtained on the target chain
        /// @param value The value we send to vizing on the source chain
    */
    function _computeTradeFee(
        uint64 destChainid,
        uint256 value
    ) internal view returns (uint256 amountIn) {
        return
            IVizingGasSystemChannel(LaunchPad.gasSystemAddr()).computeTradeFee(
                destChainid,
                value
            );
    }

    /*
        /// @notice Fetch the nonce of the user with specific destination chain
        /// @param destChainid The chain id of the destination chain
        /// see https://docs.vizing.com/docs/BuildOnVizing/Contract
    */
    function _fetchNonce(
        uint64 destChainid
    ) internal view virtual returns (uint32 nonce) {
        nonce = LaunchPad.GetNonceLaunch(destChainid, msg.sender);
    }

    /*
        /// @notice Estimate the gas price we need to encode in message
        /// @param destChainid The chain id of the destination chain
        /// see https://docs.vizing.com/docs/BuildOnVizing/Contract
    */
    function _fetchPrice(
        uint64 destChainid
    ) internal view virtual returns (uint64) {
        return
            IVizingGasSystemChannel(LaunchPad.gasSystemAddr()).estimatePrice(
                destChainid
            );
    }

    /*
        /// @notice Estimate the gas price we need to encode in message
        /// @param targetContract The target contract address on the destination chain
        /// @param destChainid The chain id of the destination chain
        /// see https://docs.vizing.com/docs/BuildOnVizing/Contract
    */
    function _fetchPrice(
        address targetContract,
        uint64 destChainid
    ) internal view virtual returns (uint64) {
        return
            IVizingGasSystemChannel(LaunchPad.gasSystemAddr()).estimatePrice(
                targetContract,
                destChainid
            );
    }

    /*
        /// @notice similar to uniswap Swap Router
        /// @notice Estimate how many native token we should spend to exchange the amountOut in the destChainid
        /// @param destChainid The chain id of the destination chain
        /// @param amountOut The value we want to exchange in the destination chain
        /// @return amountIn the native token amount on the source chain we should spend
        /// see https://docs.vizing.com/docs/BuildOnVizing/Contract
    */
    function _exactOutput(
        uint64 destChainid,
        uint256 amountOut
    ) internal view returns (uint256 amountIn) {
        return
            IVizingGasSystemChannel(LaunchPad.gasSystemAddr()).exactOutput(
                destChainid,
                amountOut
            );
    }

    /*
        /// @notice similar to uniswap Swap Router
        /// @notice Estimate how many native token we could get in the destChainid if we input the amountIn
        /// @param destChainid The chain id of the destination chain
        /// @param amountIn The value we spent in the source chain
        /// @return amountOut the native token amount the destination chain will receive
        /// see https://docs.vizing.com/docs/BuildOnVizing/Contract
    */
    function _exactInput(
        uint64 destChainid,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        return
            IVizingGasSystemChannel(LaunchPad.gasSystemAddr()).exactInput(
                destChainid,
                amountIn
            );
    }

    /*
        /// @notice Estimate the gas price we need to encode in message
        /// @param value The native token that value target address will receive in the destination chain
        /// @param destChainid The chain id of the destination chain
        /// @param additionParams The addition params for the message
        ///        if not in expert mode, set to 0 (`new bytes(0)`)
        /// @param message The message we want to send to the destination chain
        /// see https://docs.vizing.com/docs/BuildOnVizing/Contract
    */
    function _estimateVizingGasFee(
        uint256 value,
        uint64 destChainid,
        bytes memory additionParams,
        bytes memory message
    ) internal view returns (uint256 vizingGasFee) {
        return
            LaunchPad.estimateGas(value, destChainid, additionParams, message);
    }

    /*  
        /// @notice **Highly recommend** to call this function in your frontend program
        /// @notice Estimate the gas price we need to encode in message
        /// @param value The native token that value target address will receive in the destination chain
        /// @param destChainid The chain id of the destination chain
        /// @param additionParams The addition params for the message
        ///        if not in expert mode, set to 0 (`new bytes(0)`)
        /// @param message The message we want to send to the destination chain
        /// see https://docs.vizing.com/docs/BuildOnVizing/Contract
    */
    function estimateVizingGasFee(
        uint256 value,
        uint64 destChainid,
        bytes calldata additionParams,
        bytes calldata message
    ) external view returns (uint256 vizingGasFee) {
        return
            _estimateVizingGasFee(value, destChainid, additionParams, message);
    }
}
