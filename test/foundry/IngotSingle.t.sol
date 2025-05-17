// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ICrucible } from "../../../contracts/interfaces/ICrucible.sol";
import { Ingot } from "../../../contracts/Ingot.sol";
import { IngotSpec } from "../../../contracts/types/IngotSpec.sol";
import { NuggetSpec, NuggetSpecLib } from "../../../contracts/types/NuggetSpec.sol";
import { CollectionType } from "../../../contracts/types/CollectionType.sol";
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

contract IngotSingleTest is TestHelperOz5 {
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

    uint256[][] emptyFloorIds;

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

    function test_native() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(0),
            collectionType: CollectionType.NATIVE,
            decimalsOrFloorAmount: 18,
            ids: ids,
            amounts: amounts
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = nuggetSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        assertEq(ingot.name(), "Ingot NATIVE:10^18");
        assertEq(ingot.symbol(), "IO NATIVE");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(0));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.NATIVE));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 18);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.deal(userA, initialBalance);
        vm.startPrank(userA);
        ingot.fuse{ value: initialBalance }(100, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 100);
        assertEq(ingot.totalSupply(), 100);
        assertEq(address(ingot).balance, initialBalance);
        assertEq(userA.balance, 0);

        ingot.dissolve(100, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(address(ingot).balance, 0);
        assertEq(userA.balance, initialBalance);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        vm.expectRevert();
        ingot.fuse{ value: 1 wei }(1 wei, emptyFloorIds);

        vm.deal(userB, 1 ether);
        vm.expectRevert();
        ingot.fuse{ value: 1 wei }(1 ether, emptyFloorIds);
        vm.expectRevert();
        ingot.fuse{ value: 1 ether }(1 ether, emptyFloorIds);
        // 18 decimals will succeed
        ingot.fuse{ value: 1 ether }(1, emptyFloorIds);
    }

    function test_erc20() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc20mock),
            collectionType: CollectionType.ERC20,
            decimalsOrFloorAmount: 0,
            ids: ids,
            amounts: amounts
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = nuggetSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        assertEq(ingot.name(), "Ingot ERC20:BRINE:10^0");
        assertEq(ingot.symbol(), "IO BRINE");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc20mock));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC20));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 0);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc20mock.mint(userA, initialBalance);
        erc20mock.approve(address(ingot), initialBalance);

        ingot.fuse(initialBalance, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), initialBalance);
        assertEq(ingot.totalSupply(), initialBalance);
        assertEq(erc20mock.balanceOf(address(ingot)), initialBalance);
        assertEq(erc20mock.balanceOf(userA), 0);

        ingot.dissolve(initialBalance, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc20mock.balanceOf(address(ingot)), 0);
        assertEq(erc20mock.balanceOf(userA), initialBalance);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc20mock.mint(userB, 1 wei);
        vm.expectRevert();
        ingot.fuse(10 wei, emptyFloorIds);

        erc20mock.approve(address(ingot), 10 wei);
        vm.expectRevert();
        ingot.fuse(10 wei, emptyFloorIds);

        erc20mock.mint(userB, 9 wei);
        vm.expectRevert();
        ingot.dissolve(10 wei, emptyFloorIds);
        vm.stopPrank();
    }

    function test_erc20_decimals() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc20mock),
            collectionType: CollectionType.ERC20,
            decimalsOrFloorAmount: 18,
            ids: ids,
            amounts: amounts
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = nuggetSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        assertEq(ingot.name(), "Ingot ERC20:BRINE:10^18");
        assertEq(ingot.symbol(), "IO BRINE");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc20mock));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC20));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 18);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc20mock.mint(userA, 1 * 10 ** 18);
        erc20mock.approve(address(ingot), 1 * 10 ** 18);

        ingot.fuse(1, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 1);
        assertEq(ingot.totalSupply(), 1);
        assertEq(erc20mock.balanceOf(address(ingot)), 1 * 10 ** 18);
        assertEq(erc20mock.balanceOf(userA), 0);

        ingot.dissolve(1, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc20mock.balanceOf(address(ingot)), 0);
        assertEq(erc20mock.balanceOf(userA), 1 * 10 ** 18);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc20mock.mint(userB, 1 wei);
        vm.expectRevert();
        ingot.fuse(10 wei, emptyFloorIds);

        erc20mock.approve(address(ingot), 10 wei);
        vm.expectRevert();
        ingot.fuse(10 wei, emptyFloorIds);

        erc20mock.mint(userB, 9 wei);
        vm.expectRevert();
        ingot.dissolve(10 wei, emptyFloorIds);
        vm.stopPrank();
    }

    function test_erc721floor() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc721mock),
            collectionType: CollectionType.ERC721FLOOR,
            decimalsOrFloorAmount: 1,
            ids: ids,
            amounts: amounts
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = nuggetSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        assertEq(ingot.name(), "Ingot ERC721FLOOR:MoredCrepePopeClub:1");
        assertEq(ingot.symbol(), "IO MoredCrepePopeClub");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc721mock));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC721FLOOR));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 1);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc721mock.mint(userA, 1);
        erc721mock.mint(userA, 2);
        erc721mock.mint(userA, 3);
        erc721mock.setApprovalForAll(address(ingot), true);
        uint256[][] memory floorIds = new uint256[][](1);
        floorIds[0] = new uint256[](3);
        floorIds[0][0] = 1;
        floorIds[0][1] = 2;
        floorIds[0][2] = 3;
        ingot.fuse(3, floorIds);
        assertEq(ingot.balanceOf(userA), 3);
        assertEq(ingot.totalSupply(), 3);
        assertEq(erc721mock.ownerOf(1), address(ingot));
        assertEq(erc721mock.ownerOf(2), address(ingot));
        assertEq(erc721mock.ownerOf(3), address(ingot));
        assertEq(erc721mock.balanceOf(address(ingot)), 3);
        assertEq(erc721mock.balanceOf(userA), 0);

        ingot.dissolve(3, floorIds);
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
        uint256[][] memory floorIdsB = new uint256[][](1);
        floorIdsB[0] = new uint256[](3);
        floorIdsB[0][0] = 4;
        floorIdsB[0][1] = 5;
        floorIdsB[0][2] = 7;

        vm.expectRevert();
        ingot.fuse(3, floorIdsB);

        floorIdsB[0][2] = 6;
        ingot.fuse(3, floorIdsB);

        floorIdsB[0][2] = 7;
        vm.expectRevert();
        ingot.dissolve(3, floorIdsB); // [4, 5, 7] is not owned by contract

        uint256[][] memory floorIdsBGreedy = new uint256[][](1);
        floorIdsBGreedy[0] = new uint256[](4);
        floorIdsBGreedy[0][0] = 4;
        floorIdsBGreedy[0][1] = 5;
        floorIdsBGreedy[0][2] = 6;
        floorIdsBGreedy[0][3] = 7;

        vm.expectRevert();
        ingot.dissolve(3, floorIdsBGreedy); // [4, 5, 6] is owned by contract
    }

    function test_erc721floor_flooramounts() public {
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc721mock),
            collectionType: CollectionType.ERC721FLOOR,
            decimalsOrFloorAmount: 3,
            ids: ids,
            amounts: amounts
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = nuggetSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        assertEq(ingot.name(), "Ingot ERC721FLOOR:MoredCrepePopeClub:3");
        assertEq(ingot.symbol(), "IO MoredCrepePopeClub");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc721mock));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC721FLOOR));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 3);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc721mock.mint(userA, 1);
        erc721mock.mint(userA, 2);
        erc721mock.mint(userA, 3);
        erc721mock.mint(userA, 4);
        erc721mock.mint(userA, 5);
        erc721mock.mint(userA, 6);
        erc721mock.setApprovalForAll(address(ingot), true);
        uint256[][] memory floorIds = new uint256[][](1);
        floorIds[0] = new uint256[](6);
        floorIds[0][0] = 1;
        floorIds[0][1] = 2;
        floorIds[0][2] = 3;
        floorIds[0][3] = 4;
        floorIds[0][4] = 5;
        floorIds[0][5] = 6;
        ingot.fuse(2, floorIds);
        assertEq(ingot.balanceOf(userA), 2);
        assertEq(ingot.totalSupply(), 2);
        assertEq(erc721mock.ownerOf(1), address(ingot));
        assertEq(erc721mock.ownerOf(2), address(ingot));
        assertEq(erc721mock.ownerOf(3), address(ingot));
        assertEq(erc721mock.ownerOf(4), address(ingot));
        assertEq(erc721mock.ownerOf(5), address(ingot));
        assertEq(erc721mock.ownerOf(6), address(ingot));
        assertEq(erc721mock.balanceOf(address(ingot)), 6);
        assertEq(erc721mock.balanceOf(userA), 0);

        ingot.dissolve(2, floorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc721mock.ownerOf(1), address(userA));
        assertEq(erc721mock.ownerOf(2), address(userA));
        assertEq(erc721mock.ownerOf(3), address(userA));
        assertEq(erc721mock.ownerOf(4), address(userA));
        assertEq(erc721mock.ownerOf(5), address(userA));
        assertEq(erc721mock.ownerOf(6), address(userA));
        assertEq(erc721mock.balanceOf(userA), 6);
        assertEq(erc721mock.balanceOf(address(ingot)), 0);

        vm.stopPrank();
    }

    function test_erc721() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](0);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc721mock),
            collectionType: CollectionType.ERC721,
            decimalsOrFloorAmount: 0,
            ids: ids,
            amounts: amounts
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = nuggetSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        assertEq(ingot.name(), "Ingot ERC721:MoredCrepePopeClub:1,2,3");
        assertEq(ingot.symbol(), "IO MoredCrepePopeClub:1,2,3");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc721mock));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC721));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 0);
        assertEq(ingot.spec().nuggetSpecs[0].ids[0], 1);
        assertEq(ingot.spec().nuggetSpecs[0].ids[1], 2);
        assertEq(ingot.spec().nuggetSpecs[0].ids[2], 3);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc721mock.mint(userA, 1);
        erc721mock.mint(userA, 2);
        erc721mock.mint(userA, 3);
        erc721mock.setApprovalForAll(address(ingot), true);

        ingot.fuse(1, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 1);
        assertEq(ingot.totalSupply(), 1);
        assertEq(erc721mock.ownerOf(1), address(ingot));
        assertEq(erc721mock.ownerOf(2), address(ingot));
        assertEq(erc721mock.ownerOf(3), address(ingot));
        assertEq(erc721mock.balanceOf(address(ingot)), 3);
        assertEq(erc721mock.balanceOf(userA), 0);

        ingot.dissolve(1, emptyFloorIds);
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
        ingot.fuse(1, emptyFloorIds);
        vm.expectRevert();
        ingot.dissolve(1, emptyFloorIds);
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

        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc1155mock),
            collectionType: CollectionType.ERC1155,
            decimalsOrFloorAmount: 0,
            ids: ids,
            amounts: amounts
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        uint256 ingotId = nuggetSpec.getId();
        ingot.initialize(ICrucible(crucible), ingotId, ingotSpec);

        string memory collection_string = Strings.toHexString(uint256(uint160(nuggetSpec.collection)), 20);
        string memory name = string.concat("Ingot ERC1155:", collection_string, ":1x1,2x2,3x3");
        string memory symbol = string.concat("IO ", collection_string, ":1x1,2x2,3x3");
        assertEq(ingot.name(), name);
        assertEq(ingot.symbol(), symbol);
        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc1155mock));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC1155));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 0);
        assertEq(ingot.spec().nuggetSpecs[0].ids[0], 1);
        assertEq(ingot.spec().nuggetSpecs[0].ids[1], 2);
        assertEq(ingot.spec().nuggetSpecs[0].ids[2], 3);
        assertEq(ingot.spec().nuggetSpecs[0].amounts[0], 1);
        assertEq(ingot.spec().nuggetSpecs[0].amounts[1], 2);
        assertEq(ingot.spec().nuggetSpecs[0].amounts[2], 3);

        // Bunch of success cases
        vm.startPrank(userA);
        erc1155mock.mint(userA, 1, 1);
        erc1155mock.mint(userA, 2, 2);
        erc1155mock.mint(userA, 3, 3);
        erc1155mock.setApprovalForAll(address(ingot), true);
        ingot.fuse(1, emptyFloorIds);
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

        ingot.fuse(10, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 11);
        assertEq(ingot.totalSupply(), 11);
        assertEq(erc1155mock.balanceOf(address(ingot), 1), 11);
        assertEq(erc1155mock.balanceOf(address(ingot), 2), 22);
        assertEq(erc1155mock.balanceOf(address(ingot), 3), 33);
        assertEq(erc1155mock.balanceOf(userA, 1), 0);
        assertEq(erc1155mock.balanceOf(userA, 2), 0);
        assertEq(erc1155mock.balanceOf(userA, 3), 0);

        ingot.dissolve(11, emptyFloorIds);
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
        ingot.fuse(1, emptyFloorIds);
        vm.expectRevert();
        ingot.dissolve(1, emptyFloorIds);

        erc1155mock.mint(userB, 1, 1);
        erc1155mock.mint(userB, 2, 2);
        erc1155mock.mint(userB, 3, 2);
        vm.expectRevert();
        ingot.fuse(1, emptyFloorIds);

        erc1155mock.mint(userB, 3, 1);
        vm.expectRevert();
        ingot.fuse(2, emptyFloorIds);
    }
}
