// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Ingot } from "../../../contracts/Ingot.sol";
import { ICrucible } from "../../../contracts/interfaces/ICrucible.sol";
import { IngotSpec, IngotSpecLib } from "../../../contracts/types/IngotSpec.sol";
import { CollectionType } from "../../../contracts/types/CollectionType.sol";

// Mock imports
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ERC721Mock } from "../mocks/ERC721Mock.sol";
import { ERC1155Mock } from "../mocks/ERC1155Mock.sol";

// Forge imports
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract IngotTest is TestHelperOz5 {
    using IngotSpecLib for IngotSpec;

    address private crucible = makeAddr("crucible");
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

        ingot = new Ingot();
        erc20mock = new ERC20Mock("BRINE", "BRINE");
        erc721mock = new ERC721Mock("MoredCrepePopeClub", "MoredCrepePopeClub");
        erc1155mock = new ERC1155Mock("PurpleBeta", "PurpleBeta");

        // mint tokens
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
    }

    function test_validateIngotSpec() public {}

    function test_initializeOnce() public {}

    function test_erc20() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        IngotSpec memory ingotSpec = IngotSpec({
            collection: address(erc20mock),
            collectionType: CollectionType.ERC20,
            ids: ids,
            amounts: amounts
        });

        uint256 ingotId = ingotSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        assertEq(ingot.name(), "Ingot ERC20:BRINE");
        assertEq(ingot.symbol(), "IO BRINE");

        assertEq(ingot.spec().collection, address(erc20mock));
        assertEq(abi.encode(ingot.spec().collectionType), abi.encode(CollectionType.ERC20));
        assertEq(ingot.spec().ids.length, 0);
        assertEq(ingot.spec().amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc20mock.mint(userA, initialBalance);
        erc20mock.approve(address(ingot), initialBalance);

        ingot.fuse(initialBalance);
        assertEq(ingot.balanceOf(userA), initialBalance);
        assertEq(ingot.totalSupply(), initialBalance);
        assertEq(erc20mock.balanceOf(address(ingot)), initialBalance);
        assertEq(erc20mock.balanceOf(userA), 0);

        ingot.dissolve(initialBalance);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc20mock.balanceOf(address(ingot)), 0);
        assertEq(erc20mock.balanceOf(userA), initialBalance);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc20mock.mint(userB, 1 wei);
        vm.expectRevert();
        ingot.fuse(10 wei);

        erc20mock.approve(address(ingot), 10 wei);
        vm.expectRevert();
        ingot.fuse(10 wei);

        erc20mock.mint(userB, 9 wei);

        vm.expectRevert();
        ingot.dissolve(10 wei);
        vm.stopPrank();
    }

    function test_erc721() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](0);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        IngotSpec memory ingotSpec = IngotSpec({
            collection: address(erc721mock),
            collectionType: CollectionType.ERC721,
            ids: ids,
            amounts: amounts
        });

        uint256 ingotId = ingotSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        assertEq(ingot.name(), "Ingot ERC721:MoredCrepePopeClub:1,2,3");
        assertEq(ingot.symbol(), "IO MoredCrepePopeClub:1,2,3");

        assertEq(ingot.spec().collection, address(erc721mock));
        assertEq(abi.encode(ingot.spec().collectionType), abi.encode(CollectionType.ERC721));
        assertEq(ingot.spec().ids[0], 1);
        assertEq(ingot.spec().ids[1], 2);
        assertEq(ingot.spec().ids[2], 3);
        assertEq(ingot.spec().amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc721mock.mint(userA, 1);
        erc721mock.mint(userA, 2);
        erc721mock.mint(userA, 3);
        erc721mock.setApprovalForAll(address(ingot), true);

        ingot.fuse(1);
        assertEq(ingot.balanceOf(userA), 1);
        assertEq(ingot.totalSupply(), 1);
        assertEq(erc721mock.ownerOf(1), address(ingot));
        assertEq(erc721mock.ownerOf(2), address(ingot));
        assertEq(erc721mock.ownerOf(3), address(ingot));
        assertEq(erc721mock.balanceOf(address(ingot)), 3);
        assertEq(erc721mock.balanceOf(userA), 0);

        ingot.dissolve(1);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc721mock.ownerOf(1), address(userA));
        assertEq(erc721mock.ownerOf(2), address(userA));
        assertEq(erc721mock.ownerOf(3), address(userA));
        assertEq(erc721mock.balanceOf(userA), 3);
        assertEq(erc721mock.balanceOf(address(ingot)), 0);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc721mock.mint(userB, 4);
        erc721mock.mint(userB, 5);
        erc721mock.mint(userB, 6);
        erc721mock.setApprovalForAll(address(ingot), true);
        vm.expectRevert();
        ingot.fuse(1);
        vm.expectRevert();
        ingot.dissolve(1);
        vm.stopPrank();
    }

    function test_erc1155() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        amounts[0] = 1;
        amounts[1] = 2;
        amounts[2] = 3;

        IngotSpec memory ingotSpec = IngotSpec({
            collection: address(erc1155mock),
            collectionType: CollectionType.ERC1155,
            ids: ids,
            amounts: amounts
        });

        uint256 ingotId = ingotSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        string memory collection_string = Strings.toHexString(uint256(uint160(ingotSpec.collection)), 20);
        string memory name = string.concat("Ingot ERC1155:", collection_string, ":1x1,2x2,3x3");
        string memory symbol = string.concat("IO ", collection_string, ":1x1,2x2,3x3");
        assertEq(ingot.name(), name);
        assertEq(ingot.symbol(), symbol);
        assertEq(ingot.spec().collection, address(erc1155mock));
        assertEq(abi.encode(ingot.spec().collectionType), abi.encode(CollectionType.ERC1155));
        assertEq(ingot.spec().ids[0], 1);
        assertEq(ingot.spec().ids[1], 2);
        assertEq(ingot.spec().ids[2], 3);
        assertEq(ingot.spec().amounts[0], 1);
        assertEq(ingot.spec().amounts[1], 2);
        assertEq(ingot.spec().amounts[2], 3);

        // Bunch of success cases
        vm.startPrank(userA);
        erc1155mock.mint(userA, 1, 1);
        erc1155mock.mint(userA, 2, 2);
        erc1155mock.mint(userA, 3, 3);
        erc1155mock.setApprovalForAll(address(ingot), true);
        ingot.fuse(1);
        assertEq(ingot.balanceOf(userA), 1);
        assertEq(ingot.totalSupply(), 1);
        assertEq(erc1155mock.balanceOf(address(ingot), 1), 1);
        assertEq(erc1155mock.balanceOf(address(ingot), 2), 2);
        assertEq(erc1155mock.balanceOf(address(ingot), 3), 3);
        assertEq(erc1155mock.balanceOf(userA, 1), 0);
        assertEq(erc1155mock.balanceOf(userA, 2), 0);
        assertEq(erc1155mock.balanceOf(userA, 3), 0);

        erc1155mock.mint(userA, 1, 10);
        erc1155mock.mint(userA, 2, 20);
        erc1155mock.mint(userA, 3, 30);

        ingot.fuse(10);
        assertEq(ingot.balanceOf(userA), 11);
        assertEq(ingot.totalSupply(), 11);
        assertEq(erc1155mock.balanceOf(address(ingot), 1), 11);
        assertEq(erc1155mock.balanceOf(address(ingot), 2), 22);
        assertEq(erc1155mock.balanceOf(address(ingot), 3), 33);
        assertEq(erc1155mock.balanceOf(userA, 1), 0);
        assertEq(erc1155mock.balanceOf(userA, 2), 0);
        assertEq(erc1155mock.balanceOf(userA, 3), 0);

        ingot.dissolve(11);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc1155mock.balanceOf(address(ingot), 1), 0);
        assertEq(erc1155mock.balanceOf(address(ingot), 2), 0);
        assertEq(erc1155mock.balanceOf(address(ingot), 3), 0);
        assertEq(erc1155mock.balanceOf(userA, 1), 11);
        assertEq(erc1155mock.balanceOf(userA, 2), 22);
        assertEq(erc1155mock.balanceOf(userA, 3), 33);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc1155mock.mint(userB, 4, 1);
        erc1155mock.mint(userB, 5, 2);
        erc1155mock.mint(userB, 6, 3);
        erc1155mock.setApprovalForAll(address(ingot), true);
        vm.expectRevert();
        ingot.fuse(1);
        vm.expectRevert();
        ingot.dissolve(1);

        erc1155mock.mint(userB, 1, 1);
        erc1155mock.mint(userB, 2, 2);
        erc1155mock.mint(userB, 3, 2);
        vm.expectRevert();
        ingot.fuse(1);

        erc1155mock.mint(userB, 3, 1);
        vm.expectRevert();
        ingot.fuse(2);
    }
}
