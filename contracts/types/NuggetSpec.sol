// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { CollectionType } from "./CollectionType.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/*
| Token Type    | collection            | decimalsOrFloorAmount    | ids               | amounts                           |
|---------------|-----------------------|--------------------------|-------------------|-----------------------------------|
| Native        | `== address(0)`       | `>= 0`                   | `length == 0`     | `length == 0`                     |
| ERC20         | `!= address(0)`       | `>= 0`                   | `length == 0`     | `length == 0`                     |
| ERC721FLOOR   | `!= address(0)`       | `> 0`                    | `length == 0`     | `length == 0`                     |
| ERC721        | `!= address(0)`       | `== 0`                   | `length > 0`      | `length == 0`                     |
| ERC1155       | `!= address(0)`       | `== 0`                   | `length > 0`      | `length > 0` (== `ids.length`)    |
*/
struct NuggetSpec {
    CollectionType collectionType;
    address collection;
    uint24 decimalsOrFloorAmount;
    uint256[] ids;
    uint256[] amounts;
}

interface NameAndSymbol {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);
}

library NuggetSpecLib {
    using Strings for uint256;
    using Strings for uint24;

    function getId(NuggetSpec memory _nuggetSpec) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_nuggetSpec)));
    }

    function validate(NuggetSpec calldata _nuggetSpec) public pure {
        if (_nuggetSpec.collectionType == CollectionType.NATIVE) {
            require(_nuggetSpec.collection == address(0), "NuggetSpec.collection must be zero address for Native");
            require(_nuggetSpec.decimalsOrFloorAmount >= 0, "NuggetSpec.decimals must be >= 0 for Native");
            require(_nuggetSpec.ids.length == 0, "NuggetSpec.ids must be empty for Native");
            require(_nuggetSpec.amounts.length == 0, "NuggetSpec.amounts must be empty for Native");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC20) {
            require(_nuggetSpec.collection != address(0), "NuggetSpec.collection cannot be zero address for ERC20");
            require(_nuggetSpec.decimalsOrFloorAmount >= 0, "NuggetSpec.decimals must be >= 0 for ERC20");
            require(_nuggetSpec.ids.length == 0, "NuggetSpec.ids must be empty for ERC20");
            require(_nuggetSpec.amounts.length == 0, "NuggetSpec.amounts must be empty for ERC20");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721FLOOR) {
            require(
                _nuggetSpec.collection != address(0),
                "NuggetSpec.collection cannot be zero address for ERC721FLOOR"
            );
            require(_nuggetSpec.decimalsOrFloorAmount > 0, "NuggetSpec.decimals must be > 0 for ERC721FLOOR");
            require(_nuggetSpec.ids.length == 0, "NuggetSpec.ids must be empty for ERC721FLOOR");
            require(_nuggetSpec.amounts.length == 0, "NuggetSpec.amounts must be empty for ERC721FLOOR");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721) {
            require(_nuggetSpec.collection != address(0), "NuggetSpec.collection cannot be zero address for ERC721");
            require(_nuggetSpec.decimalsOrFloorAmount == 0, "NuggetSpec.decimals must be 0 for ERC721");
            require(_nuggetSpec.ids.length > 0, "NuggetSpec.ids must not be empty for ERC721");
            require(_nuggetSpec.amounts.length == 0, "NuggetSpec.amounts must be empty for ERC721");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC1155) {
            require(_nuggetSpec.collection != address(0), "NuggetSpec.collection cannot be zero address for ERC1155");
            require(_nuggetSpec.decimalsOrFloorAmount == 0, "NuggetSpec.decimals must be 0 for ERC1155");
            require(_nuggetSpec.ids.length > 0, "NuggetSpec.ids must not be empty for ERC1155");
            require(_nuggetSpec.amounts.length > 0, "NuggetSpec.amounts must not be empty for ERC1155");
            require(
                _nuggetSpec.ids.length == _nuggetSpec.amounts.length,
                "NuggetSpec.ids and NuggetSpec.amounts must be the same length for ERC1155"
            );
        } else {
            revert("Invalid collection type");
        }
    }

    function getNameSuffix(NuggetSpec calldata _nuggetSpec) public view returns (string memory) {
        if (_nuggetSpec.collectionType == CollectionType.NATIVE) {
            return
                string.concat(
                    "NATIVE:",
                    block.chainid.toString(),
                    ":10^",
                    Strings.toString(uint256(_nuggetSpec.decimalsOrFloorAmount))
                );
        } else if (_nuggetSpec.collectionType == CollectionType.ERC20) {
            return
                string.concat(
                    "ERC20:",
                    NameAndSymbol(_nuggetSpec.collection).name(),
                    ":10^",
                    Strings.toString(uint256(_nuggetSpec.decimalsOrFloorAmount))
                );
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721FLOOR) {
            string memory name = NameAndSymbol(_nuggetSpec.collection).name();
            name = string.concat("ERC721:", name, ":", _nuggetSpec.decimalsOrFloorAmount.toString(), "xFLOOR");
            return name;
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721) {
            string memory name = NameAndSymbol(_nuggetSpec.collection).name();
            name = string.concat("ERC721:", name, ":");
            for (uint256 i = 0; i < _nuggetSpec.ids.length - 1; ++i) {
                name = string.concat(name, _nuggetSpec.ids[i].toString(), ",");
            }
            name = string.concat(name, _nuggetSpec.ids[_nuggetSpec.ids.length - 1].toString());
            return name;
        } else if (_nuggetSpec.collectionType == CollectionType.ERC1155) {
            string memory name = Strings.toHexString(uint256(uint160(_nuggetSpec.collection)), 20);
            name = string.concat("ERC1155:", name, ":");
            for (uint256 i = 0; i < _nuggetSpec.ids.length - 1; ++i) {
                name = string.concat(name, _nuggetSpec.ids[i].toString(), "x", _nuggetSpec.amounts[i].toString(), ",");
            }
            name = string.concat(
                name,
                _nuggetSpec.ids[_nuggetSpec.ids.length - 1].toString(),
                "x",
                _nuggetSpec.amounts[_nuggetSpec.ids.length - 1].toString()
            );
            return name;
        } else {
            revert("Invalid collection type");
        }
    }

    function getSymbolSuffix(NuggetSpec memory _nuggetSpec) public view returns (string memory) {
        if (_nuggetSpec.collectionType == CollectionType.NATIVE) {
            return string.concat("NATIVE:", block.chainid.toString());
        } else if (_nuggetSpec.collectionType == CollectionType.ERC20) {
            return NameAndSymbol(_nuggetSpec.collection).symbol();
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721FLOOR) {
            string memory symbol = NameAndSymbol(_nuggetSpec.collection).symbol();
            return string.concat(symbol, ":", _nuggetSpec.decimalsOrFloorAmount.toString(), "xFLOOR");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721) {
            string memory symbol = NameAndSymbol(_nuggetSpec.collection).symbol();
            symbol = string.concat(symbol, ":");
            for (uint256 i = 0; i < _nuggetSpec.ids.length - 1; ++i) {
                symbol = string.concat(symbol, _nuggetSpec.ids[i].toString(), ",");
            }
            symbol = string.concat(symbol, _nuggetSpec.ids[_nuggetSpec.ids.length - 1].toString());
            return symbol;
        } else if (_nuggetSpec.collectionType == CollectionType.ERC1155) {
            string memory symbol = Strings.toHexString(uint256(uint160(_nuggetSpec.collection)), 20);
            symbol = string.concat(symbol, ":");
            for (uint256 i = 0; i < _nuggetSpec.ids.length - 1; ++i) {
                symbol = string.concat(
                    symbol,
                    _nuggetSpec.ids[i].toString(),
                    "x",
                    _nuggetSpec.amounts[i].toString(),
                    ","
                );
            }
            symbol = string.concat(
                symbol,
                _nuggetSpec.ids[_nuggetSpec.ids.length - 1].toString(),
                "x",
                _nuggetSpec.amounts[_nuggetSpec.ids.length - 1].toString()
            );
            return symbol;
        } else {
            revert("Invalid collection type");
        }
    }
}
