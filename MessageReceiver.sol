// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMessageChannel} from "./interface/IMessageChannel.sol";
import {IMessageReceiver} from "./interface/IMessageReceiver.sol";

abstract contract MessageReceiver is IMessageReceiver {
    error LandingPadAccessDenied();
    error NotImplement();
    IMessageChannel public LandingPad;

    modifier onlyVizingPad() {
        if (msg.sender != address(LandingPad)) revert LandingPadAccessDenied();
        _;
    }

    constructor(address _LandingPad) {
        __LandingPadInit(_LandingPad);
    }

    /*
        /// rewrite set LandingPad address function
        /// @notice call this function to reset the LaunchPad contract address
        /// @param _LaunchPad The new LaunchPad contract address
    */
    function __LandingPadInit(address _LandingPad) internal virtual {
        LandingPad = IMessageChannel(_LandingPad);
    }

    /// @notice the standard function to receive the omni-chain message
    function receiveStandardMessage(
        uint64 srcChainId,
        uint256 srcContract,
        bytes calldata message
    ) external payable virtual override onlyVizingPad {
        _receiveMessage(srcChainId, srcContract, message);
    }

    /// @dev override this function to handle the omni-chain message
    /// @param srcChainId the source chain id
    /// @param srcContract the source contract address
    /// @param message the message from the source chain
    function _receiveMessage(
        uint64 srcChainId,
        uint256 srcContract,
        bytes calldata message
    ) internal virtual {
        (srcChainId, srcContract, message);
        revert NotImplement();
    }
}
