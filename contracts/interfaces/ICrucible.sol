// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import { IFeeCalculator } from "./IFeeCalculator.sol";

interface ICrucible {
    function feeCalculator() external view returns (IFeeCalculator);
}
