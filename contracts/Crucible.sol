// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IFeeCalculator } from "./interfaces/IFeeCalculator.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { Ingot } from "./Ingot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
import { NuggetSpec, NuggetSpecLib } from "./types/NuggetSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";

contract Crucible is ICrucible, OApp {
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for address;
    using IngotSpecLib for IngotSpec;
    using NuggetSpecLib for NuggetSpec;

    IIngot private immutable ingotImplementation;

    mapping(uint256 => address) ingotRegistry;

    IFeeCalculator public feeCalculator;
    address public feeRecipient;

    constructor(
        address _lzEndpoint,
        address _delegate,
        IFeeCalculator _feeCalculator,
        address _feeRecipient
    ) OApp(_lzEndpoint, _delegate) Ownable(_delegate) {
        ingotImplementation = new Ingot();

        feeCalculator = _feeCalculator;
        feeRecipient = _feeRecipient;
    }

    function _createIngot(uint256 _ingotId, IngotSpec memory _ingotSpec) internal returns (address) {
        require(ingotRegistry[_ingotId] == address(0), "Ingot already exists");
        address clone = Clones.clone(address(ingotImplementation));
        IIngot(clone).initialize(ICrucible(address(this)), _ingotId, _ingotSpec);
        ingotRegistry[_ingotId] = clone;
        return clone;
    }

    function createIngot(IngotSpec calldata _ingotSpec) public returns (address) {
        _ingotSpec.validate();
        uint256 _ingotId = _ingotSpec.getId();
        return _createIngot(_ingotId, _ingotSpec);
    }

    function _takeFee(uint256 amount) internal returns (uint256) {
        uint256 _fee = feeCalculator.bridge(msg.sender, amount);
        uint256 _lzFee = msg.value - _fee;
        (bool ok, ) = feeRecipient.call{ value: _fee }("");
        require(ok, "feeRecipient transfer failed");
        return _lzFee;
    }

    function sendIngot(
        uint32 _dstEid,
        bytes calldata _options,
        IngotSpec calldata _ingotSpec,
        uint256 amount
    ) external payable {
        uint256 _ingotId = _ingotSpec.getId();
        address _ingot = ingotRegistry[_ingotId];
        require(_ingot != address(0), "Ingot does not exist");
        IIngot(_ingot).crucibleBurn(msg.sender, amount);

        bytes memory _message = abi.encode(_ingotSpec, msg.sender.addressToBytes32(), amount);

        uint256 _lzFee = _takeFee(amount);

        endpoint.send{ value: _lzFee }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, false),
            payable(msg.sender)
        );
    }

    function receiveIngot(IngotSpec memory _ingotSpec, address _user, uint256 amount) internal {
        uint256 _ingotId = _ingotSpec.getId();
        address _ingot = ingotRegistry[_ingotId];
        if (_ingot == address(0)) {
            _ingot = _createIngot(_ingotId, _ingotSpec);
        }
        IIngot(_ingot).crucibleMint(_user, amount);
    }

    function _lzReceive(Origin calldata, bytes32, bytes calldata _payload, address, bytes calldata) internal override {
        (IngotSpec memory _ingotSpec, bytes32 _bUser, uint256 _amount) = abi.decode(
            _payload,
            (IngotSpec, bytes32, uint256)
        );
        receiveIngot(_ingotSpec, _bUser.bytes32ToAddress(), _amount);
    }

    // Admin
    function setFeeCalculator(IFeeCalculator _feeCalculator) external onlyOwner {
        require(address(_feeCalculator) != address(0), "Invalid fee calculator");
        feeCalculator = _feeCalculator;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }
}
