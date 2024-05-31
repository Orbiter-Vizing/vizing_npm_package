// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOminiTokenBridge} from "./interface/IOminiTokenBridge.sol";
import {Erc20Utils} from "./library/Erc20Utils.sol";

abstract contract OmniTokenBridgeCore is IOminiTokenBridge, VizingOmni {
    error ValueNotEnough();
    error NotValidOwner();
    error NotValidSpender();
    error NotValidAmount();
    error NotValidSignature();
    error TransferError();
    error NotImplemented();
    error DataLengthError();
    error InvalidAddress();

    using SafeERC20 for IERC20;
    using Erc20Utils for address;

    uint24 public immutable DEFAULT_GASLIMIT;

    bytes1 public constant BRIDGE_SEND_MODE = 0x01;

    bytes1 public constant UNLOCK_MODE = 0x02;

    // bytes4(keccak256(bytes("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)")));
    bytes4 private constant _PERMIT_SIGNATURE = 0xd505accf;

    // bytes4(keccak256(bytes("permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32)")));
    bytes4 private constant _PERMIT_SIGNATURE_DAI = 0x8fcbaf0c;

    uint64 private immutable currentChainId;

    uint24 internal _bridgeGasLimit;

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
        _bridgeGasLimit = 2000000;
    }

    /*
        /// @similar to bridgeAsset, but gas friendly.call fetchBridgeAssetDetails to get the encodedMessage
        /// @notice Function to Send ERC20 tokens to another chain
        /// @param destinationChainId The destination chain id
        /// @param tokenReceiver The address of the receiver on the destination chain
        /// @param amount The amount of tokens to be sent
        /// @param token The address of the token to be sent
        /// @param permitData The data of the permit function of the token
        /// @param companionMessage A companion message to send to the tokenReceiver, if not needed, pass an empty bytes
    */
    function bridgeAsset(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 amount,
        address token,
        bytes calldata permitData,
        bytes calldata companionMessage
    ) public payable virtual override {
        (, bytes memory metadata) = fetchBridgeAssetDetails(
            destinationChainId,
            tokenReceiver,
            amount,
            token,
            companionMessage
        );

        {
            _bridgeAssetHandlingStrategy(
                destinationChainId,
                tokenReceiver,
                amount,
                token,
                permitData
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
        uint256 amount,
        address token,
        bytes calldata permitData
    ) internal {
        _bridgeSendCallback(destinationChainId, tokenReceiver, amount, token);
        TokenInformation memory tokenInfo = wrappedTokens[token];
        // check if token is wrapped-token
        if (tokenInfo.originTokenAddress != address(0)) {
            // The token is a wrapped token from another network
            _storeAsset(token, msg.sender, amount);
        } else {
            // Use permit if any
            if (permitData.length != 0) {
                _permit(token, amount, permitData);
            }
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    /*
        /// @notice Function to estimate the fee of sending tokens to another chain
        /// @param destinationChainId The destination chain id
        /// @param destinationAddress The address of the receiver on the destination chain
        /// @param amount The amount of tokens to be sent
        /// @param token The address of the token to be sent
        /// @return The fee of sending tokens to another chain
    */
    function fetchBridgeAssetDetails(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 amount,
        address token,
        bytes calldata companionMessage
    ) public view returns (uint256 gasFee, bytes memory encodedMessage) {
        address originTokenAddress;
        uint64 originChainId;

        if (token == address(0)) {
            revert TransferError();
        } else {
            TokenInformation memory tokenInfo = wrappedTokens[token];

            // check if token is wrapped-token
            if (tokenInfo.originTokenAddress != address(0)) {
                originTokenAddress = tokenInfo.originTokenAddress;
                originChainId = tokenInfo.originChainId;
            } else {
                originTokenAddress = token;
                originChainId = currentChainId;
            }
        }

        {
            bytes memory metadata = _encodeMetadata(
                BRIDGE_SEND_MODE,
                originTokenAddress,
                originChainId,
                tokenReceiver,
                token,
                amount,
                companionMessage
            );
            address targetContract = mirrorBridge[destinationChainId];
            uint64 price = _fetchPrice(targetContract, destinationChainId);
            encodedMessage = _packetMessage(
                BRIDGE_SEND_MODE, // STANDARD_ACTIVATE
                targetContract,
                _fetchGasLimit(),
                price,
                metadata
            );
        }

        gasFee = _estimateVizingGasFee(
            0,
            destinationChainId,
            new bytes(0),
            encodedMessage
        );
    }

    /*
        /// @notice Function to receive the message from another chain
            (in this case, the message contains the information of the token to be claimed)
        /// @param message The message from the source chain
    */
    function _receiveMessage(
        uint64 srcChainId,
        uint256,
        /*srcContract*/ bytes calldata message
    ) internal virtual override {
        bytes1 mode = bytes1(bytes32(message[0:32]));
        if (mode == BRIDGE_SEND_MODE) {
            (
                ,
                address originTokenAddress,
                uint64 originChainId,
                address tokenReceiver,
                uint256 amount,
                string memory name,
                string memory symbol,
                uint8 decimals,

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
                        uint8,
                        bytes
                    )
                );

            _claimSuccessCallback(
                srcChainId,
                _claimAssetHandler(
                    originChainId,
                    originTokenAddress,
                    tokenReceiver,
                    amount,
                    name,
                    symbol,
                    decimals
                )
            );
        } else if (mode == UNLOCK_MODE) {
            (
                ,
                address originTokenAddress,
                address tokenReceiver,
                uint256 amount
            ) = abi.decode(message, (bytes1, address, address, uint256));
            IERC20(originTokenAddress).safeTransfer(tokenReceiver, amount);
        }
    }

    function predictTokenAddress(
        uint64 destinationChainId,
        uint64 originChainId,
        address originTokenAddress,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external view virtual override returns (address) {
        (destinationChainId, originChainId, name, symbol, decimals);
        if (originTokenAddress != address(0)) {
            revert NotImplemented();
        }
        return address(0);
    }

    function fetchUnLockDetails(
        uint64 destinationChainId,
        address originTokenAddress,
        address tokenReceiver,
        uint256 amount
    )
        external
        view
        virtual
        override
        returns (uint256 fee, bytes memory unLockMessage)
    {
        bytes memory metadata = abi.encode(
            UNLOCK_MODE,
            originTokenAddress,
            tokenReceiver,
            amount
        );
        address targetContract = mirrorBridge[destinationChainId];
        if (targetContract == address(0)) {
            revert InvalidAddress();
        }
        uint64 price = _fetchPrice(targetContract, destinationChainId);
        unLockMessage = _packetMessage(
            BRIDGE_SEND_MODE,
            targetContract,
            _fetchGasLimit(),
            price,
            metadata
        );

        fee = _estimateVizingGasFee(
            0,
            destinationChainId,
            new bytes(0),
            unLockMessage
        );
    }

    function _encodeMetadata(
        bytes1 mode,
        address originTokenAddress,
        uint64 originChainId,
        address tokenReceiver,
        address token,
        uint256 amount,
        bytes calldata companionMessage
    ) internal view returns (bytes memory metadata) {
        metadata = abi.encode(
            mode,
            originTokenAddress,
            originChainId,
            tokenReceiver,
            amount,
            token.safeName(),
            token.safeSymbol(),
            token.safeDecimals(),
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
        uint256 amount,
        address token
    ) internal virtual {
        (destinationChainId, amount, token);
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
        address wrappedToken
    ) internal virtual {
        (srcChainId, wrappedToken);
        if (wrappedToken != address(0)) {
            revert NotImplemented();
        }
    }

    function _claimAssetHandler(
        uint64 originChainId,
        address originTokenAddress,
        address tokenReceiver,
        uint256 amount,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal returns (address wrappedToken) {
        // Transfer funds
        if (originTokenAddress == address(0)) {
            // Transfer ether
            /* solhint-disable avoid-low-level-calls */
            (bool success, ) = tokenReceiver.call{value: amount}(new bytes(0));
            if (!success) {
                revert TransferError();
            }
        } else {
            // Transfer tokens
            if (originChainId == currentChainId) {
                // The token is an ERC20 from this network
                IERC20(originTokenAddress).safeTransfer(tokenReceiver, amount);
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
                        decimals
                    );

                    // Mint tokens for the destination address
                    _claimAsset(wrappedToken, tokenReceiver, amount);

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
                        decimals
                    );
                } else {
                    // Use the existing wrapped erc20
                    _claimAsset(wrappedToken, tokenReceiver, amount);
                }
            }
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
        uint8 decimals
    ) internal virtual returns (address) {
        (salt, name, symbol, decimals);
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
        uint256 amount
    ) internal virtual {
        (token, tokenReceiver, amount);
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
        uint256 amount
    ) internal virtual {
        (token, tokenReceiver, amount);
        if (tokenReceiver != address(0)) {
            revert NotImplemented();
        }
    }

    /**
     * @notice Function to call token permit method of extended ERC20
     *  + @param token ERC20 token address
     * @param amount Quantity that is expected to be allowed
     * @param permitData Raw data of the call `permit` of the token
     */
    function _permit(
        address token,
        uint256 amount,
        bytes calldata permitData
    ) internal {
        bytes4 sig = bytes4(permitData[:4]);
        if (sig == _PERMIT_SIGNATURE) {
            (
                address owner,
                address spender,
                uint256 value,
                uint256 deadline,
                uint8 v,
                bytes32 r,
                bytes32 s
            ) = abi.decode(
                    permitData[4:],
                    (
                        address,
                        address,
                        uint256,
                        uint256,
                        uint8,
                        bytes32,
                        bytes32
                    )
                );
            if (owner != msg.sender) {
                revert NotValidOwner();
            }
            if (spender != address(this)) {
                revert NotValidSpender();
            }

            if (value != amount) {
                revert NotValidAmount();
            }

            // we call without checking the result, in case it fails and he doesn't have enough balance
            // the following transferFrom should be fail. This prevents DoS attacks from using a signature
            // before the smartcontract call
            /* solhint-disable avoid-low-level-calls */
            (bool success, ) = address(token).call(
                abi.encodeWithSelector(
                    _PERMIT_SIGNATURE,
                    owner,
                    spender,
                    value,
                    deadline,
                    v,
                    r,
                    s
                )
            );
            (success);
        } else {
            if (sig != _PERMIT_SIGNATURE_DAI) {
                revert NotValidSignature();
            }

            (
                address holder,
                address spender,
                uint256 nonce,
                uint256 expiry,
                bool allowed,
                uint8 v,
                bytes32 r,
                bytes32 s
            ) = abi.decode(
                    permitData[4:],
                    (
                        address,
                        address,
                        uint256,
                        uint256,
                        bool,
                        uint8,
                        bytes32,
                        bytes32
                    )
                );

            if (holder != msg.sender) {
                revert NotValidOwner();
            }

            if (spender != address(this)) {
                revert NotValidSpender();
            }

            // we call without checking the result, in case it fails and he doesn't have enough balance
            // the following transferFrom should be fail. This prevents DoS attacks from using a signature
            // before the smartcontract call
            /* solhint-disable avoid-low-level-calls */
            (bool success, ) = address(token).call(
                abi.encodeWithSelector(
                    _PERMIT_SIGNATURE_DAI,
                    holder,
                    spender,
                    nonce,
                    expiry,
                    allowed,
                    v,
                    r,
                    s
                )
            );
            (success);
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

    function _fetchGasLimit() internal view virtual returns (uint24) {
        return _bridgeGasLimit;
    }

    function _modifyGasLimit(uint24 newGasLimit) internal {
        _bridgeGasLimit = newGasLimit;
    }
}
