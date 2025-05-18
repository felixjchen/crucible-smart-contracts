// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import { IFeeCalculator } from "./IFeeCalculator.sol";
import { IngotSpec } from "../types/IngotSpec.sol";

import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

interface ICrucible {
    function invent(IngotSpec calldata _ingotSpec) external returns (address);

    function fuse(uint256 _ingotId, uint256 _amount, uint256[][] calldata floorIds) external payable;

    function dissolve(uint256 _ingotId, uint256 _amount, uint256[][] calldata floorIds) external payable;

    function transmute(
        uint32 _dstEid,
        bytes calldata _options,
        address _user,
        uint256 _ingotId,
        uint256 amount
    ) external payable;

    function transmuteWithInvent(
        uint32 _dstEid,
        bytes calldata _options,
        address _user,
        IngotSpec calldata _ingotSpec,
        uint256 _amount
    ) external payable;

    function quoteTransmute(
        uint32 _dstEid,
        bytes calldata _options,
        address _user,
        uint256 _ingotId,
        uint256 _amount
    ) external view returns (MessagingFee memory);

    function quoteTransmuteWithInvent(
        uint32 _dstEid,
        bytes calldata _options,
        address _user,
        IngotSpec calldata _ingotSpec,
        uint256 _amount
    ) external view returns (MessagingFee memory);
}
