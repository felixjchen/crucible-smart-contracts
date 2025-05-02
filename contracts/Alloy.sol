// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IAlloy } from "./interfaces/IAlloy.sol";
import { AlloySpec, AlloySpecLib } from "./types/AlloySpec.sol";
import { IngotSpec } from "./types/IngotSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";
import { Mover } from "./Mover.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Alloy is IAlloy, ERC20, Mover, Initializable {
    using AlloySpecLib for AlloySpec;

    ICrucible public crucible;

    uint256 public alloyId;
    AlloySpec private alloySpec;

    string private alloyName;
    string private alloySymbol;

    constructor() ERC20("AlloyBaseImplementation", "AlloyBaseImplementation") {}

    function initialize(
        ICrucible _crucible,
        uint256 _alloyId,
        AlloySpec calldata _alloySpec
    ) public override initializer {
        require(address(_crucible) != address(0), "Crucible cannot be zero address");
        crucible = _crucible;

        alloyId = _alloyId;
        alloySpec = _alloySpec;

        alloyName = _alloySpec.getName();
        alloySymbol = _alloySpec.getSymbol();
    }

    function spec() public view returns (AlloySpec memory) {
        return alloySpec;
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
        _mint(msg.sender, amount);
    }

    // Unwrap
    function dissolve(uint256 amount) public {
        AlloySpec memory _alloySpec = alloySpec;
        for (uint256 i = 0; i < _alloySpec.ingotSpecs.length; ++i) {
            IngotSpec memory ingotSpec = _alloySpec.ingotSpecs[i];
            give(ingotSpec, amount);
        }
        _burn(msg.sender, amount);
    }

    function crucibleBurn(address from, uint256 amount) external {
        require(msg.sender == address(crucible), "Only crucible can burn");
        _burn(from, amount);
    }

    function crucibleMint(address to, uint256 amount) external {
        require(msg.sender == address(crucible), "Only crucible can mint");
        _mint(to, amount);
    }
}
