// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
//      oooooo     oooo ooooo  oooooooooooo ooooo ooooo      ooo   .oooooo.
//       `888.     .8'  `888' d'""""""d888' `888' `888b.     `8'  d8P'  `Y8b
//        `888.   .8'    888        .888P    888   8 `88b.    8  888
//         `888. .8'     888       d888'     888   8   `88b.  8  888
//          `888.8'      888     .888P       888   8     `88b.8  888     ooooo
//           `888'       888    d888'    .P  888   8       `888  `88.    .88'
//            `8'       o888o .8888888888P  o888o o8o        `8   `Y8bood8P'
//
//                  find all details at https://www.vizing.com/
//
//                            .^~7?JYPPPPPP55YJ?!~^.
//                       .^7YPB#&&&&&&&&&&&&&&&&&&#BPY?~.
//                    :75B#&&&&####################&&&&#GY7:
//                 :75#&&&#######&&&&&&&&&&&&&&&&#######&&&#P7:
//               :JB&&#######&&&##BP5YJJ???JY5PB#&&&&#######&&BJ:
//             :Y#&&######&&#B5?~:.            .:~?YG#&&######&&#Y:
//            7B&&######&#GJ^.                      .~JG&&######&&B7
//          .5&&######&#5~                     .        ~5#&######&&5.
//         ^G&######&&5~                     ~PGP~        ~5&&###&&&&G: ...::::..
//        :G&######&#?                       !#&#?          7B###BBGGG5YY5555555YJ!
//       .P&######&B^                         !&7       .:~!75PPPP5555PPPPPPPPPPPPP^
//       7&######&#~                          YB: .:~7?Y5PPPPPPPPPPPPPPPPPPPPPPPPP7
//      .B&######&?       ~??~               7GJ7J55PPPPPPPPPPPPPPPPPPPPPPPPPPPPY^
//      1&######&B.      .B@@#~         .^~7YP5PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPY~.
//      #&######&5        ^77JP5?!^..~7J5PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5?^
//      J&######&J             ~JP555PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5J!.
//      #&######&5          :!?Y55PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5J!:.
//      1#######&B.     :~?YPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5?~:^?P~
//      .B&######&J .^7J5PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5Y7^:~JG#&B.
//       7&####&##G?YPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPY?~:^!YB#&&#&?
//        5&&##BP5PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5J!^:~JP#&&&###&P.
//        .GBPP55PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5Y?!^^~?5B&&&######&G:
//       :!YP5PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5Y?~^^!JPB&&&&########&G:
//     ^?5PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP5Y?!^:^7YG#&&&&##########&&5.
//   .7PPPPPPPPPPPPPPPPPPPPPPPPPPPPP5J7~^^^!JPB#&&&#############&&B7
//  ^5PPPPPPPPPPPPPPPPPPPPPPP55Y?7~^^^7J5B#&&&&###############&&#Y:
//  YPPPPPPPPPPPPPPPPPP5YJ7!~^^^!?YPB#&&&&#################&&&BJ:
//  ^?Y55555555YYJ?7!^^^~!7J5GB#&&&&&###################&&&#P7:
//    ..:::::...       ~YB&@&&&&###################&&&&&B57:
//                       .^7YPB#&&&&&&&&&&&&&&&&&&#BGY7~.
//                            .^~7?YY5PPPGPP55Y?7~^.
//
// import {OmniTokenBridgeCore} from "@vizing/contracts/DApps/OmniTokenBridge/OmniTokenBridgeCore.sol";

import {OmniTokenBridgeCore} from "./OmniTokenBridgeCore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICompanionMessage} from "./interface/ICompanionMessage.sol";
import {TokenWrapped} from "./TokenWrapped.sol";

contract VizingTokenBridge is Ownable, OmniTokenBridgeCore {
    using SafeERC20 for IERC20;

    constructor(
        address _owner,
        address[] memory _governors,
        address _vizingPad,
        uint64 _currentChainId
    ) Ownable(_owner) OmniTokenBridgeCore(_vizingPad, _currentChainId) {
        if (
            _governors.length == 0 ||
            _owner == address(0) ||
            _vizingPad == address(0)
        ) {
            revert InvalidAddress();
        }

        DEFAULT_GASLIMIT = 2000000;
        bool[] memory states = new bool[](_governors.length + 1);
        address[] memory newGovernors = new address[](_governors.length + 1);
        for (uint256 i = 0; i < _governors.length; i++) {
            states[i] = true;
            newGovernors[i] = _governors[i];
        }
        states[_governors.length] = true;
        newGovernors[_governors.length] = _owner;
        _setGovernors(newGovernors, states);
    }

    /*
        /// @notice this function is called on source chain
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
    ) internal pure override {
        (destinationChainId, tokenReceiver, amount, token);
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
            (
                ,
                address originTokenAddress,
                uint64 originChainId,
                address tokenReceiver,
                uint256 amount,
                string memory name,
                string memory symbol,
                uint8 decimals,
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

            if (companionMessage.length != 0) {
                bool success = ICompanionMessage(tokenReceiver)
                    .bridgeConvertTokenReceiver(companionMessage);
                if (!success) {
                    revert FailedCall();
                }
            }
        } else if (mode == UNLOCK_MODE) {
            if (governors[address(uint160(srcContract))] == false) {
                revert NotBridgeMessage();
            }
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
    ) external view override returns (address) {
        address bridgeAddress = mirrorBridge[destinationChainId];
        bridgeAddress = bridgeAddress == address(0)
            ? address(this)
            : bridgeAddress;
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                bridgeAddress,
                                keccak256(
                                    abi.encodePacked(
                                        originChainId,
                                        originTokenAddress
                                    )
                                ),
                                keccak256(
                                    abi.encodePacked(
                                        type(TokenWrapped).creationCode,
                                        abi.encode(name, symbol, decimals)
                                    )
                                )
                            )
                        )
                    )
                )
            );
    }

    /*
        /// @notice this function is called on destination chain
        /// @notice Function to be called after the claimAsset function is successful
        /// @param wrappedToken The address of the wrapped token
    */
    function _claimSuccessCallback(
        uint64 srcChainId,
        address wrappedToken
    ) internal pure override {
        (srcChainId, wrappedToken);
    }

    function _deployContract(
        bytes32 salt,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal override returns (address) {
        TokenWrapped newWrappedToken = (new TokenWrapped){salt: salt}(
            name,
            symbol,
            decimals
        );
        return address(newWrappedToken);
    }

    function _claimAsset(
        address token,
        address tokenReceiver,
        uint256 amount
    ) internal override {
        TokenWrapped(token).mint(tokenReceiver, amount);
    }

    function _storeAsset(
        address token,
        address account,
        uint256 amount
    ) internal override {
        TokenWrapped(token).burn(account, amount);
    }

    function setMirrorBridges(
        uint64[] calldata chainIds,
        address[] calldata bridges
    ) external onlyGovernor {
        _setMirrorBridges(chainIds, bridges);
    }

    function setGovernors(
        address[] calldata _governors,
        bool[] calldata _states
    ) external onlyOwner {
        _setGovernors(_governors, _states);
    }

    function modifyBridgeGasLimit(uint24 _newGasLimit) external onlyGovernor {
        _modifyGasLimit(_newGasLimit);
    }
}
