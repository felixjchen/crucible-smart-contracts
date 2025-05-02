// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { IngotSpec } from "../types/IngotSpec.sol";
import { ICrucible } from "./ICrucible.sol";

interface IIngot {
    function initialize(ICrucible _crucible, uint256 _ingotId, IngotSpec calldata _ingotSpec) external;

    function crucibleMint(address to, uint256 amount) external;

    function crucibleBurn(address from, uint256 amount) external;
}
