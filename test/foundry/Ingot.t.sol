// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ICrucible } from "../../../contracts/interfaces/ICrucible.sol";
import { IIngot } from "../../../contracts/interfaces/IIngot.sol";
import { Ingot } from "../../../contracts/Ingot.sol";
import { IngotSpec, IngotSpecLib } from "../../../contracts/types/IngotSpec.sol";
import { NuggetSpec, NuggetSpecLib } from "../../../contracts/types/NuggetSpec.sol";
import { CollectionType } from "../../../contracts/types/CollectionType.sol";

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Crucible } from "../../../contracts/Crucible.sol";
import { NativeFixedFeeCalculator } from "../../../contracts/NativeFixedFeeCalculator.sol";

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
    using NuggetSpecLib for NuggetSpec;

    address private owner = makeAddr("owner");
    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");
    uint256 private initialBalance = 100 ether;

    Ingot private ingot;
    Crucible private crucible;
    NativeFixedFeeCalculator private feeCalculator;

    ERC20Mock private erc20mock;
    ERC20Mock private erc20mockB;
    ERC721Mock private erc721mock;
    ERC1155Mock private erc1155mock;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        feeCalculator = new NativeFixedFeeCalculator(0 wei, 0 wei, 0 wei);
        crucible = Crucible(
            _deployOApp(
                type(Crucible).creationCode,
                abi.encode(address(endpoints[1]), owner, feeCalculator, address(this))
            )
        );
        ingot = new Ingot();

        erc20mock = new ERC20Mock("BRINE", "BRINE");
        erc721mock = new ERC721Mock("MoredCrepePopeClub", "MoredCrepePopeClub");
        erc1155mock = new ERC1155Mock("PurpleBeta", "PurpleBeta");
    }

    function test_initializeOnce() public {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc20mock),
            collectionType: CollectionType.ERC20,
            decimalsOrFloorAmount: 0,
            ids: new uint256[](0),
            amounts: new uint256[](0)
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = ingotSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);
        vm.expectRevert();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);
    }

    function test_supportsInterface() public view {
        assertTrue(ingot.supportsInterface(type(IERC165).interfaceId));
        assertTrue(ingot.supportsInterface(type(IERC721Receiver).interfaceId));
        assertTrue(ingot.supportsInterface(type(IERC1155Receiver).interfaceId));
        assertTrue(ingot.supportsInterface(type(IIngot).interfaceId));
    }

    function test_isERC721Receiver() public view {
        assertEq(ingot.onERC721Received(address(0), address(0), 0, ""), bytes4(0x150b7a02));
    }

    function test_isNotERC1155Reciever() public {
        vm.expectRevert();
        ingot.onERC1155Received(address(0), address(0), 0, 0, "");
    }

    function test_isERC1155BatchReciever() public view {
        assertEq(
            ingot.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), ""),
            bytes4(0xbc197c81)
        );
    }

    function test_crucibleMint() public {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc20mock),
            collectionType: CollectionType.ERC20,
            decimalsOrFloorAmount: 0,
            ids: new uint256[](0),
            amounts: new uint256[](0)
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = ingotSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        vm.startPrank(userA);
        vm.expectRevert();
        ingot.crucibleMint(userA, 1 ether);
        vm.stopPrank();

        vm.startPrank(address(crucible));
        ingot.crucibleMint(userA, 1 ether);
        assertEq(ingot.balanceOf(userA), 1 ether);
        assertEq(ingot.totalSupply(), 1 ether);
        vm.stopPrank();
    }

    function test_crucibleBurn() public {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc20mock),
            collectionType: CollectionType.ERC20,
            decimalsOrFloorAmount: 0,
            ids: new uint256[](0),
            amounts: new uint256[](0)
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = ingotSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        vm.startPrank(address(crucible));
        ingot.crucibleMint(userA, 1 ether);
        vm.stopPrank();

        vm.startPrank(userA);
        vm.expectRevert();
        ingot.crucibleBurn(userA, 1 ether);
        vm.stopPrank();

        vm.startPrank(address(crucible));
        ingot.crucibleBurn(userA, 1 ether);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        vm.stopPrank();
    }

    function test_validateNuggetSpec() public view {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(0),
            collectionType: CollectionType.NATIVE,
            decimalsOrFloorAmount: 0,
            ids: new uint256[](0),
            amounts: new uint256[](0)
        });
    }
}
