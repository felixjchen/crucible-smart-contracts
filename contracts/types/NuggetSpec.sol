// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { CollectionType } from "./CollectionType.sol";

// TODO: Custom interfaces ?
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/*
| Token Type     | ids | amounts | decimals                                |
|----------------|:---:|:-------:|-----------------------------------------|
| Native         | —   | —       | ✓ (e.g. 10^6 for USDC, 10^18 for ETH)   |
| ERC20          | —   | —       | ✓ (e.g. 10^6 for USDC, 10^18 for ETH)   |
| ERC721FLOOR    | —   | —       | —                                       |
| ERC721         | ✓   | —       | —                                       |
| ERC1155        | ✓   | ✓       | —                                       |
*/
struct NuggetSpec {
    address collection;
    CollectionType collectionType;
    uint8 decimals;
    uint256[] ids;
    uint256[] amounts;
}

library NuggetSpecLib {
    using Strings for uint256;

    function getId(NuggetSpec memory _nugetSpec) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_nugetSpec)));
    }

    function validate(NuggetSpec calldata _nugetSpec) public pure {
        require(_nugetSpec.collection != address(0), "NuggetSpec.collection cannot be zero address");

        if (_nugetSpec.collectionType == CollectionType.NATIVE) {
            require(_nugetSpec.ids.length == 0, "NuggetSpec.ids must be empty for Native");
            require(_nugetSpec.amounts.length == 0, "NuggetSpec.amounts must be empty for Native");
        } else if (_nugetSpec.collectionType == CollectionType.ERC20) {
            require(_nugetSpec.ids.length == 0, "NuggetSpec.ids must be empty for ERC20");
            require(_nugetSpec.amounts.length == 0, "NuggetSpec.amounts must be empty for ERC20");
        } else if (_nugetSpec.collectionType == CollectionType.ERC721) {
            require(_nugetSpec.decimals == 0, "NuggetSpec.decimals must be 0 for ERC721");
            require(_nugetSpec.ids.length > 0, "NuggetSpec.ids must not be empty for ERC721");
            require(_nugetSpec.amounts.length == 0, "NuggetSpec.amounts must be empty for ERC721");
        } else if (_nugetSpec.collectionType == CollectionType.ERC721FLOOR) {
            require(_nugetSpec.decimals == 0, "NuggetSpec.decimals must be 0 for ERC721FLOOR");
            require(_nugetSpec.ids.length == 0, "NuggetSpec.ids must be empty for ERC721FLOOR");
            require(_nugetSpec.amounts.length == 0, "NuggetSpec.amounts must be empty for ERC721FLOOR");
        } else if (_nugetSpec.collectionType == CollectionType.ERC1155) {
            require(_nugetSpec.decimals == 0, "NuggetSpec.decimals must be 0 for ERC1155");
            require(_nugetSpec.ids.length > 0, "NuggetSpec.ids must not be empty for ERC1155");
            require(_nugetSpec.amounts.length > 0, "NuggetSpec.amounts must not be empty for ERC1155");
            require(
                _nugetSpec.ids.length == _nugetSpec.amounts.length,
                "NuggetSpec.ids and NuggetSpec.amounts must be the same length for ERC1155"
            );
        } else {
            revert("Invalid collection type");
        }
    }

    function getNameSuffix(NuggetSpec calldata _nugetSpec) public view returns (string memory) {
        if (_nugetSpec.collectionType == CollectionType.NATIVE) {
            return string.concat("NATIVE:10^", Strings.toString(uint256(_nugetSpec.decimals)));
        } else if (_nugetSpec.collectionType == CollectionType.ERC20) {
            return
                string.concat(
                    "ERC20:",
                    ERC20(_nugetSpec.collection).name(),
                    ":10^",
                    Strings.toString(uint256(_nugetSpec.decimals))
                );
        } else if (_nugetSpec.collectionType == CollectionType.ERC721FLOOR) {
            string memory name = ERC721(_nugetSpec.collection).name();
            name = string.concat("ERC721FLOOR:", name);
            return name;
        } else if (_nugetSpec.collectionType == CollectionType.ERC721) {
            string memory name = ERC721(_nugetSpec.collection).name();
            name = string.concat("ERC721:", name, ":");
            for (uint256 i = 0; i < _nugetSpec.ids.length - 1; ++i) {
                name = string.concat(name, _nugetSpec.ids[i].toString(), ",");
            }
            name = string.concat(name, _nugetSpec.ids[_nugetSpec.ids.length - 1].toString());
            return name;
        } else if (_nugetSpec.collectionType == CollectionType.ERC1155) {
            string memory name = Strings.toHexString(uint256(uint160(_nugetSpec.collection)), 20);
            name = string.concat("ERC1155:", name, ":");
            for (uint256 i = 0; i < _nugetSpec.ids.length - 1; ++i) {
                name = string.concat(name, _nugetSpec.ids[i].toString(), "x", _nugetSpec.amounts[i].toString(), ",");
            }
            name = string.concat(
                name,
                _nugetSpec.ids[_nugetSpec.ids.length - 1].toString(),
                "x",
                _nugetSpec.amounts[_nugetSpec.ids.length - 1].toString()
            );
            return name;
        } else {
            revert("Invalid collection type");
        }
    }

    function getSymbolSuffix(NuggetSpec memory _nugetSpec) public view returns (string memory) {
        if (_nugetSpec.collectionType == CollectionType.NATIVE) {
            return "NATIVE";
        } else if (_nugetSpec.collectionType == CollectionType.ERC20) {
            return ERC20(_nugetSpec.collection).symbol();
        } else if (_nugetSpec.collectionType == CollectionType.ERC721FLOOR) {
            string memory symbol = ERC721(_nugetSpec.collection).symbol();
            return symbol;
        } else if (_nugetSpec.collectionType == CollectionType.ERC721) {
            string memory symbol = ERC721(_nugetSpec.collection).symbol();
            symbol = string.concat(symbol, ":");
            for (uint256 i = 0; i < _nugetSpec.ids.length - 1; ++i) {
                symbol = string.concat(symbol, _nugetSpec.ids[i].toString(), ",");
            }
            symbol = string.concat(symbol, _nugetSpec.ids[_nugetSpec.ids.length - 1].toString());
            return symbol;
        } else if (_nugetSpec.collectionType == CollectionType.ERC1155) {
            string memory symbol = Strings.toHexString(uint256(uint160(_nugetSpec.collection)), 20);
            symbol = string.concat(symbol, ":");
            for (uint256 i = 0; i < _nugetSpec.ids.length - 1; ++i) {
                symbol = string.concat(
                    symbol,
                    _nugetSpec.ids[i].toString(),
                    "x",
                    _nugetSpec.amounts[i].toString(),
                    ","
                );
            }
            symbol = string.concat(
                symbol,
                _nugetSpec.ids[_nugetSpec.ids.length - 1].toString(),
                "x",
                _nugetSpec.amounts[_nugetSpec.ids.length - 1].toString()
            );
            return symbol;
        } else {
            revert("Invalid collection type");
        }
    }
}
