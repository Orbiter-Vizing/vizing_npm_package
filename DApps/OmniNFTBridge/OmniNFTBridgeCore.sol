// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IOmniNFTBridge} from "./interface/IOmniNFTBridge.sol";
import {ICompanionMessage} from "./interface/ICompanionMessage.sol";
import {MetaUtils} from "./library/MetaUtils.sol";

contract OmniNFTBridgeCore is VizingOmni, IOmniNFTBridge, IERC721Receiver {
    error NotImplemented();
    error NotBridgeMessage();
    error DataLengthError();
    error FailedCall();

    using MetaUtils for address;

    uint24 public immutable DEFAULT_GASLIMIT;

    bytes1 private constant BRIDGE_SEND_MODE = 0x01;

    bytes1 private constant UNLOCK_MODE = 0x02;

    uint64 private immutable currentChainId;

    // keccak256(OriginNetwork || tokenAddress) --> Wrapped token address
    mapping(bytes32 => address) public tokenInfoToWrappedToken;

    // Wrapped token Address --> Origin token information
    mapping(address => TokenInformation) public wrappedTokens;

    mapping(uint64 => address) public mirrorBridge;

    mapping(uint64 => address) public mirrorGovernor;

    constructor(
        address _vizingPad,
        uint64 _deployChainId
    ) VizingOmni(_vizingPad) {
        currentChainId = _deployChainId;
        DEFAULT_GASLIMIT = 2000000;
    }

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
    ) public payable virtual override {
        {
            _bridgeAssetHandlingStrategy(
                destinationChainId,
                tokenReceiver,
                tokenId,
                token
            );
        }

        bytes memory metadata;
        {
            metadata = fetchBridgeAssetMessage(
                destinationChainId,
                tokenReceiver,
                tokenId,
                token,
                baseURI,
                companionMessage
            );
        }
        this.Launch{value: msg.value}(msg.sender, destinationChainId, metadata);
    }

    function Launch(
        address sender,
        uint64 destinationChainId,
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
            new bytes(0),
            metadata
        );
    }

    function _bridgeAssetHandlingStrategy(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token
    ) internal {
        _bridgeSendCallback(destinationChainId, tokenReceiver, tokenId, token);
        TokenInformation memory tokenInfo = wrappedTokens[token];
        // check if token is wrapped-token
        if (tokenInfo.originTokenAddress != address(0)) {
            // The token is a wrapped token from another network
            _storeAsset(token, tokenId);
        } else {
            IERC721(token).safeTransferFrom(msg.sender, address(this), tokenId);
        }
    }

    function fetchBridgeAssetMessage(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token,
        string calldata baseURI,
        bytes calldata companionMessage
    ) public view returns (bytes memory encodedMessage) {
        address originTokenAddress;
        uint64 originChainId;
        {
            TokenInformation memory tokenInfo = wrappedTokens[token];

            // check if token is wrapped-token
            if (tokenInfo.originTokenAddress != address(0)) {
                // The token is a wrapped token from another network
                originTokenAddress = tokenInfo.originTokenAddress;
                originChainId = tokenInfo.originChainId;
            } else {
                originTokenAddress = token;
                originChainId = currentChainId;
            }
        }

        bytes memory metadata = _encodeMetadata(
            BRIDGE_SEND_MODE,
            originTokenAddress,
            originChainId,
            tokenReceiver,
            tokenId,
            token,
            baseURI,
            companionMessage
        );
        address targetContract = mirrorBridge[destinationChainId];
        uint64 price = _fetchPrice(targetContract, destinationChainId);
        encodedMessage = _packetMessage(
            BRIDGE_SEND_MODE, // STANDARD_ACTIVATE
            targetContract,
            DEFAULT_GASLIMIT,
            price,
            metadata
        );
    }

    function fetchBridgeAssetMessage(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token,
        bytes calldata companionMessage
    ) public view returns (bytes memory encodedMessage) {
        address originTokenAddress;
        uint64 originChainId;
        TokenInformation memory tokenInfo = wrappedTokens[token];

        // check if token is wrapped-token
        if (tokenInfo.originTokenAddress != address(0)) {
            // The token is a wrapped token from another network
            originTokenAddress = tokenInfo.originTokenAddress;
            originChainId = tokenInfo.originChainId;
        } else {
            originTokenAddress = token;
            originChainId = currentChainId;
        }

        bytes memory metadata = _encodeMetadata(
            BRIDGE_SEND_MODE,
            originTokenAddress,
            originChainId,
            tokenReceiver,
            tokenId,
            token,
            "",
            companionMessage
        );
        address targetContract = mirrorBridge[destinationChainId];
        uint64 price = _fetchPrice(targetContract, destinationChainId);
        encodedMessage = _packetMessage(
            BRIDGE_SEND_MODE, // STANDARD_ACTIVATE
            targetContract,
            DEFAULT_GASLIMIT,
            price,
            metadata
        );
    }

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
    ) public view returns (uint256 gasFee, bytes memory encodedMessage) {
        encodedMessage = fetchBridgeAssetMessage(
            destinationChainId,
            tokenReceiver,
            tokenId,
            token,
            companionMessage
        );

        gasFee = _estimateVizingGasFee(
            0,
            destinationChainId,
            new bytes(0),
            encodedMessage
        );
    }

    function predictNFTAddress(
        uint64 destinationChainId,
        uint64 originChainId,
        address originTokenAddress,
        string memory name,
        string memory symbol
    ) external view virtual override returns (address) {
        (destinationChainId, originChainId, name, symbol);
        if (originTokenAddress != address(0)) {
            revert NotImplemented();
        }
        return address(0);
    }

    /*
        /// @notice Function to receive the message from another chain
            (in this case, the message contains the information of the token to be claimed)
        /// @param message The message from the source chain
    */
    function _receiveMessage(
        uint64 srcChainId,
        uint256 srcContract,
        bytes calldata message
    ) internal virtual override {
        bytes1 mode = bytes1(bytes32(message[0:32]));
        if (mode == BRIDGE_SEND_MODE) {
            if (mirrorBridge[srcChainId] != address(uint160(srcContract))) {
                revert NotBridgeMessage();
            }
            address _tokenReceiver;
            bytes memory _companionMessage;
            {
                (
                    ,
                    address originTokenAddress,
                    uint64 originChainId,
                    address tokenReceiver,
                    uint256 tokenId,
                    string memory name,
                    string memory symbol,
                    string memory baseURI,
                    bytes memory companionMessage
                ) = abi.decode(
                        message,
                        (
                            bytes1,
                            address,
                            uint64,
                            address,
                            uint256,
                            string,
                            string,
                            string,
                            bytes
                        )
                    );

                _claimAssetHandler(
                    originChainId,
                    originTokenAddress,
                    tokenReceiver,
                    tokenId,
                    name,
                    symbol,
                    baseURI
                );
                _tokenReceiver = tokenReceiver;
                _companionMessage = companionMessage;
            }

            if (_companionMessage.length > 0) {
                bool success = ICompanionMessage(_tokenReceiver)
                    .handlerBridgeCompanionMessage(_companionMessage);
                if (!success) {
                    revert FailedCall();
                }
            }
        } else if (mode == UNLOCK_MODE) {
            if (mirrorGovernor[srcChainId] != address(uint160(srcContract))) {
                revert NotBridgeMessage();
            }
            (
                ,
                address originTokenAddress,
                address tokenReceiver,
                uint256 tokenId
            ) = abi.decode(message, (bytes1, address, address, uint256));
            IERC721(originTokenAddress).safeTransferFrom(
                address(this),
                tokenReceiver,
                tokenId
            );
        }
    }

    function _claimAssetHandler(
        uint64 originChainId,
        address originTokenAddress,
        address tokenReceiver,
        uint256 tokenId,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) internal returns (address wrappedToken) {
        // Transfer tokens
        if (originChainId == currentChainId) {
            // The token is an ERC20 from this network
            IERC721(originTokenAddress).safeTransferFrom(
                address(this),
                tokenReceiver,
                tokenId
            );
        } else {
            // The tokens is not from this network
            // Create a wrapper for the token if not exist yet
            bytes32 tokenInfoHash = keccak256(
                abi.encodePacked(originChainId, originTokenAddress)
            );
            wrappedToken = tokenInfoToWrappedToken[tokenInfoHash];

            if (wrappedToken == address(0)) {
                // Create a new wrapped erc20 using create2

                wrappedToken = _deployContract(
                    tokenInfoHash,
                    name,
                    symbol,
                    baseURI
                );

                // Mint tokens for the destination address
                _claimAsset(wrappedToken, tokenReceiver, tokenId);

                // Create mappings
                tokenInfoToWrappedToken[tokenInfoHash] = wrappedToken;

                // wrappedToken = address(newWrappedToken);
                wrappedTokens[wrappedToken] = TokenInformation(
                    originChainId,
                    originTokenAddress
                );
                emit NewWrappedToken(
                    originChainId,
                    originTokenAddress,
                    wrappedToken,
                    name,
                    symbol,
                    baseURI
                );
            } else {
                // Use the existing wrapped erc20
                _claimAsset(wrappedToken, tokenReceiver, tokenId);
            }
        }
    }

    function _encodeMetadata(
        bytes1 mode,
        address originTokenAddress,
        uint64 originChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token,
        string memory baseURI,
        bytes calldata companionMessage
    ) public view returns (bytes memory encodedMessage) {
        encodedMessage = abi.encode(
            mode,
            originTokenAddress,
            originChainId,
            tokenReceiver,
            tokenId,
            token._safeName(),
            token._safeSymbol(),
            baseURI,
            companionMessage
        );
    }

    /*
        /// @notice override this function to implement the callback function before the bridgeAsset function is executed
        /// @notice Function to be called before the bridgeAsset function is executed
        /// @param destinationChainId The destination chain id
        /// @param tokenReceiver The address of the receiver on the destination chain
        /// @param amount The amount of tokens to be sent
        /// @param token The address of the token to be sent
    */
    function _bridgeSendCallback(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token
    ) internal virtual {
        (destinationChainId, tokenId, token);
        if (tokenReceiver != address(0)) {
            revert NotImplemented();
        }
    }

    /*
        /// @notice override this function to implement the callback function after the claimAsset function is successful
        /// @notice Function to be called after the claimAsset function is successful
        /// @param wrappedToken The address of the wrapped token
    */
    function _claimSuccessCallback(
        uint64 srcChainId,
        address sender,
        address wrappedToken
    ) internal virtual {
        (srcChainId, sender, wrappedToken);
        if (wrappedToken != address(0)) {
            revert NotImplemented();
        }
    }

    /*
        /// @notice please override this function to deploy the contract on destination chain
        /// @param salt The salt for the contract deployment
        /// @param name The name of the token
        /// @param symbol The symbol of the token
        /// @param decimals The decimals of the token
    */
    function _deployContract(
        bytes32 salt,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) internal virtual returns (address) {
        (salt, name, symbol, baseURI);
        if (salt != 0) {
            revert NotImplemented();
        }
        return address(0);
    }

    /*
        /// @notice please override this function to claim the asset
        /// @notice Function to claim the asset
        /// @param token The address of the token
        /// @param tokenReceiver The address of the receiver
        /// @param amount The amount of tokens to be claimed
    */
    function _claimAsset(
        address token,
        address tokenReceiver,
        uint256 tokenId
    ) internal virtual {
        (token, tokenReceiver, tokenId);
        if (tokenReceiver != address(0)) {
            revert NotImplemented();
        }
    }

    /*
        /// @notice please override this function to store the asset
        /// @param token The address of the token
        /// @param tokenReceiver The address of the receiver
        /// @param amount The amount of tokens to be stored
    */
    function _storeAsset(address token, uint256 tokenId) internal virtual {
        (token, tokenId);
        if (token != address(0)) {
            revert NotImplemented();
        }
    }

    function _setMirrorGovernors(
        uint64[] calldata chainIds,
        address[] calldata governors
    ) internal {
        if (chainIds.length != governors.length) {
            revert DataLengthError();
        }

        for (uint256 i = 0; i < chainIds.length; i++) {
            mirrorGovernor[chainIds[i]] = governors[i];
        }
    }

    /*
        /// @notice Function to set the mirror bridges
        /// @param chainIds The chain ids of the mirror bridges
        /// @param bridges The addresses of the mirror bridges
    */
    function _setMirrorBridges(
        uint64[] calldata chainIds,
        address[] calldata bridges
    ) internal {
        if (chainIds.length != bridges.length) {
            revert DataLengthError();
        }
        for (uint256 i = 0; i < chainIds.length; i++) {
            mirrorBridge[chainIds[i]] = bridges[i];
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        (operator, from, tokenId, data);
        return IERC721Receiver.onERC721Received.selector;
    }
}
