// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { CollectionType } from "./CollectionType.sol";
import { NuggetSpec, NuggetSpecLib } from "./NuggetSpec.sol";

// TODO: Custom interfaces ?
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

struct IngotSpec {
    NuggetSpec[] nuggetSpecs;
}

library IngotSpecLib {
    using Strings for uint256;
    using NuggetSpecLib for NuggetSpec;

    function getId(IngotSpec calldata _ingotSpec) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_ingotSpec.nuggetSpecs)));
    }

    function validate(IngotSpec calldata _ingotSpec) public pure {
        assert(_ingotSpec.nuggetSpecs.length > 1);
        uint256 lastNuggetSpecId = 0;
        for (uint256 i = 0; i < _ingotSpec.nuggetSpecs.length; ++i) {
            _ingotSpec.nuggetSpecs[i].validate();

            uint256 ingotSpecId = _ingotSpec.nuggetSpecs[i].getId();
            require(lastNuggetSpecId < ingotSpecId, "NuggetSpec ids must be ordered");
            lastNuggetSpecId = ingotSpecId;
        }
    }

    function getName(IngotSpec memory _ingotSpec) public view returns (string memory) {
        string memory symbol = "Ingot";
        for (uint i = 0; i < _ingotSpec.nuggetSpecs.length; ++i) {
            NuggetSpec memory ingotSpec = _ingotSpec.nuggetSpecs[i];
            symbol = string.concat(symbol, " ", ingotSpec.getNameSuffix());
        }
        return symbol;
    }

    function getSymbol(IngotSpec memory _ingotSpec) public view returns (string memory) {
        string memory symbol = "IO";
        for (uint i = 0; i < _ingotSpec.nuggetSpecs.length; ++i) {
            NuggetSpec memory ingotSpec = _ingotSpec.nuggetSpecs[i];
            symbol = string.concat(symbol, " ", ingotSpec.getSymbolSuffix());
        }
        return symbol;
    }
}
