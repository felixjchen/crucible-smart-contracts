// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Crucible } from "../../../contracts/Crucible.sol";
import { ICrucible } from "../../../contracts/interfaces/ICrucible.sol";

// Mock imports
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ERC721Mock } from "../mocks/ERC721Mock.sol";
import { ERC1155Mock } from "../mocks/ERC1155Mock.sol";

// Forge imports
import "forge-std/console.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract CrucibleTest is TestHelperOz5 {
    // using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;

    Crucible private aCrucible;
    Crucible private bCrucible;

    address private owner = makeAddr("owner");
    address private feeRecipient = makeAddr("feeRecipient");
    address private userA = makeAddr("userA");
    address private userB = makeAddr("userB");

    uint256 private initialBalance = 100 ether;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        vm.startPrank(owner);
        aCrucible = Crucible(
            _deployOApp(type(Crucible).creationCode, abi.encode(address(endpoints[aEid]), owner, feeRecipient))
        );

        bCrucible = Crucible(
            _deployOApp(type(Crucible).creationCode, abi.encode(address(endpoints[aEid]), owner, feeRecipient))
        );
        // config and wire the ofts
        address[] memory crucibles = new address[](2);
        crucibles[0] = address(aCrucible);
        crucibles[1] = address(bCrucible);
        this.wireOApps(crucibles);
        vm.stopPrank();

        // vm.deal(userA, 1000 ether);
        // vm.deal(userB, 1000 ether);
    }

    function test_constructor() public {}

    // function test_send_oft() public {
    //     uint256 tokensToSend = 1 ether;
    //     bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
    //     SendParam memory sendParam = SendParam(
    //         bEid,
    //         addressToBytes32(userB),
    //         tokensToSend,
    //         tokensToSend,
    //         options,
    //         "",
    //         ""
    //     );
    //     MessagingFee memory fee = aCrucible.quoteSend(sendParam, false);

    //     assertEq(aCrucible.balanceOf(userA), initialBalance);
    //     assertEq(bCrucible.balanceOf(userB), initialBalance);

    //     vm.prank(userA);
    //     aCrucible.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
    //     verifyPackets(bEid, addressToBytes32(address(bCrucible)));

    //     assertEq(aCrucible.balanceOf(userA), initialBalance - tokensToSend);
    //     assertEq(bCrucible.balanceOf(userB), initialBalance + tokensToSend);
    // }

    // function test_send_oft_compose_msg() public {
    //     uint256 tokensToSend = 1 ether;

    //     OFTComposerMock composer = new OFTComposerMock();

    //     bytes memory options = OptionsBuilder
    //         .newOptions()
    //         .addExecutorLzReceiveOption(200000, 0)
    //         .addExecutorLzComposeOption(0, 500000, 0);
    //     bytes memory composeMsg = hex"1234";
    //     SendParam memory sendParam = SendParam(
    //         bEid,
    //         addressToBytes32(address(composer)),
    //         tokensToSend,
    //         tokensToSend,
    //         options,
    //         composeMsg,
    //         ""
    //     );
    //     MessagingFee memory fee = aCrucible.quoteSend(sendParam, false);

    //     assertEq(aCrucible.balanceOf(userA), initialBalance);
    //     assertEq(bCrucible.balanceOf(address(composer)), 0);

    //     vm.prank(userA);
    //     (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = aCrucible.send{ value: fee.nativeFee }(
    //         sendParam,
    //         fee,
    //         payable(address(this))
    //     );
    //     verifyPackets(bEid, addressToBytes32(address(bCrucible)));

    //     // lzCompose params
    //     uint32 dstEid_ = bEid;
    //     address from_ = address(bCrucible);
    //     bytes memory options_ = options;
    //     bytes32 guid_ = msgReceipt.guid;
    //     address to_ = address(composer);
    //     bytes memory composerMsg_ = OFTComposeMsgCodec.encode(
    //         msgReceipt.nonce,
    //         aEid,
    //         oftReceipt.amountReceivedLD,
    //         abi.encodePacked(addressToBytes32(userA), composeMsg)
    //     );
    //     this.lzCompose(dstEid_, from_, options_, guid_, to_, composerMsg_);

    //     assertEq(aCrucible.balanceOf(userA), initialBalance - tokensToSend);
    //     assertEq(bCrucible.balanceOf(address(composer)), tokensToSend);

    //     assertEq(composer.from(), from_);
    //     assertEq(composer.guid(), guid_);
    //     assertEq(composer.message(), composerMsg_);
    //     assertEq(composer.executor(), address(this));
    //     assertEq(composer.extraData(), composerMsg_); // default to setting the extraData to the message as well to test
    // }

    // TODO import the rest of oft tests?
}
