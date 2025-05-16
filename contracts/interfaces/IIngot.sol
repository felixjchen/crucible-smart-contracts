// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { IngotSpec } from "../types/IngotSpec.sol";
import { ICrucible } from "./ICrucible.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IIngot is IERC20 {
    function ingotId() external view returns (uint256);

    function initialize(ICrucible _crucible, uint256 _ingotId, IngotSpec calldata _ingotSpec) external;

    function crucibleMint(address to, uint256 amount) external;

    function crucibleBurn(address from, uint256 amount) external;

    function fuse(uint256 amount, uint256[][] calldata floorIds) external payable;

    function dissolve(uint256 amount, uint256[][] calldata floorIds) external payable;
}
