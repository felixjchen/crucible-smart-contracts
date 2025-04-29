// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IAlloy } from "./interfaces/IAlloy.sol";
import { Alloy } from "./Alloy.sol";
import { AlloySpec, AlloySpecLib } from "./types/AlloySpec.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { Ingot } from "./Ingot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

contract Crucible is ICrucible, Ownable {
    using AlloySpecLib for AlloySpec;
    using IngotSpecLib for IngotSpec;

    IAlloy public immutable alloy_implementation;
    IIngot public immutable ingot_implementation;

    mapping(uint256 => address) alloyRegistry;
    mapping(uint256 => address) ingotRegistry;

    constructor(address _lzEndpoint, address _delegate) Ownable(msg.sender) {
        alloy_implementation = new Alloy(_lzEndpoint, _delegate);
        ingot_implementation = new Ingot(_lzEndpoint, _delegate);
    }

    function createAlloy(AlloySpec calldata _alloySpec) external returns (address) {
        _alloySpec.validate();

        uint256 _alloyId = _alloySpec.getId();

        require(alloyRegistry[_alloyId] == address(0), "Alloy already exists");

        address clone = Clones.clone(address(alloy_implementation));
        IAlloy(clone).initialize(_alloyId, _alloySpec, ICrucible(address(this)));
        alloyRegistry[_alloyId] = clone;

        return clone;
    }

    function createIngot(IngotSpec calldata _ingotSpec) external returns (address) {
        _ingotSpec.validate();

        uint256 _ingotId = _ingotSpec.getId();

        require(ingotRegistry[_ingotId] == address(0), "Ingot already exists");
        address clone = Clones.clone(address(ingot_implementation));
        IIngot(clone).initialize(_ingotId, _ingotSpec, ICrucible(address(this)));
        ingotRegistry[_ingotId] = clone;

        return clone;
    }
}
