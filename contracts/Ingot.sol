// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ICrucible } from "./interfaces/ICrucible.sol";
import { IIngot } from "./interfaces/IIngot.sol";
import { IngotSpec, IngotSpecLib } from "./types/IngotSpec.sol";
import { NuggetSpec } from "./types/NuggetSpec.sol";
import { CollectionType } from "./types/CollectionType.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

// TODO: Perhaps this contract can go eventless for easier indexing

contract Ingot is IIngot, ERC20, Initializable, ReentrancyGuard, IERC721Receiver, IERC1155Receiver {
    using SafeERC20 for IERC20;
    using IngotSpecLib for IngotSpec;

    event Fused(address indexed user, uint256 amount);
    event Dissolved(address indexed user, uint256 amount);

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

    function crucibleMint(address to, uint256 amount) external onlyCrucible {
        _mint(to, amount);
    }

    function crucibleBurn(address from, uint256 amount) external onlyCrucible {
        require(msg.sender == address(crucible), "Only crucible can burn");
        _burn(from, amount);
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

    function _take(uint256 nuggetSpecIndex, uint256 amount) private {
        NuggetSpec memory _nuggetSpec = ingotSpec.nuggetSpecs[nuggetSpecIndex];
        if (_nuggetSpec.collectionType == CollectionType.NATIVE) {
            uint256 _fee = crucible.feeCalculator().wrap(msg.sender, amount);
            require(msg.value == amount * 10 ** _nuggetSpec.decimalsOrFloorAmount + _fee, "Invalid amount");

            require(payable(crucible.feeRecipient()).send(_fee), "feeRecipient transfer failed");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC20) {
            IERC20(_nuggetSpec.collection).safeTransferFrom(
                msg.sender,
                address(this),
                amount * 10 ** _nuggetSpec.decimalsOrFloorAmount
            );
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721) {
            for (uint i = 0; i < _nuggetSpec.ids.length; ++i) {
                IERC721(_nuggetSpec.collection).safeTransferFrom(msg.sender, address(this), _nuggetSpec.ids[i]);
            }
        } else if (_nuggetSpec.collectionType == CollectionType.ERC1155) {
            uint256[] memory amounts = new uint256[](_nuggetSpec.ids.length);
            for (uint i = 0; i < _nuggetSpec.ids.length; ++i) {
                amounts[i] = _nuggetSpec.amounts[i] * amount;
            }
            IERC1155(_nuggetSpec.collection).safeBatchTransferFrom(
                msg.sender,
                address(this),
                _nuggetSpec.ids,
                amounts,
                ""
            );
        }
    }

    function _takeFloors(uint256 nuggetSpecIndex, uint256 amount, uint256[] memory floorIds) private {
        NuggetSpec memory _nuggetSpec = ingotSpec.nuggetSpecs[nuggetSpecIndex];
        if (_nuggetSpec.collectionType == CollectionType.ERC721FLOOR) {
            require(floorIds.length == amount * _nuggetSpec.decimalsOrFloorAmount, "Invalid amount");
            for (uint i = 0; i < floorIds.length; ++i) {
                IERC721(_nuggetSpec.collection).safeTransferFrom(msg.sender, address(this), floorIds[i]);
            }
        }
    }

    function _give(uint256 nuggetSpecIndex, uint256 amount) private {
        NuggetSpec memory _nuggetSpec = ingotSpec.nuggetSpecs[nuggetSpecIndex];
        if (_nuggetSpec.collectionType == CollectionType.NATIVE) {
            (bool success, ) = msg.sender.call{ value: amount * 10 ** _nuggetSpec.decimalsOrFloorAmount }("");
            require(success, "Transfer failed");
        } else if (_nuggetSpec.collectionType == CollectionType.ERC20) {
            IERC20(_nuggetSpec.collection).safeTransfer(msg.sender, amount * 10 ** _nuggetSpec.decimalsOrFloorAmount);
        } else if (_nuggetSpec.collectionType == CollectionType.ERC721) {
            for (uint i = 0; i < _nuggetSpec.ids.length; ++i) {
                IERC721(_nuggetSpec.collection).safeTransferFrom(address(this), msg.sender, _nuggetSpec.ids[i]);
            }
        } else if (_nuggetSpec.collectionType == CollectionType.ERC1155) {
            uint256[] memory amounts = new uint256[](_nuggetSpec.ids.length);
            for (uint i = 0; i < _nuggetSpec.ids.length; ++i) {
                amounts[i] = _nuggetSpec.amounts[i] * amount;
            }
            IERC1155(_nuggetSpec.collection).safeBatchTransferFrom(
                address(this),
                msg.sender,
                _nuggetSpec.ids,
                amounts,
                ""
            );
        }
    }

    function _giveFloors(uint256 nuggetSpecIndex, uint256 amount, uint256[] memory floorIds) private {
        NuggetSpec memory _nuggetSpec = ingotSpec.nuggetSpecs[nuggetSpecIndex];
        if (_nuggetSpec.collectionType == CollectionType.ERC721FLOOR) {
            require(floorIds.length == amount * _nuggetSpec.decimalsOrFloorAmount, "Invalid amount");
            for (uint i = 0; i < floorIds.length; ++i) {
                IERC721(_nuggetSpec.collection).safeTransferFrom(address(this), msg.sender, floorIds[i]);
            }
        }
    }

    // Wrap
    function fuse(uint256 amount, uint256[][] calldata floorIds) public payable nonReentrant {
        uint256 j = 0;
        for (uint256 i = 0; i < ingotSpec.nuggetSpecs.length; ++i) {
            if (ingotSpec.nuggetSpecs[i].collectionType != CollectionType.ERC721FLOOR) {
                _take(i, amount);
            } else {
                _takeFloors(i, amount, floorIds[j]);
                ++j;
            }
        }
        _mint(msg.sender, amount);

        emit Fused(msg.sender, amount);
    }

    // Unwrap
    function dissolve(uint256 amount, uint256[][] calldata floorIds) public payable nonReentrant {
        uint256 _fee = crucible.feeCalculator().unwrap(msg.sender, amount);
        require(msg.value == _fee, "Invalid fee");

        require(payable(crucible.feeRecipient()).send(_fee), "feeRecipient transfer failed");

        uint256 j = 0;
        for (uint256 i = 0; i < ingotSpec.nuggetSpecs.length; ++i) {
            if (ingotSpec.nuggetSpecs[i].collectionType != CollectionType.ERC721FLOOR) {
                _give(i, amount);
            } else {
                _giveFloors(i, amount, floorIds[j]);
                ++j;
            }
        }
        _burn(msg.sender, amount);
        emit Dissolved(msg.sender, amount);
    }

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
}
