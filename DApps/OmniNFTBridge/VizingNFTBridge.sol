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

import {OmniNFTBridgeCore} from "./OmniNFTBridgeCore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TokenWrapped} from "./TokenWrapped.sol";

contract VizingNFTBridge is Ownable, OmniNFTBridgeCore {
    constructor(
        address _owner,
        address _vizingPad,
        uint64 _currentChainId
    ) Ownable(_owner) OmniNFTBridgeCore(_vizingPad, _currentChainId) {
        DEFAULT_GASLIMIT = 2000000;
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

    function predictNFTAddress(
        uint64 destinationChainId,
        uint64 originChainId,
        address originTokenAddress,
        string memory name,
        string memory symbol
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
                                        abi.encode(name, symbol)
                                    )
                                )
                            )
                        )
                    )
                )
            );
    }

    function _deployContract(
        bytes32 salt,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) internal override returns (address) {
        TokenWrapped newWrappedToken = (new TokenWrapped){salt: salt}(
            name,
            symbol
        );
        TokenWrapped(newWrappedToken).setBaseURI(baseURI);
        return address(newWrappedToken);
    }

    function _claimAsset(
        address token,
        address tokenReceiver,
        uint256 tokenId
    ) internal override {
        TokenWrapped(token).mint(tokenReceiver, tokenId);
    }

    function _storeAsset(address token, uint256 tokenId) internal override {
        TokenWrapped(token).burn(tokenId);
    }

    function setMirrorBridges(
        uint64[] calldata chainIds,
        address[] calldata bridges
    ) external onlyOwner {
        _setMirrorBridges(chainIds, bridges);
    }

    function setMirrorGovernors(
        uint64[] calldata chainIds,
        address[] calldata governors
    ) external onlyOwner {
        _setMirrorGovernors(chainIds, governors);
    }
}
