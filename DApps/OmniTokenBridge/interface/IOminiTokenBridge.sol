// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IOminiTokenBridge {
    // Wrapped Token information struct
    struct TokenInformation {
        uint64 originChainId;
        address originTokenAddress;
    }

    /**
     * @dev Emitted when a token is bridged to another chain
     */
    event BridgeAsset(
        uint64 destinationChainId,
        address destinationAddress,
        uint256 amount,
        address token
    );

    /**
     * @dev Emitted when a new wrapped token is created
     */
    event NewWrappedToken(
        uint64 originChainId,
        address originTokenAddress,
        address wrappedTokenAddress,
        string name,
        string symbol,
        uint8 decimals
    );

    /*
        /// @similar to bridgeAsset, but gas friendly.call fetchBridgeAssetDetails to get the encodedMessage
        /// @notice Function to Send ERC20 tokens to another chain
        /// @param destinationChainId The destination chain id
        /// @param tokenReceiver The address of the receiver on the destination chain
        /// @param amount The amount of tokens to be sent
        /// @param token The address of the token to be sent
        /// @param permitData The data of the permit function of the token
        /// @param companionMessage A companion message to send to the tokenReceiver
    */
    function bridgeAsset(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 amount,
        address token,
        bytes calldata permitData,
        bytes calldata companionMessage
    ) external payable;

    /*
        /// @notice Function to estimate the fee of sending tokens to another chain
        /// @param destinationChainId The destination chain id
        /// @param destinationAddress The address of the receiver on the destination chain
        /// @param amount The amount of tokens to be sent
        /// @param token The address of the token to be sent
        /// @return gasFee The fee of sending tokens to another chain
        /// @return companionMessage A companion message to send to the destinationAddress
    */
    function fetchBridgeAssetDetails(
        uint64 destinationChainId,
        address destinationAddress,
        uint256 amount,
        address token,
        bytes calldata companionMessage
    ) external view returns (uint256 gasFee, bytes memory encodedMessage);

    /*
        /// @notice Function to predict the address of the token on the destination chain
        /// @notice This function should be called at the destination chain
        /// @param targetChainId The destination chain id
        /// @param originChainId The origin chain id
        /// @param originTokenAddress The address of the token to be wrapped
        /// @param name The name of the token on source chain
        /// @param symbol The symbol of the token on source chain
        /// @param decimals The decimals of the token on source chain
        /// @return wrappedTokenAddress The address of the wrapped token on the destination chain
    */
    function predictTokenAddress(
        uint64 destinationChainId,
        uint64 originChainId,
        address originTokenAddress,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external view returns (address wrappedTokenAddress);

    /*
        /// @notice Function to build security message to unlock tokens
        /// @param originTokenAddress The address of the token to be unlocked
        /// @param tokenReceiver The address of the receiver on the destination chain
        /// @param amount The amount of tokens to be unlocked
        /// @return unLockMessage The security message to unlock tokens
    */
    function fetchUnLockDetails(
        uint64 destinationChainId,
        address originTokenAddress,
        address tokenReceiver,
        uint256 amount
    ) external view returns (uint256 fee, bytes memory unLockMessage);
}
