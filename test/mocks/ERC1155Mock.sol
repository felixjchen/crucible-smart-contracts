// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ERC1155Mock is ERC1155 {
    constructor(string memory _name, string memory _symbol) ERC1155("") {}

    function mint(address _to, uint256 _tokenId, uint256 _amount) public {
        _mint(_to, _tokenId, _amount, "");
    }
}
