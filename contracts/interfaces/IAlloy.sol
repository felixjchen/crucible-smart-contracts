// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { AlloySpec } from "../types/AlloySpec.sol";
import { ICrucible } from "./ICrucible.sol";

interface IAlloy {
    function initialize(ICrucible _crucible, uint256 _alloyId, AlloySpec calldata _alloySpec) external;

    function crucibleMint(address to, uint256 amount) external;

    function crucibleBurn(address from, uint256 amount) external;
}
