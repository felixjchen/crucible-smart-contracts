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

    ERC20Mock private erc20mockA;
    ERC20Mock private erc20mockB;
    ERC721Mock private erc721mockA;
    ERC721Mock private erc721mockB;
    ERC1155Mock private erc1155mockA;
    ERC1155Mock private erc1155mockB;

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

        erc20mockA = new ERC20Mock("BRINE", "BRINE");
        erc721mockA = new ERC721Mock("MoredCrepePopeClub", "MoredCrepePopeClub");
        erc1155mockA = new ERC1155Mock("PurpleBeta", "PurpleBeta");

        erc20mockB = new ERC20Mock("USBC", "USBC");
        erc721mockB = new ERC721Mock("BABUKI", "BABUKI");
        erc1155mockB = new ERC1155Mock("PurpleFall", "PurpleFall");

        emptyFloorIds = new uint256[][](0);
    }
}
