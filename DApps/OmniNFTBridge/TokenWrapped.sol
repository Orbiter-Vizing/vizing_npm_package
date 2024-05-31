// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TokenWrapped is ERC721 {
    error AccessDenied();
    // Version
    string public constant VERSION = "1";

    // Chain id on deployment
    uint256 public immutable deploymentChainId;

    // Vizing OmniToken Bridge address
    address public immutable bridgeAddress;

    // URI
    string private baseURI_;

    modifier onlyBridge() {
        if (msg.sender != bridgeAddress) revert AccessDenied();
        _;
    }

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        bridgeAddress = msg.sender;
        deploymentChainId = block.chainid;
    }

    function mint(address to, uint256 tokenId) external onlyBridge {
        _safeMint(to, tokenId);
    }

    // Notice that is not require to approve wrapped tokens to use the bridge
    function burn(uint256 tokenId) external onlyBridge {
        _burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI_;
    }

    function setBaseURI(string calldata baseURI) external onlyBridge {
        baseURI_ = baseURI;
    }
}
