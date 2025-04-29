// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IAlloy } from "./interfaces/IAlloy.sol";
import { AlloySpec, AlloySpecLib } from "./types/AlloySpec.sol";
import { IngotSpec } from "./types/IngotSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";
import { Mover } from "./Mover.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Alloy is IAlloy, Mover, OFT, Initializable {
    using AlloySpecLib for AlloySpec;

    uint256 public alloyId;
    AlloySpec public alloySpec;
    ICrucible public crucible;

    string private alloyName;
    string private alloySymbol;

    constructor(
        address _lzEndpoint,
        address _delegate
    ) OFT("AlloyBaseImplementation", "AlloyBaseImplementation", _lzEndpoint, _delegate) Ownable(msg.sender) {}

    function initialize(
        uint256 _alloyId,
        AlloySpec calldata _alloySpec,
        ICrucible _crucible
    ) public override initializer {
        require(address(_crucible) != address(0), "Crucible cannot be zero address");

        alloyId = _alloyId;
        alloySpec = _alloySpec;
        crucible = _crucible;

        alloyName = _alloySpec.getName();
        alloySymbol = _alloySpec.getSymbol();
    }

    function name() public view override returns (string memory) {
        return alloyName;
    }

    function symbol() public view override returns (string memory) {
        return alloySymbol;
    }

    // Wrap
    function fuse(uint256 amount) public {
        AlloySpec memory _alloySpec = alloySpec;
        for (uint256 i = 0; i < _alloySpec.ingotSpecs.length; ++i) {
            IngotSpec memory ingotSpec = _alloySpec.ingotSpecs[i];
            take(ingotSpec, amount);
        }
        _mint(tx.origin, amount);
    }

    // Unwrap
    function dissolve(uint256 amount) public {
        AlloySpec memory _alloySpec = alloySpec;
        for (uint256 i = 0; i < _alloySpec.ingotSpecs.length; ++i) {
            IngotSpec memory ingotSpec = _alloySpec.ingotSpecs[i];
            give(ingotSpec, amount);
        }
        _burn(tx.origin, amount);
    }
}
