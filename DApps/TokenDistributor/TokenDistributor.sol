// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {MessageTypeLib} from "@vizing/contracts/library/MessageTypeLib.sol";
import {IMessageStruct} from "@vizing/contracts/interface/IMessageStruct.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenDistributor is Ownable, VizingOmni {
    uint24 private constant GAS_LIMIT = 120000;

    uint256 public txCount;

    bytes1 public constant BRIDGE_SEND_MODE = 0x01;

    bytes1 public constant COUNT_MODE = 0x02;

    mapping(uint64 => address) public mirrorExchanger;

    constructor(
        address _vizingPad
    ) Ownable(msg.sender) VizingOmni(_vizingPad) {}

    function tokenDistribute(
        uint64[] calldata destChainid,
        uint256[] calldata amountOut,
        uint256[] calldata payForPongfee,
        address[] calldata tokenReceiver
    ) external payable {
        if (destChainid.length != tokenReceiver.length) {
            revert("TokenDistributor: Invalid length");
        }
        address[] memory targetContracts = new address[](destChainid.length);
        uint24[] memory gasLimitInDestChain = new uint24[](destChainid.length);
        bytes[] memory messageEncoded = new bytes[](destChainid.length);
        for (uint256 i = 0; i < destChainid.length; i++) {
            targetContracts[i] = mirrorExchanger[destChainid[i]];
            gasLimitInDestChain[i] = GAS_LIMIT;
            messageEncoded[i] = abi.encode(
                BRIDGE_SEND_MODE,
                tokenReceiver[i],
                amountOut[i]
            );
        }

        uint256[] memory totalAmount = new uint256[](amountOut.length);
        for (uint256 i = 0; i < amountOut.length; i++) {
            totalAmount[i] = amountOut[i] + payForPongfee[i];
        }

        _simpleLaunchMultiChain(
            destChainid,
            targetContracts,
            totalAmount,
            gasLimitInDestChain,
            messageEncoded
        );
    }

    function _simpleLaunchMultiChain(
        uint64[] memory destChainid,
        address[] memory targetContract,
        uint256[] memory amountOut,
        uint24[] memory gasLimitInDestChain,
        bytes[] memory messageEncoded
    ) internal virtual {
        bytes[] memory packedMessage = new bytes[](messageEncoded.length);
        for (uint256 i = 0; i < messageEncoded.length; i++) {
            packedMessage[i] = _packetMessage(
                bytes1(0x01), // ARBITRARY_ACTIVATE
                targetContract[i],
                gasLimitInDestChain[i],
                _fetchPrice(targetContract[i], destChainid[i]),
                messageEncoded[i]
            );
        }

        LaunchPad.launchMultiChain{value: msg.value}(
            IMessageStruct.launchEnhanceParams(
                0,
                0,
                address(0),
                msg.sender,
                amountOut,
                destChainid,
                new bytes[](messageEncoded.length),
                packedMessage
            )
        );
    }

    function _receiveMessage(
        uint64 srcChainId,
        uint256 srcContract,
        bytes calldata message
    ) internal virtual override {
        bytes1 mode = bytes1(bytes32(message[0:32]));
        if (mode == BRIDGE_SEND_MODE) {
            (, address tokenReceiver, uint256 amountOut) = abi.decode(
                message,
                (bytes1, address, uint256)
            );

            require(msg.value > amountOut, "Invalid amount");
            // send ether to tokenReceiver
            (bool sent, ) = payable(tokenReceiver).call{value: amountOut}("");
            require(sent, "Failed to send ether");

            address targetContract = address(uint160(srcContract));
            uint64 price = _fetchPrice(targetContract, srcChainId);
            bytes memory encodedMessage = _packetMessage(
                BRIDGE_SEND_MODE, // STANDARD_ACTIVATE
                targetContract,
                GAS_LIMIT,
                price,
                abi.encode(COUNT_MODE)
            );

            uint256 gasfee = fetchBridgeAssetDetails(
                srcChainId,
                targetContract
            );

            require(msg.value - amountOut >= gasfee, "gas fee not enough");

            this.Launch{value: gasfee}(srcChainId, encodedMessage);
        } else if (mode == COUNT_MODE) {
            txCount++;
        }
    }

    function Launch(
        uint64 destinationChainId,
        bytes calldata metadata
    ) public payable {
        require(msg.sender == address(this), "invalid sender");
        LaunchPad.Launch{value: msg.value}(
            0,
            0,
            address(0),
            address(this),
            0,
            destinationChainId,
            new bytes(0),
            metadata
        );
    }

    function setMirrorExchangers(
        uint64[] calldata chainIds,
        address[] calldata exchangers
    ) external onlyOwner {
        require(chainIds.length == exchangers.length, "Invalid length");

        for (uint256 i = 0; i < chainIds.length; i++) {
            mirrorExchanger[chainIds[i]] = exchangers[i];
        }
    }

    function fetchBridgeAssetDetails(
        uint64 destinationChainId,
        address targetContract
    ) public view returns (uint256 gasFee) {
        uint64 price = _fetchPrice(targetContract, destinationChainId);
        bytes memory encodedMessage = _packetMessage(
            BRIDGE_SEND_MODE, // STANDARD_ACTIVATE
            targetContract,
            GAS_LIMIT,
            price,
            abi.encode(COUNT_MODE)
        );
        gasFee = _estimateVizingGasFee(
            0,
            destinationChainId,
            new bytes(0),
            encodedMessage
        );
    }
}
