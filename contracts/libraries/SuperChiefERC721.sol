// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC2981, IERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ERC721URIStorage, ERC721, IERC721, IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {IExecutionDelegate} from "../interfaces/IExecutionDelegate.sol";
import {Destroyable} from "./Destroyable.sol";

import {Sig} from "../libraries/Structs.sol";

/**
 * @title SuperChief Maketplace NFT Standard
 * @dev use ERC721URIStorage standard
 */
contract SuperChiefERC721 is ERC721URIStorage, ERC2981, Destroyable {
  /// @dev collection params
  string public contractURI;

  /// @dev address public executionDelegate
  IExecutionDelegate public executionDelegate;

  /// @dev fires when contract uri changed
  event ContractURIChanged(string _contractURI);
  /**
   * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
   */
  event SuperChiefTransferSingle(
    address indexed from,
    address indexed to,
    uint256 firstTokenId,
    uint256 batchSize
  );

  /**
   * @dev sets contract params
   * @param _name name of collection
   * @param _symbol symbol of collection
   * @param _contractURI uri of contract
   * @param _executionDelegate execution delegate address
   */
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _contractURI,
    address _executionDelegate
  ) ERC721(_name, _symbol) {
    executionDelegate = IExecutionDelegate(_executionDelegate);

    contractURI = _contractURI;

    emit ContractURIChanged(_contractURI);
  }

  modifier onlyWhitelistedContract() {
    require(
      !_isContract(msg.sender) ||
        msg.sender == address(executionDelegate) ||
        !executionDelegate.blacklisted(msg.sender),
      "SuperChiefCollection: invalid executor"
    );
    _;
  }

  function _isContract(address _addr) private view returns (bool isContract) {
    uint32 size;
    assembly {
      size := extcodesize(_addr)
    }
    return (size > 0);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(ERC2981, ERC721URIStorage) returns (bool) {
    return
      interfaceId == type(IERC721).interfaceId ||
      interfaceId == type(IERC721Metadata).interfaceId ||
      interfaceId == type(IERC2981).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  /**
   * @dev Set contract url
   * @param _contractURI IPFS url for contract metadata
   * @param _sig signature of admin
   */
  function setContractURI(string memory _contractURI, Sig calldata _sig) external {
    require(
      msg.sender == owner() || executionDelegate.checkSuperAdmin(msg.sender, _sig),
      "SuperChiefCollection: Permission denied"
    );
    contractURI = _contractURI;

    emit ContractURIChanged(_contractURI);
  }

  /**
   * @dev Burns `tokenId`. See {ERC721-_burn}.
   *
   * Requirements:
   *
   * - The caller must own `tokenId` or be an approved operator.
   */
  function burn(uint256 tokenId) public virtual {
    //solhint-disable-next-line max-line-length
    require(
      _isApprovedOrOwner(_msgSender(), tokenId),
      "ERC721: caller is not token owner or approved"
    );
    _burn(tokenId);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 firstTokenId,
    uint256 batchSize
  ) internal override onlyWhitelistedContract {
    emit SuperChiefTransferSingle(from, to, firstTokenId, batchSize);
  }
}
