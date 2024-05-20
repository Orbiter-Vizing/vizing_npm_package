// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IMessageStruct} from "../../interface/IMessageStruct.sol";
import {IOmniNFTBridge} from "./interface/IOmniNFTBridge.sol";

contract OmniNFTBridgeCore is VizingOmni, Ownable, IOmniNFTBridge {
    error NotImplemented();

    uint24 public immutable WRAPPED_TOKEN_GAS_LIMIT;

    uint24 public immutable MINT_TOKEN_GAS_LIMIT;

    bytes1 private constant BRIDGE_SEND_MODE = 0x01;

    bytes1 private constant UNLOCK_MODE = 0x02;

    uint64 private immutable currentChainId;

    // keccak256(OriginNetwork || tokenAddress) --> Wrapped token address
    mapping(bytes32 => address) public tokenInfoToWrappedToken;

    // Wrapped token Address --> Origin token information
    mapping(address => TokenInformation) public wrappedTokens;

    mapping(uint64 => address) public mirrorBridge;

    // wrapped history
    mapping(bytes32 => bool) public wrappedHistory;

    constructor(
        address _owner,
        address _vizingPad,
        uint64 _deployChainId
    ) VizingOmni(_vizingPad) Ownable(_owner) {
        WRAPPED_TOKEN_GAS_LIMIT = 1500000;
        MINT_TOKEN_GAS_LIMIT = 65000;
        currentChainId = _deployChainId;
    }

    /*
        /// @notice Function to Send ERC721 (NFT) tokens to another chain
        /// @param destinationChainId The destination chain id
        /// @param tokenReceiver The address of the receiver on the destination chain
        /// @param tokenId The id of the token to be sent
        /// @param token The address of the token to be sent
    */
    function bridgeAsset(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token
    ) public payable override {
        _bridgeSendCallback(destinationChainId, tokenReceiver, tokenId, token);
        address originTokenAddress;
        uint64 originChainId;
        bytes memory metadata;
        uint24 gasLimitInDestChain = MINT_TOKEN_GAS_LIMIT;
        TokenInformation memory tokenInfo = wrappedTokens[token];

        // check if token is wrapped-token
        if (tokenInfo.originTokenAddress != address(0)) {
            // The token is a wrapped token from another network

            // Burn tokens
            _storeAsset(token, msg.sender, tokenId);

            originTokenAddress = tokenInfo.originTokenAddress;
            originChainId = tokenInfo.originChainId;
        } else {
            IERC721(token).transferFrom(msg.sender, address(this), tokenId);

            originTokenAddress = token;
            originChainId = currentChainId;
        }
        bytes32 wrappedHistoryHash = keccak256(
            abi.encode(destinationChainId, token)
        );

        if (wrappedHistory[wrappedHistoryHash] == false) {
            gasLimitInDestChain = WRAPPED_TOKEN_GAS_LIMIT;
            wrappedHistory[wrappedHistoryHash] = true;
        }

        // Encode metadata
        metadata = abi.encode(
            originTokenAddress,
            originChainId,
            tokenReceiver,
            tokenId,
            _safeName(token),
            _safeSymbol(token),
            _safeTokenURI(token, tokenId)
        );

        _simpleLaunch(
            destinationChainId,
            mirrorBridge[destinationChainId],
            0,
            gasLimitInDestChain,
            metadata
        );
    }

    /*
        /// @notice Function to receive the message from another chain
            (in this case, the message contains the information of the token to be claimed)
        /// @param message The message from the source chain
    */
    function _receiveMessage(
        uint64 /*srcChainId*/,
        uint256 /*srcContract*/,
        bytes calldata message
    ) internal virtual override {
        bytes1 mode = bytes1(bytes32(message[0:32]));
        if (mode == BRIDGE_SEND_MODE) {
            (
                address originTokenAddress,
                uint64 originChainId,
                address tokenReceiver,
                uint256 tokenId,
                string memory name,
                string memory symbol,
                string memory tokenURI
            ) = abi.decode(
                    message,
                    (address, uint64, address, uint256, string, string, string)
                );

            _claimAssetHandler(
                originChainId,
                originTokenAddress,
                tokenReceiver,
                tokenId,
                name,
                symbol,
                tokenURI
            );
        } else if (mode == UNLOCK_MODE) {
            (
                address originTokenAddress,
                address tokenReceiver,
                uint256 tokenId
            ) = abi.decode(message, (address, address, uint256));
            IERC721(originTokenAddress).transferFrom(
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
        string memory tokenURI
    ) internal returns (address wrappedToken) {
        // Transfer tokens
        if (originChainId == currentChainId) {
            // The token is an ERC20 from this network
            IERC721(originTokenAddress).transferFrom(
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

                wrappedToken = _deployContract(tokenInfoHash, name, symbol);

                // Mint tokens for the destination address
                _claimAsset(wrappedToken, tokenReceiver, tokenId, tokenURI);

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
                    tokenId,
                    name,
                    symbol,
                    tokenURI
                );
            } else {
                // Use the existing wrapped erc20
                _claimAsset(wrappedToken, tokenReceiver, tokenId, tokenURI);
            }
        }
    }

    /*
        /// @notice Function to estimate the fee of sending tokens to another chain
        /// @param destinationChainId The destination chain id
        /// @param destinationAddress The address of the receiver on the destination chain
        /// @param tokenReceiver The address of the receiver on the destination chain
        /// @param tokenId The id of the token to be sent
        /// @param token The address of the token to be sent
        /// @return The fee of sending tokens to another chain
    */
    function fetchBridgeAssetDetails(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 tokenId,
        address token
    ) external view returns (uint256 gasFee) {
        // address originTokenAddress;
        // uint64 originChainId;
        // bytes memory metadata;
        // uint24 gasLimitInDestChain = MINT_TOKEN_GAS_LIMIT;
        // TokenInformation memory tokenInfo = wrappedTokens[token];
        // // check if token is wrapped-token
        // if (tokenInfo.originTokenAddress != address(0)) {
        //     // The token is a wrapped token from another network
        //     originTokenAddress = tokenInfo.originTokenAddress;
        //     originChainId = tokenInfo.originChainId;
        // } else {
        //     originTokenAddress = token;
        //     originChainId = currentChainId;
        // }
        // bytes32 wrappedHistoryHash = keccak256(
        //     abi.encode(destinationChainId, token)
        // );
        // if (wrappedHistory[wrappedHistoryHash] == false) {
        //     gasLimitInDestChain = WRAPPED_TOKEN_GAS_LIMIT;
        // }
        // // string memory tokenName = _safeName(token);
        // // string memory tokenSymbol = _safeSymbol(token);
        // string memory tokenURI = _safeTokenURI(token, tokenId);
        // // Encode metadata
        // metadata = abi.encode(
        //     originTokenAddress,
        //     originChainId,
        //     tokenReceiver,
        //     tokenId,
        //     _safeName(token),
        //     _safeSymbol(token),
        //     tokenURI
        // );
        // address targetContract = mirrorBridge[destinationChainId];
        // uint64 price = _fetchPrice(targetContract, destinationChainId);
        // bytes memory signature = _fetchSignature(BRIDGE_SEND_MODE, metadata);
        // bytes memory packedMessage = PacketMessage(
        //     bytes1(0x02), // ARBITRARY_ACTIVATE
        //     targetContract,
        //     gasLimitInDestChain,
        //     price,
        //     signature
        // );
        // gasFee = _estimateVizingGasFee(
        //     0,
        //     destinationChainId,
        //     new bytes(0),
        //     packedMessage
        // );
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
        string memory symbol
    ) internal virtual returns (address) {
        (salt, name, symbol);
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
        uint256 tokenId,
        string memory tokenURI
    ) internal virtual {
        (token, tokenReceiver, tokenId, tokenURI);
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
    function _storeAsset(
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
        /// @notice Function to set the mirror bridges
        /// @param chainIds The chain ids of the mirror bridges
        /// @param bridges The addresses of the mirror bridges
    */
    function _setMirrorBridges(
        uint64[] calldata chainIds,
        address[] calldata bridges
    ) internal {
        require(chainIds.length == bridges.length, "Invalid input length");
        for (uint256 i = 0; i < chainIds.length; i++) {
            mirrorBridge[chainIds[i]] = bridges[i];
        }
    }

    /**
     * @notice Provides a safe ERC721.symbol version which returns 'NO_SYMBOL' as fallback string
     * @param token The address of the ERC-721 token contract
     */
    function _safeSymbol(address token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(
            abi.encodeCall(IERC721Metadata.symbol, ())
        );
        return success ? _returnDataToString(data) : "NO_SYMBOL";
    }

    /**
     * @notice  Provides a safe ERC721.name version which returns 'NO_NAME' as fallback string.
     * @param token The address of the ERC-721 token contract.
     */
    function _safeName(address token) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(
            abi.encodeCall(IERC721Metadata.name, ())
        );
        return success ? _returnDataToString(data) : "NO_NAME";
    }

    /**
     * @notice Function to get the token URI of an ERC721 token
     * @param token The address of the ERC-721 token contract
     */
    function _safeTokenURI(
        address token,
        uint256 tokenId
    ) internal view returns (string memory) {
        (bool success, bytes memory data) = address(token).staticcall(
            abi.encodeCall(IERC721Metadata.tokenURI, (tokenId))
        );
        return success ? _returnDataToString(data) : "NO_TOKEN_URI";
    }

    /**
     * @notice Function to convert returned data to string
     * returns 'NOT_VALID_ENCODING' as fallback value.
     * @param data returned data
     */
    function _returnDataToString(
        bytes memory data
    ) internal pure returns (string memory) {
        if (data.length >= 64) {
            return abi.decode(data, (string));
        } else if (data.length == 32) {
            // Since the strings on bytes32 are encoded left-right, check the first zero in the data
            uint256 nonZeroBytes;
            while (nonZeroBytes < 32 && data[nonZeroBytes] != 0) {
                nonZeroBytes++;
            }

            // If the first one is 0, we do not handle the encoding
            if (nonZeroBytes == 0) {
                return "NOT_VALID_ENCODING";
            }
            // Create a byte array with nonZeroBytes length
            bytes memory bytesArray = new bytes(nonZeroBytes);
            for (uint256 i = 0; i < nonZeroBytes; i++) {
                bytesArray[i] = data[i];
            }
            return string(bytesArray);
        } else {
            return "NOT_VALID_ENCODING";
        }
    }
}
