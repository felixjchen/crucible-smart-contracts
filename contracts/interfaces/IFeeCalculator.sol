// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IFeeCalculator {
    function wrap(address user, uint256 amount) external returns (uint256);

    function unwrap(address user, uint256 amount) external returns (uint256);

    function bridge(address user, uint256 amount) external returns (uint256);
}
