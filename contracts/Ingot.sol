// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";
import { Mover } from "./Mover.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Ingot is ERC20, IIngot, Mover, Initializable {
    using IngotSpecLib for IngotSpec;

    ICrucible public crucible;

    uint256 public ingotId;
    IngotSpec private ingotSpec;

    string private ingotName;
    string private ingotSymbol;

    constructor() ERC20("IngotBaseImplementation", "IngotBaseImplementation") {}

    function initialize(
        ICrucible _crucible,
        uint256 _ingotId,
        IngotSpec calldata _ingotSpec
    ) public override initializer {
        require(address(_crucible) != address(0), "Crucible cannot be zero address");
        crucible = _crucible;

        ingotId = _ingotId;
        ingotSpec = _ingotSpec;

        ingotName = _ingotSpec.getName();
        ingotSymbol = _ingotSpec.getSymbol();
    }

    function spec() public view returns (IngotSpec memory) {
        return ingotSpec;
    }

    function name() public view override returns (string memory) {
        return ingotName;
    }

    function symbol() public view override returns (string memory) {
        return ingotSymbol;
    }

    // Wrap
    function fuse(uint256 amount) public payable {
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

    function crucibleBurn(address from, uint256 amount) external {
        require(msg.sender == address(crucible), "Only crucible can burn");
        _burn(from, amount);
    }

    function crucibleMint(address to, uint256 amount) external {
        require(msg.sender == address(crucible), "Only crucible can mint");
        _mint(to, amount);
    }
}
