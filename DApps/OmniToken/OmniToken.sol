// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {OmniTokenCore} from "./OmniTokenCore.sol";

contract OmniToken is OmniTokenCore {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _vizingPad,
        address _defaultRelayer
    ) OmniTokenCore(_name, _symbol, _vizingPad) {
        minArrivalTime = 3 minutes;
        maxArrivalTime = 30 days;
        minGasLimit = 100000;
        maxGasLimit = 500000;
        selectedRelayer = _defaultRelayer;
        tokenMintfee = 0.00001 ether;
        _mint(msg.sender, _initialSupply);
        tokenOnChain[uint64(block.chainid)] += _initialSupply;
    }

    function _tokenHandlingStrategy(uint256 amount) internal override {
        _burn(msg.sender, amount);
        tokenOnChain[uint64(block.chainid)] -= amount;
    }

    function getLaunchHooks(bytes1 hook) external view returns (address) {
        return LaunchPad.expertLaunchHook(hook);
    }
}
