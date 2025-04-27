// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

enum CollectionType {
    ERC1155,
    ERC721,
    ERC20
}

contract Alloy is OFT {
    address collection;
    CollectionType collectionType;
    uint256[] ids; // Used in ERC1155, ERC721
    uint256[] amounts; // Used in ERC1155, ERC20

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}
}
