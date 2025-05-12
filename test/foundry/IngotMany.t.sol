// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import { Alloy } from "../../../contracts/Alloy.sol";
// import { ICrucible } from "../../../contracts/interfaces/ICrucible.sol";
// import { NuggetSpec } from "../../../contracts/types/NuggetSpec.sol";
// import { AlloySpec, AlloySpecLib } from "../../../contracts/types/AlloySpec.sol";
// import { CollectionType } from "../../../contracts/types/CollectionType.sol";

// // Mock imports
// import { ERC20Mock } from "../mocks/ERC20Mock.sol";
// import { ERC721Mock } from "../mocks/ERC721Mock.sol";
// import { ERC1155Mock } from "../mocks/ERC1155Mock.sol";

// // Forge imports
// import "forge-std/console.sol";
// import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
// import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contract AlloyTest is TestHelperOz5 {
//     using AlloySpecLib for AlloySpec;

//     address private crucible = makeAddr("crucible");
//     address private userA = makeAddr("userA");
//     address private userB = makeAddr("userB");
//     address private userC = makeAddr("userC");
//     uint256 private initialBalance = 100 ether;

//     Alloy private alloy;

//     ERC20Mock private erc20mockA;
//     ERC20Mock private erc20mockB;
//     ERC721Mock private erc721mockA;
//     ERC721Mock private erc721mockB;
//     ERC1155Mock private erc1155mockA;
//     ERC1155Mock private erc1155mockB;

//     function setUp() public virtual override {
//         super.setUp();

//         alloy = new Alloy();
//         erc20mockA = new ERC20Mock("BRINE", "BRINE");
//         erc20mockB = new ERC20Mock("PETH", "PETH");
//         erc721mockA = new ERC721Mock("MoredCrepePopeClub", "MoredCrepePopeClub");
//         erc721mockB = new ERC721Mock("BZUKA", "BZUKA");
//         erc1155mockA = new ERC1155Mock("PurpleBeta", "PurpleBeta");
//         erc1155mockB = new ERC1155Mock("GagnaRock", "GagnaRock");

//         // mint tokens
//         vm.deal(userA, 1000 ether);
//         vm.deal(userB, 1000 ether);
//     }

//     function test_validateAlloySpec() public {}

//     function test_initializeOnce() public {}

//     function test_two_erc20() public {
//         NuggetSpec[] memory nuggetSpecs = new NuggetSpec[](2);
//         uint256[] memory ids = new uint256[](0);
//         uint256[] memory amounts = new uint256[](0);
//         nuggetSpecs[0] = NuggetSpec({
//             collection: address(erc20mockA),
//             collectionType: CollectionType.ERC20,
//             decimals: 1,
//             ids: ids,
//             amounts: amounts
//         });

//         nuggetSpecs[1] = NuggetSpec({
//             collection: address(erc20mockB),
//             collectionType: CollectionType.ERC20,
//             decimals: 1,
//             ids: ids,
//             amounts: amounts
//         });
//         AlloySpec memory alloySpec = AlloySpec({ nuggetSpecs: nuggetSpecs });
//         uint256 alloyId = alloySpec.getId();

//         alloy.initialize(ICrucible(crucible), alloyId, alloySpec);

//         assertEq(alloy.name(), "Alloy ERC20:BRINE ERC20:PETH");
//         assertEq(alloy.symbol(), "AO BRINE PETH");

//         assertEq(alloy.spec().nuggetSpecs[0].collection, address(erc20mockA));
//         assertEq(abi.encode(alloy.spec().nuggetSpecs[0].collectionType), abi.encode(CollectionType.ERC20));
//         assertEq(alloy.spec().nuggetSpecs[0].ids.length, 0);
//         assertEq(alloy.spec().nuggetSpecs[0].amounts.length, 0);
//         assertEq(alloy.spec().nuggetSpecs[1].collection, address(erc20mockB));
//         assertEq(abi.encode(alloy.spec().nuggetSpecs[1].collectionType), abi.encode(CollectionType.ERC20));
//         assertEq(alloy.spec().nuggetSpecs[1].ids.length, 0);
//         assertEq(alloy.spec().nuggetSpecs[1].amounts.length, 0);

//         // Bunch of success cases
//         vm.startPrank(userA);
//         erc20mockA.mint(userA, initialBalance);
//         erc20mockB.mint(userA, initialBalance);
//         erc20mockA.approve(address(alloy), initialBalance);
//         erc20mockB.approve(address(alloy), initialBalance);
//         alloy.fuse(initialBalance);
//         assertEq(alloy.balanceOf(userA), initialBalance);
//         assertEq(alloy.totalSupply(), initialBalance);
//         assertEq(erc20mockA.balanceOf(address(alloy)), initialBalance);
//         assertEq(erc20mockB.balanceOf(address(alloy)), initialBalance);
//         assertEq(erc20mockA.balanceOf(userA), 0);
//         assertEq(erc20mockB.balanceOf(userA), 0);

//         alloy.dissolve(initialBalance);
//         assertEq(alloy.balanceOf(userA), 0);
//         assertEq(alloy.totalSupply(), 0);
//         assertEq(erc20mockA.balanceOf(address(alloy)), 0);
//         assertEq(erc20mockB.balanceOf(address(alloy)), 0);
//         assertEq(erc20mockA.balanceOf(userA), initialBalance);
//         assertEq(erc20mockB.balanceOf(userA), initialBalance);
//         vm.stopPrank();

//         // Bunch of failure cases
//         vm.startPrank(userB);
//         erc20mockA.approve(address(alloy), initialBalance);
//         erc20mockB.approve(address(alloy), initialBalance);
//         vm.expectRevert();
//         alloy.fuse(initialBalance); // Not enough A or B
//         erc20mockA.mint(userB, initialBalance);
//         vm.expectRevert();
//         alloy.fuse(initialBalance); // Not enough B
//         erc20mockB.mint(userB, initialBalance);
//         alloy.fuse(initialBalance);
//         alloy.dissolve(initialBalance);
//         vm.stopPrank();

//         vm.startPrank(userC);
//         erc20mockA.mint(userC, 1 wei);
//         erc20mockB.mint(userC, 1 wei);
//         vm.expectRevert();
//         alloy.fuse(1 wei);
//         erc20mockA.approve(address(alloy), 1 wei);
//         vm.expectRevert();
//         alloy.fuse(1 wei);
//         erc20mockB.approve(address(alloy), 1 wei);
//         alloy.fuse(1 wei);
//         vm.stopPrank();
//     }

//     function test_two_erc721() public {}

//     function test_two_erc1155() public {}

//     function test_blend() public {}
// }
