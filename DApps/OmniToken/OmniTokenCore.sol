// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOmniTokenCore} from "./interface/IOmniTokenCore.sol";

abstract contract OmniTokenCore is ERC20, VizingOmni, IOmniTokenCore, Ownable {
    error InvalidData();

    uint64 public immutable override minArrivalTime;
    uint64 public immutable override maxArrivalTime;
    uint24 public immutable override minGasLimit;
    uint24 public immutable override maxGasLimit;
    bytes1 public immutable override defaultBridgeMode;
    address public immutable override selectedRelayer;
    uint256 public immutable tokenMintfee;
    bytes1 constant STANDARD_ACTIVATE = 0x01;
    bytes1 constant ARBITRARY_ACTIVATE = 0x02;
    // mirror OmniToken : mirrorToken[Chainid] = address
    mapping(uint64 => address) public mirrorToken;
    mapping(uint64 => uint256) public tokenOnChain;

    enum VizingRequestType {
        INVALID,
        XXX,
        TRANSFER,
        MINT,
        FUND,
        COUNT_INFO
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _vizingPad
    ) ERC20(_name, _symbol) VizingOmni(_vizingPad) Ownable(msg.sender) {
        defaultBridgeMode = ARBITRARY_ACTIVATE;
    }

    function bridgeTransfer(
        uint64 destChainid,
        address receiver,
        uint256 amount
    ) external payable virtual override {
        _tokenHandlingStrategy(amount);
        bridgeTransferHandler(destChainid, receiver, amount);
    }

    function bridgeTransferReceiver(
        address toAddress,
        uint256 amount
    ) public onlyVizingPad {
        _mint(toAddress, amount);
        tokenOnChain[uint64(block.chainid)] += amount;
    }

    function bridgeTransferHandler(
        uint64 destChainid,
        address receiver,
        uint256 amount
    ) public payable virtual {
        bytes memory message = PacketMessage(
            defaultBridgeMode,
            mirrorToken[destChainid],
            maxGasLimit,
            _fetchPrice(destChainid),
            _fetchTransferSignature(receiver, amount)
        );
        _bridgeTransferHandler(destChainid, message);
    }

    function _bridgeTransferHandler(
        uint64 destChainid,
        bytes memory message
    ) internal {
        emit2LaunchPad(
            uint64(block.timestamp + minArrivalTime),
            uint64(block.timestamp + maxArrivalTime),
            selectedRelayer,
            msg.sender,
            0,
            destChainid,
            new bytes(0),
            message
        );
    }

    /// @dev we build this function because bridgeTransferReceiver() method implements permission checking for the landing pad,
    ///         so it can be called here.
    function _fetchTransferSignature(
        address toAddress,
        uint256 amount
    ) internal view virtual returns (bytes memory signature) {
        signature = abi.encodeCall(
            IOmniTokenCore.bridgeTransferReceiver,
            (toAddress, amount)
        );
    }

    function _fetchCountInfoSignature(
        uint256 count
    ) internal view virtual returns (bytes memory signature) {
        return abi.encode(VizingRequestType.COUNT_INFO, count);
    }

    function mint(
        address toAddress,
        uint256 amount
    ) public payable virtual override {
        require(
            msg.value >= tokenMintfee * amount,
            "OmniToken: mint fee not enough"
        );
        _mint(toAddress, amount);
        tokenOnChain[uint64(block.chainid)] += amount;
    }

    function simpleBridgeMint(
        uint64 destChainId,
        address receiver,
        uint256 amount,
        uint256 gasTip
    ) public payable virtual override {
        uint256 value = tokenMintfee * amount;

        bytes memory messageEncode = abi.encode(
            VizingRequestType.MINT,
            receiver,
            amount
        );

        _simpleLaunch(
            destChainId,
            mirrorToken[destChainId],
            gasTip + value,
            maxGasLimit,
            messageEncode
        );
    }

    function bridgeMint(
        uint64 destChainId,
        address receiver,
        uint256 amount,
        uint256 gasTip
    ) public payable virtual override {
        uint256 value = tokenMintfee * amount;
        require(msg.value >= value, "OmniToken: mint fee not enough");

        bytes memory message = _bridgeMintHandler(
            destChainId,
            receiver,
            amount
        );

        emit2LaunchPad(
            uint64(block.timestamp + minArrivalTime),
            uint64(block.timestamp + maxArrivalTime),
            address(0),
            msg.sender,
            value + gasTip,
            destChainId,
            new bytes(0),
            message
        );
    }

    function _bridgeMintHandler(
        uint64 destChainId,
        address receiver,
        uint256 amount
    ) internal view returns (bytes memory) {
        return
            PacketMessage(
                defaultBridgeMode,
                mirrorToken[destChainId],
                maxGasLimit,
                _fetchPrice(destChainId),
                _fetchMintSignature(receiver, amount)
            );
    }

    function _fetchMintSignature(
        address toAddress,
        uint256 amount
    ) internal view virtual returns (bytes memory) {
        return abi.encode(VizingRequestType.MINT, toAddress, amount);
    }

    /// @notice before you bridgeTransfer, please call this function to get the bridge fee
    /// @dev if your token would charge a extra fee, you can override this function
    /// @return the fee of the bridge transfer
    function fetchOmniTokenTransferFee(
        uint64 destChainid,
        address receiver,
        uint256 amount
    ) external view virtual override returns (uint256) {
        return
            _estimateVizingGasFee(
                0,
                destChainid,
                new bytes(0),
                PacketMessage(
                    defaultBridgeMode,
                    mirrorToken[destChainid],
                    maxGasLimit,
                    _fetchPrice(destChainid),
                    _fetchTransferSignature(receiver, amount)
                )
            );
    }

    function fetchOmniTokenMintFee(
        uint256 value,
        uint64 destChainid,
        address receiver,
        uint256 amount
    ) external view virtual override returns (uint256) {
        return
            _estimateVizingGasFee(
                value,
                destChainid,
                new bytes(0),
                abi.encodePacked(
                    defaultBridgeMode,
                    uint256(uint160(mirrorToken[destChainid])),
                    maxGasLimit,
                    _fetchPrice(destChainid),
                    _fetchMintSignature(receiver, amount)
                )
            );
    }

    /// @dev bellow are the virtual functions, feel free to override them in your own contract.
    /// for Example, you can override the _tokenHandlingStrategy,
    /// instead of burning the token, you can transfer the token to a specific address.
    function _tokenHandlingStrategy(uint256 amount) internal virtual {
        _burn(msg.sender, amount);
    }

    function _receiveMessage(
        uint64 srcChainId,
        uint256 srcContract,
        bytes calldata message
    ) internal virtual override {
        // check mirrorToken
        if (mirrorToken[srcChainId] != address(uint160(srcContract))) {
            revert InvalidData();
        }
        // decode the message, args is for mint(address toAddress, uint256 amount)
        uint256 brideMode = uint256(bytes32(message[0:32]));
        bytes memory sig;
        if (uint256(VizingRequestType.MINT) == brideMode) {
            (address toAddress, uint256 amount) = abi.decode(
                message[32:],
                (address, uint256)
            );

            uint256 value = tokenMintfee * amount;
            require(msg.value >= value, "OmniToken: mint fee not enough");
            _mint(toAddress, amount);
            tokenOnChain[uint64(block.chainid)] += amount;
            sig = _infoBackHandler(srcChainId);
            // send message back
            infoBackEmit(
                (uint64(block.timestamp) + 3 minutes),
                (uint64(block.timestamp) + 1000 minutes),
                address(0),
                address(this),
                0,
                srcChainId,
                new bytes(0),
                sig
            );
        } else if (uint256(VizingRequestType.TRANSFER) == brideMode) {
            (address toAddress, uint256 amount) = abi.decode(
                message[32:],
                (address, uint256)
            );
            _mint(toAddress, amount);
            require(msg.value == 0, "no need to pay for transfer");
            tokenOnChain[uint64(block.chainid)] += amount;
            sig = _infoBackHandler(srcChainId);
            // send message back
            infoBackEmit(
                (uint64(block.timestamp) + 3 minutes),
                (uint64(block.timestamp) + 1000 minutes),
                address(0),
                address(this),
                0,
                srcChainId,
                new bytes(0),
                sig
            );
        } else if (uint256(VizingRequestType.COUNT_INFO) == brideMode) {
            (, uint256 count) = abi.decode(message[32:], (uint64, uint256));
            tokenOnChain[srcChainId] = count;
        } else {
            revert InvalidData();
        }
    }

    function _infoBackHandler(
        uint64 srcChainId
    ) internal view returns (bytes memory) {
        return
            PacketMessage(
                defaultBridgeMode,
                mirrorToken[srcChainId],
                maxGasLimit,
                _fetchPrice(srcChainId),
                _fetchCountInfoSignature(tokenOnChain[uint64(block.chainid)])
            );
    }

    function infoBackEmit(
        uint64 earliestArrivalTimestamp,
        uint64 latestArrivalTimestamp,
        address relayer,
        address sender,
        uint256 value,
        uint64 destChainid,
        bytes memory additionParams,
        bytes memory message
    ) public payable virtual {
        uint256 gasfee = LaunchPad.estimateGas(
            0,
            destChainid,
            additionParams,
            message
        );

        LaunchPad.Launch{value: gasfee}(
            earliestArrivalTimestamp,
            latestArrivalTimestamp,
            relayer,
            sender,
            value,
            destChainid,
            additionParams,
            message
        );
    }

    function setMirrorToken(
        uint64 Chainid,
        address tokenAddress
    ) external onlyOwner {
        mirrorToken[Chainid] = tokenAddress;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
