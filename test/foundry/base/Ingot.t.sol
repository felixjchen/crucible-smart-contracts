// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Ingot } from "../../../contracts/Ingot.sol";
import { IngotSpec } from "../../../contracts/types/IngotSpec.sol";

// Mock imports
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { ERC721Mock } from "../../mocks/ERC721Mock.sol";
import { ERC1155Mock } from "../../mocks/ERC1155Mock.sol";

// Forge imports
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract IngotBaseTest is TestHelperOz5 {
    address private endpoint = makeAddr("endpoint");
    address private owner = makeAddr("owner");
    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");
    uint256 private initialBalance = 100 ether;

    Ingot private ingot;

    ERC20Mock private erc20mock;
    ERC721Mock private erc721mock;
    ERC1155Mock private erc1155mock;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        ingot = new Ingot(endpoints[1], owner);
        erc20mock = new ERC20Mock("ERC20Mock", "ERC20Mock");
        erc721mock = new ERC721Mock("ERC721Mock", "ERC721Mock");
        erc1155mock = new ERC1155Mock("ERC1155Mock", "ERC1155Mock");

        // mint tokens
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
    }

    function test_erc20() public {}
}
