// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { AlloySpec } from "../types/AlloySpec.sol";
import { ICrucible } from "./ICrucible.sol";

interface IAlloy {
    function initialize(uint256 _alloyId, AlloySpec calldata _alloySpec, ICrucible _crucible) external;
}
