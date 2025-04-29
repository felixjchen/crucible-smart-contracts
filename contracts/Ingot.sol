// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";
import { Mover } from "./Mover.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Ingot is IIngot, Mover, OFT, Initializable {
    using IngotSpecLib for IngotSpec;

    uint256 public ingotId;
    IngotSpec public ingotSpec;
    ICrucible public crucible;

    string private ingotName;
    string private ingotSymbol;

    constructor(
        address _lzEndpoint,
        address _delegate
    ) OFT("IngotBaseImplementation", "IngotBaseImplementation", _lzEndpoint, _delegate) Ownable(_delegate) {}

    function initialize(
        uint256 _ingotId,
        IngotSpec calldata _ingotSpec,
        ICrucible _crucible
    ) public override initializer {
        require(address(_crucible) != address(0), "Crucible cannot be zero address");

        ingotId = _ingotId;
        ingotSpec = _ingotSpec;
        crucible = _crucible;

        ingotName = _ingotSpec.getName();
        ingotSymbol = _ingotSpec.getSymbol();
    }

    function name() public view override returns (string memory) {
        return ingotName;
    }

    function symbol() public view override returns (string memory) {
        return ingotSymbol;
    }

    // Wrap
    function fuse(uint256 amount) public {
        IngotSpec memory _ingotSpec = ingotSpec;
        take(_ingotSpec, amount);
        _mint(msg.sender, amount);
    }

    // Unwrap
    function dissolve(uint256 amount) public {
        IngotSpec memory _ingotSpec = ingotSpec;
        give(_ingotSpec, amount);
        _burn(msg.sender, amount);
    }
}
