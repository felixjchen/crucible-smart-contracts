// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Crucible } from "../../../contracts/Crucible.sol";
import { ICrucible } from "../../../contracts/interfaces/ICrucible.sol";
import { IIngot } from "../../../contracts/interfaces/IIngot.sol";
import { NativeFixedFeeCalculator } from "../../../contracts/NativeFixedFeeCalculator.sol";
import { IngotSpec, IngotSpecLib } from "../../../contracts/types/IngotSpec.sol";
import { NuggetSpec } from "../../../contracts/types/NuggetSpec.sol";
import { CollectionType } from "../../../contracts/types/CollectionType.sol";

// Mock imports
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ERC721Mock } from "../mocks/ERC721Mock.sol";
import { ERC1155Mock } from "../mocks/ERC1155Mock.sol";

// Forge imports
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract CrucibleTest is TestHelperOz5 {
    using IngotSpecLib for IngotSpec;
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    Crucible private aCrucible;
    Crucible private bCrucible;

    uint256 private feeAmount = 11 wei;
    NativeFixedFeeCalculator private feeCalculator;

    address private owner = makeAddr("owner");
    address private feeRecipient = makeAddr("feeRecipient");
    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");
    uint256 private initialBalance = 100 ether;

    ERC20Mock private erc20mock;
    ERC721Mock private erc721mock;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        erc20mock = new ERC20Mock("BRINE", "BRINE");
        erc721mock = new ERC721Mock("MoredCrepePopeClub", "MoredCrepePopeClub");

        feeCalculator = new NativeFixedFeeCalculator(feeAmount, feeAmount, feeAmount);

        aCrucible = Crucible(
            _deployOApp(
                type(Crucible).creationCode,
                abi.encode(address(endpoints[aEid]), owner, feeCalculator, feeRecipient)
            )
        );
        bCrucible = Crucible(
            _deployOApp(
                type(Crucible).creationCode,
                abi.encode(address(endpoints[bEid]), owner, feeCalculator, feeRecipient)
            )
        );
        // config and wire the ofts
        vm.startPrank(owner);
        aCrucible.setPeer(bEid, addressToBytes32(address(bCrucible)));
        bCrucible.setPeer(aEid, addressToBytes32(address(aCrucible)));
        vm.stopPrank();
    }

    function getIngotSpec() public view returns (IngotSpec memory) {
        IngotSpec memory ingotSpec = IngotSpec({ nuggetSpecs: new NuggetSpec[](2) });
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        NuggetSpec memory nuggetSpecA = NuggetSpec({
            collection: address(0),
            collectionType: CollectionType.NATIVE,
            decimals: 0,
            ids: ids,
            amounts: amounts
        });
        NuggetSpec memory nuggetSpecB = NuggetSpec({
            collection: address(erc721mock),
            collectionType: CollectionType.ERC721FLOOR,
            decimals: 0,
            ids: ids,
            amounts: amounts
        });
        ingotSpec.nuggetSpecs[0] = nuggetSpecB;
        ingotSpec.nuggetSpecs[1] = nuggetSpecA;

        return ingotSpec;
    }

    function test_constructor() public view {
        assertEq(aCrucible.owner(), owner);
        assertEq(address(aCrucible.feeCalculator()), address(feeCalculator));
        assertEq(aCrucible.feeRecipient(), feeRecipient);
    }

    function test_createIngot() public {
        IngotSpec memory ingotSpec = getIngotSpec();
        assertEq(aCrucible.ingotRegistry(ingotSpec.getId()), address(0), "Ingot should not exist before creation");
        IIngot ingot = IIngot(aCrucible.createIngot(ingotSpec));
        assertTrue(aCrucible.ingotRegistry(ingotSpec.getId()) != address(0), "Ingot should exist after creation");

        vm.expectRevert("Ingot already exists");
        aCrucible.createIngot(ingotSpec);

        vm.deal(address(userA), 3 wei + 2 * feeAmount);
        erc721mock.mint(userA, 0);
        erc721mock.mint(userA, 1);
        erc721mock.mint(userA, 2);

        vm.startPrank(userA);
        erc721mock.approve(address(ingot), 0);
        erc721mock.approve(address(ingot), 1);
        erc721mock.approve(address(ingot), 2);
        uint256[][] memory floorIds = new uint256[][](1);
        floorIds[0] = new uint256[](3);
        floorIds[0][0] = 0;
        floorIds[0][1] = 1;
        floorIds[0][2] = 2;
        ingot.fuse{ value: 3 wei + feeAmount }(3, floorIds);
        assertEq(ingot.balanceOf(userA), 3);
        assertEq(ingot.totalSupply(), 3);
        assertEq(userA.balance, feeAmount);
        assertEq(erc721mock.balanceOf(userA), 0);
        ingot.dissolve{ value: feeAmount }(3, floorIds);
        assertEq(ingot.balanceOf(userA), 0);
        assertEq(ingot.totalSupply(), 0);
        assertEq(userA.balance, 3 wei);
        assertEq(erc721mock.balanceOf(userA), 3);
        vm.stopPrank();

        // We collected 2x fees
        assertEq(feeRecipient.balance, 2 * feeAmount);
    }

    function test_sendIngotDoesNotCreate() public {
        IngotSpec memory ingotSpec = getIngotSpec();
        IIngot ingotA = IIngot(aCrucible.createIngot(ingotSpec));
        IIngot ingotB = IIngot(bCrucible.createIngot(ingotSpec));

        vm.deal(address(userA), 1 ether);
        erc721mock.mint(userA, 0);
        erc721mock.mint(userA, 1);
        erc721mock.mint(userA, 2);

        vm.startPrank(userA);
        erc721mock.approve(address(ingotA), 0);
        erc721mock.approve(address(ingotA), 1);
        erc721mock.approve(address(ingotA), 2);
        uint256[][] memory floorIds = new uint256[][](1);
        floorIds[0] = new uint256[](3);
        floorIds[0][0] = 0;
        floorIds[0][1] = 1;
        floorIds[0][2] = 2;
        ingotA.fuse{ value: 3 wei + feeAmount }(3, floorIds);

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        MessagingFee memory messagingFee = aCrucible.quoteSendIngot(bEid, options, ingotSpec, 3);

        aCrucible.sendIngot{ value: feeAmount + messagingFee.nativeFee }(bEid, options, ingotSpec, 3);
        verifyPackets(bEid, addressToBytes32(address(bCrucible)));

        vm.stopPrank();

        assertEq(ingotA.balanceOf(userA), 0);
        assertEq(ingotA.totalSupply(), 0);
        assertEq(ingotB.balanceOf(userA), 3);
        assertEq(ingotB.totalSupply(), 3);

        assertEq(feeRecipient.balance, 2 * feeAmount);
    }

    function test_sendIngotDoesCreate() public {
        IngotSpec memory ingotSpec = getIngotSpec();
        IIngot ingotA = IIngot(aCrucible.createIngot(ingotSpec));

        vm.deal(address(userA), 1 ether);
        erc721mock.mint(userA, 0);
        erc721mock.mint(userA, 1);
        erc721mock.mint(userA, 2);

        vm.startPrank(userA);
        erc721mock.approve(address(ingotA), 0);
        erc721mock.approve(address(ingotA), 1);
        erc721mock.approve(address(ingotA), 2);
        uint256[][] memory floorIds = new uint256[][](1);
        floorIds[0] = new uint256[](3);
        floorIds[0][0] = 0;
        floorIds[0][1] = 1;
        floorIds[0][2] = 2;
        ingotA.fuse{ value: 3 wei + feeAmount }(3, floorIds);

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(1_000_000, 0);
        MessagingFee memory messagingFee = aCrucible.quoteSendIngot(bEid, options, ingotSpec, 3);

        aCrucible.sendIngot{ value: feeAmount + messagingFee.nativeFee }(bEid, options, ingotSpec, 3);
        verifyPackets(bEid, addressToBytes32(address(bCrucible)));
        IIngot ingotB = IIngot(bCrucible.ingotRegistry(ingotSpec.getId()));

        vm.stopPrank();

        assertEq(ingotA.balanceOf(userA), 0);
        assertEq(ingotA.totalSupply(), 0);
        assertEq(ingotB.balanceOf(userA), 3);
        assertEq(ingotB.totalSupply(), 3);

        assertEq(feeRecipient.balance, 2 * feeAmount);
    }
}
