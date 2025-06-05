// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
import { NuggetSpec } from "./types/NuggetSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract Ingot is IIngot, ERC20, Initializable, IERC721Receiver, IERC1155Receiver {
    using SafeERC20 for IERC20;
    using IngotSpecLib for IngotSpec;

    ICrucible public crucible;

    uint256 public ingotId;
    IngotSpec private ingotSpec;

    string private ingotName;
    string private ingotSymbol;

    constructor() ERC20("IngotBaseImplementation", "IngotBaseImplementation") {}

    modifier onlyCrucible() {
        require(msg.sender == address(crucible), "Only crucible can call ingots");
        _;
    }

    function initialize(
        ICrucible _crucible,
        uint256 _ingotId,
        IngotSpec calldata _ingotSpec
    ) public override initializer {
        require(address(_crucible) != address(0), "Crucible cannot be zero address");
        // Note: We assume, (1) _ingotSpec.validate() and (2) _ingotSpec.getId() == _ingotId, we don't check here to save gas.

        crucible = _crucible;

        ingotId = _ingotId;
        ingotSpec = _ingotSpec;

        ingotName = _ingotSpec.getName();
        ingotSymbol = _ingotSpec.getSymbol();
    }

    function mint(address user, uint256 amount) external onlyCrucible {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external onlyCrucible {
        _burn(user, amount);
    }

    function wrap(address user, uint256 amount, uint256[][] calldata floorIds) external payable onlyCrucible {
        uint256 j = 0;
        for (uint256 i = 0; i < ingotSpec.nuggetSpecs.length; ++i) {
            if (ingotSpec.nuggetSpecs[i].collectionType != CollectionType.ERC721FLOOR) {
                _take(user, i, amount);
            } else {
                _takeFloors(user, i, amount, floorIds[j]);
                ++j;
            }
        }
        _mint(user, amount);
    }

    function unwrap(address user, uint256 amount, uint256[][] calldata floorIds) external onlyCrucible {
        uint256 j = 0;
        for (uint256 i = 0; i < ingotSpec.nuggetSpecs.length; ++i) {
            if (ingotSpec.nuggetSpecs[i].collectionType != CollectionType.ERC721FLOOR) {
                _give(user, i, amount);
            } else {
                _giveFloors(user, i, amount, floorIds[j]);
                ++j;
            }
        }
        _burn(user, amount);
    }

    // Internal
    function _take(address user, uint256 nuggetSpecIndex, uint256 amount) private {
        NuggetSpec memory _nuggetSpec = ingotSpec.nuggetSpecs[nuggetSpecIndex];
        if (_nuggetSpec.collectionType == CollectionType.NATIVE) {
            require(msg.value == amount * 10 ** _nuggetSpec.decimalsOrFloorAmount, "Invalid amount");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC20) {
            IERC20(_nuggetSpec.collection).safeTransferFrom(
                user,
                address(this),
                amount * 10 ** _nuggetSpec.decimalsOrFloorAmount
            );
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721) {
            require(amount == 1, "Invalid amount");
            for (uint i = 0; i < _nuggetSpec.ids.length; ++i) {
                IERC721(_nuggetSpec.collection).safeTransferFrom(user, address(this), _nuggetSpec.ids[i]);
            }
        } else if (_nuggetSpec.collectionType == CollectionType.ERC1155) {
            uint256[] memory amounts = new uint256[](_nuggetSpec.ids.length);
            for (uint i = 0; i < _nuggetSpec.ids.length; ++i) {
                amounts[i] = _nuggetSpec.amounts[i] * amount;
            }
            IERC1155(_nuggetSpec.collection).safeBatchTransferFrom(user, address(this), _nuggetSpec.ids, amounts, "");
        }
    }

    function _takeFloors(address user, uint256 nuggetSpecIndex, uint256 amount, uint256[] memory floorIds) private {
        NuggetSpec memory _nuggetSpec = ingotSpec.nuggetSpecs[nuggetSpecIndex];
        require(floorIds.length == amount * _nuggetSpec.decimalsOrFloorAmount, "Invalid amount");
        for (uint i = 0; i < floorIds.length; ++i) {
            IERC721(_nuggetSpec.collection).safeTransferFrom(user, address(this), floorIds[i]);
        }
    }

    function _give(address user, uint256 nuggetSpecIndex, uint256 amount) private {
        NuggetSpec memory _nuggetSpec = ingotSpec.nuggetSpecs[nuggetSpecIndex];
        if (_nuggetSpec.collectionType == CollectionType.NATIVE) {
            (bool success, ) = user.call{ value: amount * 10 ** _nuggetSpec.decimalsOrFloorAmount }("");
            require(success, "Transfer failed");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC20) {
            IERC20(_nuggetSpec.collection).safeTransfer(user, amount * 10 ** _nuggetSpec.decimalsOrFloorAmount);
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721) {
            require(amount == 1, "Invalid amount");
            for (uint i = 0; i < _nuggetSpec.ids.length; ++i) {
                IERC721(_nuggetSpec.collection).safeTransferFrom(address(this), user, _nuggetSpec.ids[i]);
            }
        } else if (_nuggetSpec.collectionType == CollectionType.ERC1155) {
            uint256[] memory amounts = new uint256[](_nuggetSpec.ids.length);
            for (uint i = 0; i < _nuggetSpec.ids.length; ++i) {
                amounts[i] = _nuggetSpec.amounts[i] * amount;
            }
            IERC1155(_nuggetSpec.collection).safeBatchTransferFrom(address(this), user, _nuggetSpec.ids, amounts, "");
        }
    }

    function _giveFloors(address user, uint256 nuggetSpecIndex, uint256 amount, uint256[] memory floorIds) private {
        NuggetSpec memory _nuggetSpec = ingotSpec.nuggetSpecs[nuggetSpecIndex];
        require(floorIds.length == amount * _nuggetSpec.decimalsOrFloorAmount, "Invalid amount");
        for (uint i = 0; i < floorIds.length; ++i) {
            IERC721(_nuggetSpec.collection).safeTransferFrom(address(this), user, floorIds[i]);
        }
    }

    // Views
    function onERC721Received(address, address, uint256, bytes memory) public pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(false, "Batch transfer not supported");
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IIngot).interfaceId;
    }

    function spec() public view returns (IngotSpec memory) {
        return ingotSpec;
    }

    function name() public view override returns (string memory) {
        return ingotName;
    }

    function symbol() public view override returns (string memory) {
        return ingotSymbol;
    }
}
