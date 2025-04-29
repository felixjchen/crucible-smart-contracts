// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { IngotSpec } from "../types/IngotSpec.sol";
import { ICrucible } from "./ICrucible.sol";

interface IIngot {
    function initialize(uint256 _ingotId, IngotSpec calldata _ingotSpec, ICrucible _crucible) external;
}
