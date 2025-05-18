// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import { IFeeCalculator } from "./IFeeCalculator.sol";
import { IngotSpec } from "../types/IngotSpec.sol";

interface ICrucible {
    function feeCalculator() external view returns (IFeeCalculator);

    function feeRecipient() external view returns (address);

    function sendIngot(
        uint32 _dstEid,
        bytes calldata _options,
        address _destination,
        uint256 _ingotId,
        uint256 amount
    ) external payable;

    // TODO Fill out LZ methods
}
