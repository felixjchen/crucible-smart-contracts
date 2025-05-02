// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Alloy } from "../../../contracts/Alloy.sol";
import { ICrucible } from "../../../contracts/interfaces/ICrucible.sol";
import { IngotSpec } from "../../../contracts/types/IngotSpec.sol";
import { AlloySpec, AlloySpecLib } from "../../../contracts/types/AlloySpec.sol";
import { CollectionType } from "../../../contracts/types/CollectionType.sol";

// Mock imports
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ERC721Mock } from "../mocks/ERC721Mock.sol";
import { ERC1155Mock } from "../mocks/ERC1155Mock.sol";

// Forge imports
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract AlloyBaseTest is TestHelperOz5 {
    using AlloySpecLib for AlloySpec;

    address private crucible = makeAddr("crucible");
    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");
    uint256 private initialBalance = 100 ether;

    Alloy private alloy;

    ERC20Mock private erc20mockA;
    ERC20Mock private erc20mockB;
    ERC721Mock private erc721mockA;
    ERC721Mock private erc721mockB;
    ERC1155Mock private erc1155mockA;
    ERC1155Mock private erc1155mockB;

    function setUp() public virtual override {
        super.setUp();

        alloy = new Alloy();
        erc20mockA = new ERC20Mock("BRINE", "BRINE");
        erc20mockB = new ERC20Mock("PETH", "PETH");
        erc721mockA = new ERC721Mock("MoredCrepePopeClub", "MoredCrepePopeClub");
        erc721mockB = new ERC721Mock("BZUKA", "BZUKA");
        erc1155mockA = new ERC1155Mock("PurpleBeta", "PurpleBeta");
        erc1155mockB = new ERC1155Mock("GagnaRock", "GagnaRock");

        // mint tokens
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
    }

    function test_validateAlloySpec() public {}

    function test_initializeOnce() public {}

    function test_two_erc20() public {
        IngotSpec[] memory ingotSpecs = new IngotSpec[](2);
        uint256[] memory ids = new uint256[](0);
        uint256[] memory amounts = new uint256[](0);
        ingotSpecs[0] = IngotSpec({
            collection: address(erc20mockA),
            collectionType: CollectionType.ERC20,
            ids: ids,
            amounts: amounts
        });

        ingotSpecs[1] = IngotSpec({
            collection: address(erc20mockB),
            collectionType: CollectionType.ERC20,
            ids: ids,
            amounts: amounts
        });
        AlloySpec memory alloySpec = AlloySpec({ ingotSpecs: ingotSpecs });
        uint256 alloyId = alloySpec.getId();

        alloy.initialize(ICrucible(crucible), alloyId, alloySpec);

        assertEq(alloy.name(), "Alloy ERC20:BRINE ERC20:PETH");
        assertEq(alloy.symbol(), "AO BRINE PETH");

        console.log(address(erc20mockA));
        console.log(address(erc20mockB));
    }

    function test_two_erc721() public {}

    function test_two_erc1155() public {}

    function test_blend() public {}
}
