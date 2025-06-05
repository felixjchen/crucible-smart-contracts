// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ICrucible } from "contracts/interfaces/ICrucible.sol";
import { Ingot } from "contracts/Ingot.sol";
import { IngotSpec, IngotSpecLib } from "contracts/types/IngotSpec.sol";
import { NuggetSpec, NuggetSpecLib } from "contracts/types/NuggetSpec.sol";
import { CollectionType } from "contracts/types/CollectionType.sol";
import { Crucible } from "contracts/Crucible.sol";
import { NativeFixedFeeCalculator } from "contracts/NativeFixedFeeCalculator.sol";

// Mock imports
import { ERC20Mock } from "contracts/mocks/ERC20Mock.sol";
import { ERC721Mock } from "contracts/mocks/ERC721Mock.sol";
import { ERC1155Mock } from "contracts/mocks/ERC1155Mock.sol";

// Forge imports
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract IngotWrapTest is TestHelperOz5 {
    using IngotSpecLib for IngotSpec;
    using NuggetSpecLib for NuggetSpec;

    address private owner = makeAddr("owner");
    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");
    uint256 private initialBalance = 100 ether;

    Crucible private crucible;
    NativeFixedFeeCalculator private feeCalculator;

    ERC20Mock private erc20mockA;
    ERC721Mock private erc721mockA;
    ERC1155Mock private erc1155mockA;
    ERC20Mock private erc20mockB;
    ERC721Mock private erc721mockB;
    ERC1155Mock private erc1155mockB;

    uint256[][] emptyFloorIds;
    uint256[] emptyArray;

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

        (erc20mockA, erc721mockA, erc1155mockA, erc20mockB, erc721mockB, erc1155mockB) = (
            new ERC20Mock{ salt: keccak256("20A") }("BRINE", "BRINE"),
            new ERC721Mock{ salt: keccak256("721A") }("MoredCrepePopeClub", "MoredCrepePopeClub"),
            new ERC1155Mock{ salt: keccak256("1155A") }("PurpleBeta", "PurpleBeta"),
            new ERC20Mock{ salt: keccak256("20B") }("USBC", "USBC"),
            new ERC721Mock{ salt: keccak256("721B") }("BABUKI", "BABUKI"),
            new ERC1155Mock{ salt: keccak256("1155B") }("PurpleFall", "PurpleFall")
        );
    }

    function test_native() public {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(0),
            collectionType: CollectionType.NATIVE,
            decimalsOrFloorAmount: 18,
            ids: emptyArray,
            amounts: emptyArray
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        Ingot ingot = Ingot(crucible.invent(ingotSpec));

        uint256 ingotId = ingot.ingotId();

        assertEq(ingot.ingotId(), ingotId);

        assertEq(ingot.name(), "Ingot NATIVE:31337:10^18");
        assertEq(ingot.symbol(), "IO NATIVE:31337");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(0));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.NATIVE));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 18);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.deal(userA, initialBalance);
        vm.startPrank(userA);
        crucible.forge{ value: initialBalance }(ingotId, 100, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 100);
        assertEq(ingot.totalSupply(), 100);
        assertEq(address(ingot).balance, initialBalance);
        assertEq(userA.balance, 0);

        crucible.dissolve(ingotId, 100, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(address(ingot).balance, 0);
        assertEq(userA.balance, initialBalance);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        vm.deal(userB, 1 ether);
        vm.expectRevert();
        crucible.forge{ value: 1 wei }(ingotId, 1 ether, emptyFloorIds);
        vm.expectRevert();
        crucible.forge{ value: 1 ether }(ingotId, 1 ether, emptyFloorIds);
        // 18 decimals will succeed
        crucible.forge{ value: 1 ether }(ingotId, 1, emptyFloorIds);
        vm.stopPrank();
    }

    function test_erc20() public {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc20mockA),
            collectionType: CollectionType.ERC20,
            decimalsOrFloorAmount: 0,
            ids: emptyArray,
            amounts: emptyArray
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        Ingot ingot = Ingot(crucible.invent(ingotSpec));
        uint256 ingotId = ingot.ingotId();

        assertEq(ingot.ingotId(), ingotId);

        assertEq(ingot.name(), "Ingot ERC20:BRINE:10^0");
        assertEq(ingot.symbol(), "IO BRINE");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc20mockA));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC20));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 0);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc20mockA.mint(userA, initialBalance);
        erc20mockA.approve(address(ingot), initialBalance);

        crucible.forge(ingotId, initialBalance, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), initialBalance);
        assertEq(ingot.totalSupply(), initialBalance);
        assertEq(erc20mockA.balanceOf(address(ingot)), initialBalance);
        assertEq(erc20mockA.balanceOf(userA), 0);

        crucible.dissolve(ingotId, initialBalance, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc20mockA.balanceOf(address(ingot)), 0);
        assertEq(erc20mockA.balanceOf(userA), initialBalance);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc20mockA.mint(userB, 1 wei);
        vm.expectRevert();
        crucible.forge(ingotId, 10 wei, emptyFloorIds);

        erc20mockA.approve(address(ingot), 10 wei);
        vm.expectRevert();
        crucible.forge(ingotId, 10 wei, emptyFloorIds);

        erc20mockA.mint(userB, 9 wei);
        vm.expectRevert();
        crucible.dissolve(ingotId, 10 wei, emptyFloorIds);
        vm.stopPrank();
    }

    function test_erc20_decimals() public {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc20mockA),
            collectionType: CollectionType.ERC20,
            decimalsOrFloorAmount: 18,
            ids: emptyArray,
            amounts: emptyArray
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        Ingot ingot = Ingot(crucible.invent(ingotSpec));
        uint256 ingotId = ingot.ingotId();

        assertEq(ingot.ingotId(), ingotId);

        assertEq(ingot.name(), "Ingot ERC20:BRINE:10^18");
        assertEq(ingot.symbol(), "IO BRINE");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc20mockA));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC20));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 18);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc20mockA.mint(userA, 1 * 10 ** 18);
        erc20mockA.approve(address(ingot), 1 * 10 ** 18);

        crucible.forge(ingotId, 1, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 1);
        assertEq(ingot.totalSupply(), 1);
        assertEq(erc20mockA.balanceOf(address(ingot)), 1 * 10 ** 18);
        assertEq(erc20mockA.balanceOf(userA), 0);

        crucible.dissolve(ingotId, 1, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc20mockA.balanceOf(address(ingot)), 0);
        assertEq(erc20mockA.balanceOf(userA), 1 * 10 ** 18);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc20mockA.mint(userB, 1 wei);
        vm.expectRevert();
        crucible.forge(ingotId, 10 wei, emptyFloorIds);

        erc20mockA.approve(address(ingot), 10 wei);
        vm.expectRevert();
        crucible.forge(ingotId, 10 wei, emptyFloorIds);

        erc20mockA.mint(userB, 9 wei);
        vm.expectRevert();
        crucible.dissolve(ingotId, 10 wei, emptyFloorIds);
        vm.stopPrank();
    }

    function test_erc721floor() public {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc721mockA),
            collectionType: CollectionType.ERC721FLOOR,
            decimalsOrFloorAmount: 1,
            ids: emptyArray,
            amounts: emptyArray
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        Ingot ingot = Ingot(crucible.invent(ingotSpec));
        uint256 ingotId = ingot.ingotId();

        assertEq(ingot.ingotId(), ingotId);

        assertEq(ingot.name(), "Ingot ERC721:MoredCrepePopeClub:1xFLOOR");
        assertEq(ingot.symbol(), "IO MoredCrepePopeClub:1xFLOOR");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc721mockA));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC721FLOOR));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 1);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc721mockA.mint(userA, 1);
        erc721mockA.mint(userA, 2);
        erc721mockA.mint(userA, 3);
        erc721mockA.setApprovalForAll(address(ingot), true);
        uint256[][] memory floorIds = new uint256[][](1);
        floorIds[0] = new uint256[](3);
        floorIds[0][0] = 1;
        floorIds[0][1] = 2;
        floorIds[0][2] = 3;
        crucible.forge(ingotId, 3, floorIds);
        assertEq(ingot.balanceOf(userA), 3);
        assertEq(ingot.totalSupply(), 3);
        assertEq(erc721mockA.ownerOf(1), address(ingot));
        assertEq(erc721mockA.ownerOf(2), address(ingot));
        assertEq(erc721mockA.ownerOf(3), address(ingot));
        assertEq(erc721mockA.balanceOf(address(ingot)), 3);
        assertEq(erc721mockA.balanceOf(userA), 0);

        crucible.dissolve(ingotId, 3, floorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc721mockA.ownerOf(1), address(userA));
        assertEq(erc721mockA.ownerOf(2), address(userA));
        assertEq(erc721mockA.ownerOf(3), address(userA));
        assertEq(erc721mockA.balanceOf(userA), 3);
        assertEq(erc721mockA.balanceOf(address(ingot)), 0);

        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc721mockA.mint(userB, 4);
        erc721mockA.mint(userB, 5);
        erc721mockA.mint(userB, 6);
        erc721mockA.setApprovalForAll(address(ingot), true);
        uint256[][] memory floorIdsB = new uint256[][](1);
        floorIdsB[0] = new uint256[](3);
        floorIdsB[0][0] = 4;
        floorIdsB[0][1] = 5;
        floorIdsB[0][2] = 7;

        vm.expectRevert();
        crucible.forge(ingotId, 3, floorIdsB);

        floorIdsB[0][2] = 6;
        crucible.forge(ingotId, 3, floorIdsB);

        floorIdsB[0][2] = 7;
        vm.expectRevert();
        crucible.dissolve(ingotId, 3, floorIdsB); // [4, 5, 7] is not owned by contract

        uint256[][] memory floorIdsBGreedy = new uint256[][](1);
        floorIdsBGreedy[0] = new uint256[](4);
        floorIdsBGreedy[0][0] = 4;
        floorIdsBGreedy[0][1] = 5;
        floorIdsBGreedy[0][2] = 6;
        floorIdsBGreedy[0][3] = 7;

        vm.expectRevert();
        crucible.dissolve(ingotId, 3, floorIdsBGreedy); // [4, 5, 6] is owned by contract
    }

    function test_erc721floor_flooramounts() public {
        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc721mockA),
            collectionType: CollectionType.ERC721FLOOR,
            decimalsOrFloorAmount: 3,
            ids: emptyArray,
            amounts: emptyArray
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        Ingot ingot = Ingot(crucible.invent(ingotSpec));
        uint256 ingotId = ingot.ingotId();

        assertEq(ingot.ingotId(), ingotId);

        assertEq(ingot.name(), "Ingot ERC721:MoredCrepePopeClub:3xFLOOR");
        assertEq(ingot.symbol(), "IO MoredCrepePopeClub:3xFLOOR");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc721mockA));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC721FLOOR));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 3);
        assertEq(ingot.spec().nuggetSpecs[0].ids.length, 0);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc721mockA.mint(userA, 1);
        erc721mockA.mint(userA, 2);
        erc721mockA.mint(userA, 3);
        erc721mockA.mint(userA, 4);
        erc721mockA.mint(userA, 5);
        erc721mockA.mint(userA, 6);
        erc721mockA.setApprovalForAll(address(ingot), true);
        uint256[][] memory floorIds = new uint256[][](1);
        floorIds[0] = new uint256[](6);
        floorIds[0][0] = 1;
        floorIds[0][1] = 2;
        floorIds[0][2] = 3;
        floorIds[0][3] = 4;
        floorIds[0][4] = 5;
        floorIds[0][5] = 6;
        crucible.forge(ingotId, 2, floorIds);
        assertEq(ingot.balanceOf(userA), 2);
        assertEq(ingot.totalSupply(), 2);
        assertEq(erc721mockA.ownerOf(1), address(ingot));
        assertEq(erc721mockA.ownerOf(2), address(ingot));
        assertEq(erc721mockA.ownerOf(3), address(ingot));
        assertEq(erc721mockA.ownerOf(4), address(ingot));
        assertEq(erc721mockA.ownerOf(5), address(ingot));
        assertEq(erc721mockA.ownerOf(6), address(ingot));
        assertEq(erc721mockA.balanceOf(address(ingot)), 6);
        assertEq(erc721mockA.balanceOf(userA), 0);

        crucible.dissolve(ingotId, 2, floorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc721mockA.ownerOf(1), address(userA));
        assertEq(erc721mockA.ownerOf(2), address(userA));
        assertEq(erc721mockA.ownerOf(3), address(userA));
        assertEq(erc721mockA.ownerOf(4), address(userA));
        assertEq(erc721mockA.ownerOf(5), address(userA));
        assertEq(erc721mockA.ownerOf(6), address(userA));
        assertEq(erc721mockA.balanceOf(userA), 6);
        assertEq(erc721mockA.balanceOf(address(ingot)), 0);

        vm.stopPrank();
    }

    function test_erc721() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        NuggetSpec memory nuggetSpec = NuggetSpec({
            collection: address(erc721mockA),
            collectionType: CollectionType.ERC721,
            decimalsOrFloorAmount: 0,
            ids: ids,
            amounts: emptyArray
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        Ingot ingot = Ingot(crucible.invent(ingotSpec));
        uint256 ingotId = ingot.ingotId();

        assertEq(ingot.ingotId(), ingotId);

        assertEq(ingot.name(), "Ingot ERC721:MoredCrepePopeClub:1,2,3");
        assertEq(ingot.symbol(), "IO MoredCrepePopeClub:1,2,3");

        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc721mockA));
        assertEq(abi.encode(ingot.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC721));
        assertEq(ingot.spec().nuggetSpecs[0].decimalsOrFloorAmount, 0);
        assertEq(ingot.spec().nuggetSpecs[0].ids[0], 1);
        assertEq(ingot.spec().nuggetSpecs[0].ids[1], 2);
        assertEq(ingot.spec().nuggetSpecs[0].ids[2], 3);
        assertEq(ingot.spec().nuggetSpecs[0].amounts.length, 0);

        // Bunch of success cases
        vm.startPrank(userA);
        erc721mockA.mint(userA, 1);
        erc721mockA.mint(userA, 2);
        erc721mockA.mint(userA, 3);
        erc721mockA.setApprovalForAll(address(ingot), true);

        crucible.forge(ingotId, 1, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 1);
        assertEq(ingot.totalSupply(), 1);
        assertEq(erc721mockA.ownerOf(1), address(ingot));
        assertEq(erc721mockA.ownerOf(2), address(ingot));
        assertEq(erc721mockA.ownerOf(3), address(ingot));
        assertEq(erc721mockA.balanceOf(address(ingot)), 3);
        assertEq(erc721mockA.balanceOf(userA), 0);

        crucible.dissolve(ingotId, 1, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc721mockA.ownerOf(1), address(userA));
        assertEq(erc721mockA.ownerOf(2), address(userA));
        assertEq(erc721mockA.ownerOf(3), address(userA));
        assertEq(erc721mockA.balanceOf(userA), 3);
        assertEq(erc721mockA.balanceOf(address(ingot)), 0);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userA);
        erc721mockA.setApprovalForAll(address(ingot), true);
        vm.expectRevert();
        crucible.forge(ingotId, 2, emptyFloorIds);
        vm.stopPrank();

        // Bunch of failure cases with different user
        vm.startPrank(userB);
        erc721mockA.mint(userB, 4);
        erc721mockA.mint(userB, 5);
        erc721mockA.mint(userB, 6);
        erc721mockA.setApprovalForAll(address(ingot), true);
        vm.expectRevert();
        crucible.forge(ingotId, 1, emptyFloorIds);
        vm.expectRevert();
        crucible.dissolve(ingotId, 1, emptyFloorIds);
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
            collection: address(erc1155mockA),
            collectionType: CollectionType.ERC1155,
            decimalsOrFloorAmount: 0,
            ids: ids,
            amounts: amounts
        });
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](1) });
        ingotSpec.nuggetSpecs[0] = nuggetSpec;

        Ingot ingot = Ingot(crucible.invent(ingotSpec));
        uint256 ingotId = ingot.ingotId();

        assertEq(ingot.ingotId(), ingotId);

        string memory collection_string = Strings.toHexString(uint256(uint160(nuggetSpec.collection)), 20);
        string memory name = string.concat("Ingot ERC1155:", collection_string, ":1x1,2x2,3x3");
        string memory symbol = string.concat("IO ", "ERC1155_0x8724478a:1x1,2x2,3x3");
        assertEq(ingot.name(), name);
        assertEq(ingot.symbol(), symbol);
        assertEq(ingot.spec().nuggetSpecs[0].collection, address(erc1155mockA));
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
        erc1155mockA.mint(userA, 1, 1);
        erc1155mockA.mint(userA, 2, 2);
        erc1155mockA.mint(userA, 3, 3);
        erc1155mockA.setApprovalForAll(address(ingot), true);
        crucible.forge(ingotId, 1, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 1);
        assertEq(ingot.totalSupply(), 1);
        assertEq(erc1155mockA.balanceOf(address(ingot), 1), 1);
        assertEq(erc1155mockA.balanceOf(address(ingot), 2), 2);
        assertEq(erc1155mockA.balanceOf(address(ingot), 3), 3);
        assertEq(erc1155mockA.balanceOf(userA, 1), 0);
        assertEq(erc1155mockA.balanceOf(userA, 2), 0);
        assertEq(erc1155mockA.balanceOf(userA, 3), 0);

        erc1155mockA.mint(userA, 1, 10);
        erc1155mockA.mint(userA, 2, 20);
        erc1155mockA.mint(userA, 3, 30);

        crucible.forge(ingotId, 10, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 11);
        assertEq(ingot.totalSupply(), 11);
        assertEq(erc1155mockA.balanceOf(address(ingot), 1), 11);
        assertEq(erc1155mockA.balanceOf(address(ingot), 2), 22);
        assertEq(erc1155mockA.balanceOf(address(ingot), 3), 33);
        assertEq(erc1155mockA.balanceOf(userA, 1), 0);
        assertEq(erc1155mockA.balanceOf(userA, 2), 0);
        assertEq(erc1155mockA.balanceOf(userA, 3), 0);

        crucible.dissolve(ingotId, 11, emptyFloorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(erc1155mockA.balanceOf(address(ingot), 1), 0);
        assertEq(erc1155mockA.balanceOf(address(ingot), 2), 0);
        assertEq(erc1155mockA.balanceOf(address(ingot), 3), 0);
        assertEq(erc1155mockA.balanceOf(userA, 1), 11);
        assertEq(erc1155mockA.balanceOf(userA, 2), 22);
        assertEq(erc1155mockA.balanceOf(userA, 3), 33);
        vm.stopPrank();

        // Bunch of failure cases
        vm.startPrank(userB);
        erc1155mockA.mint(userB, 4, 1);
        erc1155mockA.mint(userB, 5, 2);
        erc1155mockA.mint(userB, 6, 3);
        erc1155mockA.setApprovalForAll(address(ingot), true);
        vm.expectRevert();
        crucible.forge(ingotId, 1, emptyFloorIds);
        vm.expectRevert();
        crucible.dissolve(ingotId, 1, emptyFloorIds);

        erc1155mockA.mint(userB, 1, 1);
        erc1155mockA.mint(userB, 2, 2);
        erc1155mockA.mint(userB, 3, 2);
        vm.expectRevert();
        crucible.forge(ingotId, 1, emptyFloorIds);

        erc1155mockA.mint(userB, 3, 1);
        vm.expectRevert();
        crucible.forge(ingotId, 2, emptyFloorIds);
    }

    function test_many() public {
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](5) });
        ingotSpec.nuggetSpecs[3] = NuggetSpec({
            collection: address(0),
            collectionType: CollectionType.NATIVE,
            decimalsOrFloorAmount: 18,
            ids: emptyArray,
            amounts: emptyArray
        });
        ingotSpec.nuggetSpecs[4] = NuggetSpec({
            collection: address(erc20mockA),
            collectionType: CollectionType.ERC20,
            decimalsOrFloorAmount: 6,
            ids: emptyArray,
            amounts: emptyArray
        });
        ingotSpec.nuggetSpecs[0] = NuggetSpec({
            collection: address(erc721mockA),
            collectionType: CollectionType.ERC721FLOOR,
            decimalsOrFloorAmount: 2,
            ids: emptyArray,
            amounts: emptyArray
        });
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        ingotSpec.nuggetSpecs[2] = NuggetSpec({
            collection: address(erc721mockB),
            collectionType: CollectionType.ERC721,
            decimalsOrFloorAmount: 0,
            ids: ids,
            amounts: emptyArray
        });
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 3;
        amounts[1] = 4;
        ingotSpec.nuggetSpecs[1] = NuggetSpec({
            collection: address(erc1155mockA),
            collectionType: CollectionType.ERC1155,
            decimalsOrFloorAmount: 0,
            ids: ids,
            amounts: amounts
        });

        console.log(ingotSpec.nuggetSpecs[0].getId());
        console.log(ingotSpec.nuggetSpecs[1].getId());
        console.log(ingotSpec.nuggetSpecs[2].getId());
        console.log(ingotSpec.nuggetSpecs[3].getId());
        console.log(ingotSpec.nuggetSpecs[4].getId());

        // 1 ingot = 1 ether + 10**18 ERC20 + 2 ERC721FLOOR + ERC721:1,2 + ERC1155:1x3,2x4
        Ingot ingot = Ingot(crucible.invent(ingotSpec));
        uint256 ingotId = ingot.ingotId();

        assertEq(
            ingot.name(),
            "Ingot ERC721:MoredCrepePopeClub:2xFLOOR ERC1155:0x8724478ad648d2c08c81ea58feb7cd23f26dc3b0:1x3,2x4 ERC721:BABUKI:1,2 NATIVE:31337:10^18 ERC20:BRINE:10^6"
        );
        assertEq(
            ingot.symbol(),
            "IO MoredCrepePopeClub:2xFLOOR ERC1155_0x8724478a:1x3,2x4 BABUKI:1,2 NATIVE:31337 BRINE"
        );

        vm.startPrank(userA);
        vm.deal(userA, 1 ether);
        erc20mockA.mint(userA, 10 ** 18);
        erc20mockA.approve(address(ingot), 10 ** 18);
        erc721mockA.mint(userA, 1);
        erc721mockA.mint(userA, 2);
        erc721mockA.setApprovalForAll(address(ingot), true);
        erc721mockB.mint(userA, 1);
        erc721mockB.mint(userA, 2);
        erc721mockB.setApprovalForAll(address(ingot), true);
        erc1155mockA.mint(userA, 1, 3);
        erc1155mockA.mint(userA, 2, 4);
        erc1155mockA.setApprovalForAll(address(ingot), true);
        uint256[][] memory floorIds = new uint256[][](1);
        floorIds[0] = new uint256[](2);
        floorIds[0][0] = 1;
        floorIds[0][1] = 2;

        crucible.forge{ value: 1 ether }(ingotId, 1, floorIds);

        assertEq(ingot.balanceOf(userA), 1);
        assertEq(ingot.totalSupply(), 1);

        vm.stopPrank();
    }
}
