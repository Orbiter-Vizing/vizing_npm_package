// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library Utils {
    function hash(bytes memory data) internal pure returns (bytes32) {
        return keccak256(data);
    }
}
