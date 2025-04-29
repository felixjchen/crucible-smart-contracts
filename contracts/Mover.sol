// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { IngotSpec } from "./types/IngotSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Mover {
    using SafeERC20 for IERC20;

    function take(IngotSpec memory _ingotSpec, uint256 amount) public {
        if (_ingotSpec.collectionType == CollectionType.ERC20) {
            IERC20(_ingotSpec.collection).safeTransferFrom(msg.sender, address(this), amount);
        } else if (_ingotSpec.collectionType == CollectionType.ERC721) {
            for (uint i = 0; i < _ingotSpec.ids.length; ++i) {
                IERC721(_ingotSpec.collection).safeTransferFrom(msg.sender, address(this), _ingotSpec.ids[i]);
            }
        } else if (_ingotSpec.collectionType == CollectionType.ERC1155) {
            uint256[] memory amounts = new uint256[](_ingotSpec.ids.length);
            for (uint i = 0; i < _ingotSpec.ids.length; ++i) {
                amounts[i] = _ingotSpec.amounts[i] * amount;
            }
            IERC1155(_ingotSpec.collection).safeBatchTransferFrom(
                msg.sender,
                address(this),
                _ingotSpec.ids,
                amounts,
                ""
            );
        }
    }

    function give(IngotSpec memory _ingotSpec, uint256 amount) public {
        if (_ingotSpec.collectionType == CollectionType.ERC20) {
            IERC20(_ingotSpec.collection).safeTransferFrom(address(this), msg.sender, amount);
        } else if (_ingotSpec.collectionType == CollectionType.ERC721) {
            for (uint i = 0; i < _ingotSpec.ids.length; ++i) {
                IERC721(_ingotSpec.collection).safeTransferFrom(address(this), msg.sender, _ingotSpec.ids[i]);
            }
        } else if (_ingotSpec.collectionType == CollectionType.ERC1155) {
            uint256[] memory amounts = new uint256[](_ingotSpec.ids.length);
            for (uint i = 0; i < _ingotSpec.ids.length; ++i) {
                amounts[i] = _ingotSpec.amounts[i] * amount;
            }
            IERC1155(_ingotSpec.collection).safeBatchTransferFrom(
                address(this),
                msg.sender,
                _ingotSpec.ids,
                amounts,
                ""
            );
        }
    }
}
