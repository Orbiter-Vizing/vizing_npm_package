// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {VizingOmni} from "@vizing/contracts/VizingOmni.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IOmniERC20Core} from "./interface/IOmniERC20Core.sol";

abstract contract OmniERC20Core is ERC20, VizingOmni, IOmniERC20Core {
    uint24 public immutable MAX_GAS_LIMIT;

    // OmniERC20 address list
    mapping(uint64 => address) public omniERC20s;

    constructor(
        string memory name_,
        string memory symbol_,
        address vizingPad_
    ) ERC20(name_, symbol_) VizingOmni(vizingPad_) {}

    function transferToChain(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 amount
    ) external payable virtual override {
        _burn(msg.sender, amount);
        address targetContract = omniERC20s[destinationChainId];
        bytes memory signature = fetchTransferSignature(tokenReceiver, amount);
        bytes memory packedMessage = PacketMessage(
            bytes1(0x02), // ARBITRARY_ACTIVATE
            targetContract,
            MAX_GAS_LIMIT,
            _fetchPrice(targetContract, destinationChainId),
            signature
        );

        emit2LaunchPad(
            0,
            0,
            address(0),
            msg.sender,
            0,
            destinationChainId,
            new bytes(0),
            packedMessage
        );
        emit TransferToChain(msg.sender, amount, destinationChainId);
    }

    function transferToChain(
        uint64 destinationChainId,
        uint256 amount,
        bytes calldata additionalParams,
        bytes calldata packedMessage
    ) external payable override {
        _burn(msg.sender, amount);
        emit2LaunchPad(
            0,
            0,
            address(0),
            msg.sender,
            0,
            destinationChainId,
            additionalParams,
            packedMessage
        );
        emit TransferToChain(msg.sender, amount, destinationChainId);
    }

    function estimateTransferToChainFee(
        uint64 destinationChainId,
        address tokenReceiver,
        uint256 amount
    ) external view returns (uint256 gasFee) {
        address targetContract = address(this);
        bytes memory signature = fetchTransferSignature(tokenReceiver, amount);
        bytes memory packedMessage = PacketMessage(
            bytes1(0x02), // ARBITRARY_ACTIVATE
            targetContract,
            MAX_GAS_LIMIT,
            _fetchPrice(targetContract, destinationChainId),
            signature
        );
        gasFee = _estimateVizingGasFee(
            0,
            destinationChainId,
            new bytes(0),
            packedMessage
        );
    }

    function estimateTransferToChainFee(
        uint64 destinationChainId,
        bytes calldata additionalParams,
        bytes calldata packedMessage
    ) external view returns (uint256 gasFee) {
        gasFee = _estimateVizingGasFee(
            0,
            destinationChainId,
            additionalParams,
            packedMessage
        );
    }

    function receiveTransferFromOtherChain(
        address tokenReceiver,
        uint256 amount
    ) external override onlyVizingPad {
        _mint(tokenReceiver, amount);
    }

    function _setOmniERC20s(
        uint64[] calldata _chainIds,
        address[] calldata _omniERC20s
    ) internal {
        require(_chainIds.length == _omniERC20s.length, "Invalid length");
        for (uint256 i = 0; i < _chainIds.length; i++) {
            omniERC20s[_chainIds[i]] = _omniERC20s[i];
        }
    }

    function fetchTransferSignature(
        address tokenReceiver,
        uint256 amount
    ) public pure override returns (bytes memory signature) {
        signature = abi.encodeCall(
            IOmniERC20Core.receiveTransferFromOtherChain,
            (tokenReceiver, amount)
        );
    }

    function fetchTransferMessage(
        address destinationOmniERC20,
        uint24 gasLimit,
        uint64 price,
        bytes calldata signature
    ) external pure override returns (bytes memory message) {
        message = PacketMessage(
            bytes1(0x02), // ARBITRARY_ACTIVATE
            destinationOmniERC20,
            gasLimit,
            price,
            signature
        );
    }

    function fetchTransferPrice(
        address destinationOmniERC20,
        uint64 destChainid
    ) external view override returns (uint64 price) {
        price = _fetchPrice(destinationOmniERC20, destChainid);
    }
}
