// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {OmniERC20Core} from "./OmniERC20Core.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyOmniERC20 is OmniERC20Core, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        address vizingPad_
    ) OmniERC20Core(name_, symbol_, vizingPad_) Ownable(msg.sender) {
        MAX_GAS_LIMIT = 100000;
        _mint(msg.sender, 100000 ether);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function setOmniERC20s(
        uint64[] calldata chainIds,
        address[] calldata omniERC20s
    ) external onlyOwner {
        _setOmniERC20s(chainIds, omniERC20s);
    }
}
