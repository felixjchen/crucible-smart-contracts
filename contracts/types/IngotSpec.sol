// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { CollectionType } from "./CollectionType.sol";

// TODO: Custom interfaces ?
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// In ERC20, we omit ids and amounts. We take on the wrapped ERC20's base unit.
// In ERC721, we omit amounts. But, we use the ids array.
// In ERC1155, we use both ids and amounts.
struct IngotSpec {
    address collection;
    CollectionType collectionType;
    uint256[] ids;
    uint256[] amounts;
}

library IngotSpecLib {
    using Strings for uint256;

    function getId(IngotSpec calldata _ingotSpec) public pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(_ingotSpec.collection, _ingotSpec.collectionType, _ingotSpec.ids, _ingotSpec.amounts)
                )
            );
    }

    function validate(IngotSpec calldata _ingotSpec) public pure {
        require(_ingotSpec.collection != address(0), "IngotSpec.collection cannot be zero address");

        if (_ingotSpec.collectionType == CollectionType.ERC20) {
            require(_ingotSpec.ids.length == 0, "IngotSpec.ids must be empty for ERC20");
            require(_ingotSpec.amounts.length == 0, "IngotSpec.amounts must be empty for ERC20");
        } else if (_ingotSpec.collectionType == CollectionType.ERC721) {
            require(_ingotSpec.ids.length > 0, "IngotSpec.ids must not be empty for ERC721");
            require(_ingotSpec.amounts.length == 0, "IngotSpec.amounts must be empty for ERC721");
        } else if (_ingotSpec.collectionType == CollectionType.ERC1155) {
            require(_ingotSpec.ids.length > 0, "IngotSpec.ids must not be empty for ERC1155");
            require(_ingotSpec.amounts.length > 0, "IngotSpec.amounts must not be empty for ERC1155");
            require(
                _ingotSpec.ids.length == _ingotSpec.amounts.length,
                "IngotSpec.ids and IngotSpec.amounts must be the same length for ERC1155"
            );
        } else {
            revert("Invalid collection type");
        }
    }

    function getNameSuffix(IngotSpec calldata _ingotSpec) public view returns (string memory) {
        if (_ingotSpec.collectionType == CollectionType.ERC20) {
            return string.concat("ERC20:", ERC20(_ingotSpec.collection).name());
        } else if (_ingotSpec.collectionType == CollectionType.ERC721) {
            string memory name = ERC721(_ingotSpec.collection).name();
            name = string.concat("ERC721:", name, ":");
            for (uint256 i = 0; i < _ingotSpec.ids.length - 1; ++i) {
                name = string.concat(name, _ingotSpec.ids[i].toString(), ",");
            }
            name = string.concat(name, _ingotSpec.ids[_ingotSpec.ids.length - 1].toString());
            return name;
        } else if (_ingotSpec.collectionType == CollectionType.ERC1155) {
            string memory name = Strings.toHexString(uint256(uint160(_ingotSpec.collection)), 20);
            name = string.concat("ERC1155:", name, ":");
            for (uint256 i = 0; i < _ingotSpec.ids.length - 1; ++i) {
                name = string.concat(name, _ingotSpec.ids[i].toString(), "x", _ingotSpec.amounts[i].toString(), ",");
            }
            name = string.concat(
                name,
                _ingotSpec.ids[_ingotSpec.ids.length - 1].toString(),
                "x",
                _ingotSpec.amounts[_ingotSpec.ids.length - 1].toString()
            );
            return name;
        } else {
            revert("Invalid collection type");
        }
    }

    function getName(IngotSpec calldata _ingotSpec) public view returns (string memory) {
        return string.concat("Ingot ", getNameSuffix(_ingotSpec));
    }

    function getSymbolSuffix(IngotSpec memory _ingotSpec) public view returns (string memory) {
        if (_ingotSpec.collectionType == CollectionType.ERC20) {
            return ERC20(_ingotSpec.collection).symbol();
        } else if (_ingotSpec.collectionType == CollectionType.ERC721) {
            string memory symbol = ERC721(_ingotSpec.collection).symbol();
            symbol = string.concat(symbol, ":");
            for (uint256 i = 0; i < _ingotSpec.ids.length - 1; ++i) {
                symbol = string.concat(symbol, _ingotSpec.ids[i].toString(), ",");
            }
            symbol = string.concat(symbol, _ingotSpec.ids[_ingotSpec.ids.length - 1].toString());
            return symbol;
        } else if (_ingotSpec.collectionType == CollectionType.ERC1155) {
            string memory symbol = Strings.toHexString(uint256(uint160(_ingotSpec.collection)), 20);
            symbol = string.concat(symbol, ":");
            for (uint256 i = 0; i < _ingotSpec.ids.length - 1; ++i) {
                symbol = string.concat(
                    symbol,
                    _ingotSpec.ids[i].toString(),
                    "x",
                    _ingotSpec.amounts[i].toString(),
                    ","
                );
            }
            symbol = string.concat(
                symbol,
                _ingotSpec.ids[_ingotSpec.ids.length - 1].toString(),
                "x",
                _ingotSpec.amounts[_ingotSpec.ids.length - 1].toString()
            );
            return symbol;
        } else {
            revert("Invalid collection type");
        }
    }

    function getSymbol(IngotSpec memory _ingotSpec) public view returns (string memory) {
        return string.concat("IO ", getSymbolSuffix(_ingotSpec));
    }
}
