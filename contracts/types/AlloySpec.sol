// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { CollectionType } from "./CollectionType.sol";
import { IngotSpec, IngotSpecLib } from "./IngotSpec.sol";

// TODO: Custom interfaces ?
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

struct AlloySpec {
    IngotSpec[] ingotSpecs;
}

library AlloySpecLib {
    using Strings for uint256;
    using IngotSpecLib for IngotSpec;

    function validate(AlloySpec calldata _alloySpec) public pure {
        assert(_alloySpec.ingotSpecs.length > 1);
        uint256 lastIngotSpecId = 0;
        for (uint256 i = 0; i < _alloySpec.ingotSpecs.length; ++i) {
            _alloySpec.ingotSpecs[i].validate();

            uint256 ingotSpecId = _alloySpec.ingotSpecs[i].getId();
            require(lastIngotSpecId < ingotSpecId, "IngotSpec ids must be ordered");
            lastIngotSpecId = ingotSpecId;
        }
    }

    function getId(AlloySpec calldata _alloySpec) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_alloySpec.ingotSpecs)));
    }

    function getName(AlloySpec memory _alloySpec) public view returns (string memory) {
        string memory symbol = "Alloy";
        for (uint i = 0; i < _alloySpec.ingotSpecs.length; ++i) {
            IngotSpec memory ingotSpec = _alloySpec.ingotSpecs[i];
            symbol = string.concat(symbol, " ", ingotSpec.getNameSuffix());
        }
        return symbol;
    }

    function getSymbol(AlloySpec memory _alloySpec) public view returns (string memory) {
        string memory symbol = "AO";
        for (uint i = 0; i < _alloySpec.ingotSpecs.length; ++i) {
            IngotSpec memory ingotSpec = _alloySpec.ingotSpecs[i];
            symbol = string.concat(symbol, " ", ingotSpec.getSymbolSuffix());
        }
        return symbol;
    }
}
