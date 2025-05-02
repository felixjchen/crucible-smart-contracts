// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IAlloy } from "./interfaces/IAlloy.sol";
import { Alloy } from "./Alloy.sol";
import { AlloySpec, AlloySpecLib } from "./types/AlloySpec.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { Ingot } from "./Ingot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";
import { CrucibleAction } from "./types/CrucibleAction.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";

contract Crucible is ICrucible, OApp {
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for address;
    using AlloySpecLib for AlloySpec;
    using IngotSpecLib for IngotSpec;

    IAlloy private immutable alloyImplementation;
    IIngot private immutable ingotImplementation;

    mapping(uint256 => address) alloyRegistry;
    mapping(uint256 => address) ingotRegistry;

    uint256 public fee; // in native token
    address public feeRecipient;

    constructor(
        address _lzEndpoint,
        address _delegate,
        uint256 _fee,
        address _feeRecipient
    ) OApp(_lzEndpoint, _delegate) Ownable(_delegate) {
        alloyImplementation = new Alloy();
        ingotImplementation = new Ingot();

        fee = _fee;
        feeRecipient = _feeRecipient;
    }

    function _createAlloy(uint256 _alloyId, AlloySpec memory _alloySpec) internal returns (address) {
        require(alloyRegistry[_alloyId] == address(0), "Alloy already exists");
        address clone = Clones.clone(address(alloyImplementation));
        IAlloy(clone).initialize(ICrucible(address(this)), _alloyId, _alloySpec);
        alloyRegistry[_alloyId] = clone;
        return clone;
    }

    function _createIngot(uint256 _ingotId, IngotSpec memory _ingotSpec) internal returns (address) {
        require(ingotRegistry[_ingotId] == address(0), "Ingot already exists");
        address clone = Clones.clone(address(ingotImplementation));
        IIngot(clone).initialize(ICrucible(address(this)), _ingotId, _ingotSpec);
        ingotRegistry[_ingotId] = clone;
        return clone;
    }

    function createAlloy(AlloySpec calldata _alloySpec) public returns (address) {
        _alloySpec.validate();
        uint256 _alloyId = _alloySpec.getId();
        return _createAlloy(_alloyId, _alloySpec);
    }

    function createIngot(IngotSpec calldata _ingotSpec) public returns (address) {
        _ingotSpec.validate();
        uint256 _ingotId = _ingotSpec.getId();
        return _createIngot(_ingotId, _ingotSpec);
    }

    function _takeFee() internal returns (uint256) {
        uint256 lzFee = msg.value - fee;
        (bool ok, ) = feeRecipient.call{ value: fee }("");
        require(ok, "feeRecipient transfer failed");
        return lzFee;
    }

    function sendAlloy(
        uint32 _dstEid,
        bytes calldata _options,
        AlloySpec calldata _alloySpec,
        uint256 amount
    ) external payable {
        uint256 _alloyId = _alloySpec.getId();
        address _alloy = alloyRegistry[_alloyId];
        require(_alloy != address(0), "Alloy does not exist");
        IAlloy(_alloy).crucibleBurn(msg.sender, amount);

        bytes memory _message = abi.encode(
            CrucibleAction.ALLOYBRIDGE,
            _alloySpec,
            msg.sender.addressToBytes32(),
            amount
        );

        uint256 lzFee = _takeFee();
        endpoint.send{ value: lzFee }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, false),
            payable(msg.sender)
        );
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

        bytes memory _message = abi.encode(
            CrucibleAction.INGOTBRIDGE,
            _ingotSpec,
            msg.sender.addressToBytes32(),
            amount
        );

        uint256 lzFee = _takeFee();
        endpoint.send{ value: lzFee }(
            MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, false),
            payable(msg.sender)
        );
    }

    function receiveAlloy(AlloySpec memory _alloySpec, address _user, uint256 amount) internal {
        uint256 _alloyId = _alloySpec.getId();
        address _alloy = alloyRegistry[_alloyId];
        if (_alloy == address(0)) {
            _alloy = _createAlloy(_alloyId, _alloySpec);
        }
        IAlloy(_alloy).crucibleMint(_user, amount);
    }

    function receiveIngot(IngotSpec memory _ingotSpec, address _user, uint256 amount) internal {
        uint256 _ingotId = _ingotSpec.getId();
        address _ingot = ingotRegistry[_ingotId];
        if (_ingot == address(0)) {
            _ingot = _createIngot(_ingotId, _ingotSpec);
        }
        IAlloy(_ingot).crucibleMint(_user, amount);
    }

    function _lzReceive(Origin calldata, bytes32, bytes calldata _payload, address, bytes calldata) internal override {
        CrucibleAction _crucibleAction = CrucibleAction(uint256(bytes32(_payload[:32])));
        bytes calldata _remainingPayload = _payload[32:];

        if (_crucibleAction == CrucibleAction.ALLOYBRIDGE) {
            (AlloySpec memory _alloySpec, bytes32 _bUser, uint256 _amount) = abi.decode(
                _remainingPayload,
                (AlloySpec, bytes32, uint256)
            );
            receiveAlloy(_alloySpec, _bUser.bytes32ToAddress(), _amount);
        } else if (_crucibleAction == CrucibleAction.INGOTBRIDGE) {
            (IngotSpec memory _ingotSpec, bytes32 _bUser, uint256 _amount) = abi.decode(
                _remainingPayload,
                (IngotSpec, bytes32, uint256)
            );
            receiveIngot(_ingotSpec, _bUser.bytes32ToAddress(), _amount);
        } else {
            revert("Invalid action");
        }
    }

    // Admin Functions
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }
}
