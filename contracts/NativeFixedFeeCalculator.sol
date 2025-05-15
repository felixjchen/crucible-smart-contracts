// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { IFeeCalculator } from "./interfaces/IFeeCalculator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract NativeFixedFeeCalculator is IFeeCalculator, Ownable {
    uint256 wrapFeeUsd;
    uint256 unwrapFeeUsd;
    uint256 bridgeFeeUsd;

    constructor(uint256 _wrapFeeUsd, uint256 _unwrapFeeUsd, uint256 _bridgeFeeUsd) Ownable(msg.sender) {
        wrapFeeUsd = _wrapFeeUsd;
        unwrapFeeUsd = _unwrapFeeUsd;
        bridgeFeeUsd = _bridgeFeeUsd;
    }

    function wrap(address, uint256) public view returns (uint256) {
        return wrapFeeUsd;
    }

    function unwrap(address, uint256) public view returns (uint256) {
        return unwrapFeeUsd;
    }

    function bridge(address, uint256) public view returns (uint256) {
        return bridgeFeeUsd;
    }

    // Admin

    function setWrapFee(uint256 _wrapFeeUsd) external onlyOwner {
        wrapFeeUsd = _wrapFeeUsd;
    }

    function setUnwrapFee(uint256 _unwrapFeeUsd) external onlyOwner {
        unwrapFeeUsd = _unwrapFeeUsd;
    }

    function setBridgeFee(uint256 _bridgeFeeUsd) external onlyOwner {
        bridgeFeeUsd = _bridgeFeeUsd;
    }
}
