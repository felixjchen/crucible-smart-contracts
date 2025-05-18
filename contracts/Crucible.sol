// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IFeeCalculator } from "./interfaces/IFeeCalculator.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { Ingot } from "./Ingot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";

contract Crucible is ICrucible, OApp, ReentrancyGuard {
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for address;
    using IngotSpecLib for IngotSpec;

    event Invented(uint256 indexed ingotId, IngotSpec ingotSpec);
    event Transmuted(uint256 indexed ingotId, address indexed user, uint256 amount, uint32 dstEid, uint256 fee);
    event Fused(uint256 indexed ingotId, address indexed user, uint256 amount, uint256[][] floorIds, uint256 fee);
    event Dissolved(uint256 indexed ingotId, address indexed user, uint256 amount, uint256[][] floorIds, uint256 fee);

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

    function invent(IngotSpec calldata _ingotSpec) public returns (address) {
        return _createIngot(_ingotSpec);
    }

    function forge(uint256 _ingotId, uint256 _amount, uint256[][] calldata floorIds) external payable nonReentrant {
        address _ingot = ingotRegistry[_ingotId];
        require(_ingot != address(0), "Ingot not registered");

        uint256 fee = _takeWrapFee(_amount);

        IIngot(_ingot).wrap{ value: msg.value - fee }(msg.sender, _amount, floorIds);

        emit Fused(_ingotId, msg.sender, _amount, floorIds, fee);
    }

    function dissolve(uint256 _ingotId, uint256 _amount, uint256[][] calldata floorIds) external payable nonReentrant {
        address _ingot = ingotRegistry[_ingotId];
        require(_ingot != address(0), "Ingot not registered");

        uint256 fee = _takeUnwrapFee(_amount);

        IIngot(_ingot).unwrap(msg.sender, _amount, floorIds);

        emit Dissolved(_ingotId, msg.sender, _amount, floorIds, fee);
    }

    function transmute(
        uint32 _dstEid,
        bytes calldata _options,
        address _user,
        uint256 _ingotId,
        uint256 _amount
    ) public payable {
        address _ingot = ingotRegistry[_ingotId];
        require(_ingot != address(0), "Ingot not registered");

        uint256 fee = _takeBridgeFee(_amount);
        uint256 _lzFee = msg.value - fee;

        IIngot(_ingot).burn(msg.sender, _amount);
        endpoint.send{ value: _lzFee }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), abi.encode(_ingotId, _user, _amount), _options, false),
            payable(msg.sender)
        );

        emit Transmuted(_ingotId, msg.sender, _amount, _dstEid, fee);
    }

    function transmuteWithInvent(
        uint32 _dstEid,
        bytes calldata _options,
        address _user,
        IngotSpec calldata _ingotSpec,
        uint256 _amount
    ) public payable {
        uint256 _ingotId = _ingotSpec.getId();
        address _ingot = ingotRegistry[_ingotId];
        require(_ingot != address(0), "Ingot does not exist");

        uint256 fee = _takeBridgeFee(_amount);
        uint256 _lzFee = msg.value - fee;

        IIngot(_ingot).burn(msg.sender, _amount);
        endpoint.send{ value: _lzFee }(
            MessagingParams(
                _dstEid,
                _getPeerOrRevert(_dstEid),
                abi.encode(_ingotSpec, _user, _amount),
                _options,
                false
            ),
            payable(msg.sender)
        );

        emit Transmuted(_ingotId, msg.sender, _amount, _dstEid, fee);
    }

    function _lzReceive(Origin calldata, bytes32, bytes calldata _payload, address, bytes calldata) internal override {
        bytes32 _bUser;
        uint256 _amount;

        address _ingot;
        if (_payload.length == 3 * 32) {
            uint256 _ingotId;
            (_ingotId, _bUser, _amount) = abi.decode(_payload, (uint256, bytes32, uint256));
            _ingot = ingotRegistry[_ingotId];
        } else {
            IngotSpec memory _spec;
            (_spec, _bUser, _amount) = abi.decode(_payload, (IngotSpec, bytes32, uint256));
            _ingot = _createIngot(_spec);
        }
        IIngot(_ingot).mint(_bUser.bytes32ToAddress(), _amount);
    }

    // Internal
    function _createIngot(IngotSpec memory _ingotSpec) internal returns (address) {
        // (1) _ingotSpec.validate() and (2) _ingotSpec.getId() == _ingotId are true for Ingot.initialize()
        _ingotSpec.validate();
        uint256 _ingotId = _ingotSpec.getId();

        require(ingotRegistry[_ingotId] == address(0), "Ingot already exists");
        address clone = Clones.clone(address(ingotImplementation));
        IIngot(clone).initialize(ICrucible(address(this)), _ingotId, _ingotSpec);
        ingotRegistry[_ingotId] = clone;

        emit Invented(_ingotId, _ingotSpec);
        return clone;
    }

    function _takeWrapFee(uint256 _amount) internal returns (uint256) {
        uint256 _fee = feeCalculator.wrap(msg.sender, _amount);
        require(payable(feeRecipient).send(_fee), "feeRecipient transfer failed");
        return _fee;
    }

    function _takeUnwrapFee(uint256 _amount) internal returns (uint256) {
        uint256 _fee = feeCalculator.unwrap(msg.sender, _amount);
        require(payable(feeRecipient).send(_fee), "feeRecipient transfer failed");
        return _fee;
    }

    function _takeBridgeFee(uint256 _amount) internal returns (uint256) {
        uint256 _fee = feeCalculator.bridge(msg.sender, _amount);
        require(payable(feeRecipient).send(_fee), "feeRecipient transfer failed");
        return _fee;
    }

    // Views
    function quoteTransmute(
        uint32 _dstEid,
        bytes calldata _options,
        address _user,
        uint256 _ingotId,
        uint256 _amount
    ) public view returns (MessagingFee memory) {
        return
            endpoint.quote(
                MessagingParams(
                    _dstEid,
                    _getPeerOrRevert(_dstEid),
                    abi.encode(_ingotId, _user.addressToBytes32(), _amount),
                    _options,
                    false
                ),
                payable(msg.sender)
            );
    }

    function quoteTransmuteWithInvent(
        uint32 _dstEid,
        bytes calldata _options,
        address _user,
        IngotSpec calldata _ingotSpec,
        uint256 _amount
    ) public view returns (MessagingFee memory) {
        return
            endpoint.quote(
                MessagingParams(
                    _dstEid,
                    _getPeerOrRevert(_dstEid),
                    abi.encode(_ingotSpec, _user.addressToBytes32(), _amount),
                    _options,
                    false
                ),
                payable(msg.sender)
            );
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
