// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IFeeCalculator } from "./interfaces/IFeeCalculator.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { Ingot } from "./Ingot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
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

    event IngotCreated(address indexed ingot, uint256 indexed ingotId, IngotSpec ingotSpec);
    event IngotBridged(
        address indexed ingot,
        address indexed user,
        uint256 indexed ingotId,
        uint256 amount,
        uint32 dstEid
    );

    IIngot private immutable ingotImplementation;
    mapping(uint256 => address) public ingotRegistry;

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

    function _createIngot(IngotSpec memory _ingotSpec) internal returns (address) {
        // (1) _ingotSpec.validate() and (2) _ingotSpec.getId() == _ingotId are true for Ingot.initialize()
        _ingotSpec.validate();
        uint256 _ingotId = _ingotSpec.getId();

        require(ingotRegistry[_ingotId] == address(0), "Ingot already exists");
        address clone = Clones.clone(address(ingotImplementation));
        IIngot(clone).initialize(ICrucible(address(this)), _ingotId, _ingotSpec);
        ingotRegistry[_ingotId] = clone;

        emit IngotCreated(clone, _ingotId, _ingotSpec);
        return clone;
    }

    function createIngot(IngotSpec calldata _ingotSpec) public returns (address) {
        return _createIngot(_ingotSpec);
    }

    function quoteSendIngot(
        uint32 _dstEid,
        bytes calldata _options,
        address _destination,
        IngotSpec calldata _ingotSpec,
        uint256 _amount
    ) public view returns (MessagingFee memory) {
        return
            endpoint.quote(
                MessagingParams(
                    _dstEid,
                    _getPeerOrRevert(_dstEid),
                    abi.encode(_destination.addressToBytes32(), _amount, _ingotSpec),
                    _options,
                    false
                ),
                payable(msg.sender)
            );
    }

    function sendIngot(
        uint32 _dstEid,
        bytes calldata _options,
        address _destination,
        IngotSpec calldata _ingotSpec,
        uint256 _amount
    ) public payable {
        uint256 _ingotId = _ingotSpec.getId();
        address _ingot = ingotRegistry[_ingotId];
        require(_ingot != address(0), "Ingot does not exist");
        IIngot(_ingot).crucibleBurn(msg.sender, _amount);

        uint256 _fee = feeCalculator.bridge(msg.sender, _amount);
        require(msg.value >= _fee, "Insufficient fee");
        uint256 _lzFee = msg.value - _fee;

        require(payable(feeRecipient).send(_fee), "feeRecipient transfer failed");

        endpoint.send{ value: _lzFee }(
            MessagingParams(
                _dstEid,
                _getPeerOrRevert(_dstEid),
                abi.encode(_destination, _amount, _ingotSpec),
                _options,
                false
            ),
            payable(msg.sender)
        );

        emit IngotBridged(_ingot, msg.sender, _ingotId, _amount, _dstEid);
    }

    // TODO Perhaps a cheaper no create option
    function _lzReceive(Origin calldata, bytes32, bytes calldata _payload, address, bytes calldata) internal override {
        (bytes32 _bUser, uint256 _amount, IngotSpec memory _ingotSpec) = abi.decode(
            _payload,
            (bytes32, uint256, IngotSpec)
        );
        uint256 _ingotId = _ingotSpec.getId();
        address _ingot = ingotRegistry[_ingotId];
        if (_ingot == address(0)) {
            _ingot = _createIngot(_ingotSpec);
        }
        IIngot(_ingot).crucibleMint(_bUser.bytes32ToAddress(), _amount);
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
