// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IOmniNFTBridge {
    // Wrapped Token information struct
    struct TokenInformation {
        uint64 originChainId;
        address originTokenAddress;
    }

    /**
     * @dev Emitted when a new wrapped token is created
     */
    event NewWrappedToken(
        uint64 originChainId,
        address originTokenAddress,
        address wrappedTokenAddress,
        string name,
        string symbol,
        string uri
    );

    /*
        /// @notice Function to Send ERC721 (NFT) tokens to another chain
        /// @param destinationChainId The destination chain id
        /// @param tokenReceiver The address of the receiver on the destination chain
        /// @param tokenId The id of the token to be sent
        /// @param token The address of the token to be sent
        /// @param baseURI The base uri of the token, could be empty
        /// @param companionMessage The additional message to be sent
    */
    function bridgeAsset(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token,
        string calldata baseURI,
        bytes calldata companionMessage
    ) external payable;

    /*
        /// @notice Function to estimate the fee of sending tokens to another chain
        /// @param destinationChainId The destination chain id
        /// @param destinationAddress The address of the receiver on the destination chain
        /// @param tokenReceiver The address of the receiver on the destination chain
        /// @param tokenId The id of the token to be sent
        /// @param token The address of the token to be sent
        /// @param companionMessage The additional message to be sent
        /// @return The fee of sending tokens to another chain
        /// @return The encoded message
    */
    function fetchBridgeAssetDetails(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token,
        bytes calldata companionMessage
    ) external view returns (uint256 gasFee, bytes memory encodedMessage);

    function predictNFTAddress(
        uint64 destinationChainId,
        uint64 originChainId,
        address originTokenAddress,
        string memory name,
        string memory symbol
    ) external view returns (address);
}
