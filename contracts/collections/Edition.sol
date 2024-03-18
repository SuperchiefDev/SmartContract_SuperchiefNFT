// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC2981, IERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {ERC721ABurnable, ERC721A, IERC721A} from "erc721a/contracts/extensions/ERC721ABurnable.sol";
import {IExecutionDelegate} from "../interfaces/IExecutionDelegate.sol";
import {Destroyable} from "../libraries/Destroyable.sol";

import {Sig, EditionConfig} from "../libraries/Structs.sol";

/**
 * @title SuperChief Maketplace NFT Standard
 * @dev use ERC721ABurnable standard
 */
contract Edition is ERC721ABurnable, ERC2981, Destroyable {
  /// @dev collection params
  string public contractURI;
  string private tokenUri;

  /// @dev edition config
  EditionConfig public config;

  /// @dev address public executionDelegate
  IExecutionDelegate public executionDelegate;

  /// @dev new edition added
  event SuperChiefEditionCreated(
    address indexed edition,
    string name,
    string symbol,
    string contractURI,
    EditionConfig config,
    address feeReceiver,
    uint96 feeRate
  );
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
  event SuperChiefNftMinted(uint256 tokenId, address owner, uint256 amount, string tokenUri);

  /**
   * @dev sets contract params
   * @param _name name of collection
   * @param _symbol symbol of collection
   * @param _contractURI uri of contract
   * @param _executionDelegate execution delegate address
   * @param _config config of edition
   * @param _feeRate artist royalty rate
   * @param _receiver royalty receiver address
   */
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _contractURI,
    string memory _tokenUri,
    address _executionDelegate,
    EditionConfig memory _config,
    uint96 _feeRate,
    address _receiver
  ) ERC721A(_name, _symbol) {
    executionDelegate = IExecutionDelegate(_executionDelegate);

    contractURI = _contractURI;
    tokenUri = _tokenUri;
    config = _config;

    _setDefaultRoyalty(_receiver, _feeRate);

    emit SuperChiefEditionCreated(
      address(this),
      _name,
      _symbol,
      _contractURI,
      config,
      _receiver,
      _feeRate
    );
  }

  /**
   * @dev mint NFT
   * @param _receiver receiver to get
   * @param _count nft to count
   */
  function mint(address _receiver, uint64 _count) external payable {
    require(block.timestamp >= config.startTime, "SuperChiefEdition: mint not started yet");
    require(block.timestamp <= config.endTime, "SuperChiefEdition: mint already finished");
    require(totalSupply() < config.maxSupply, "SuperChiefEdition: mint already finished");
    require(
      totalSupply() + _count <= config.maxSupply &&
        _count >= config.txMinLimit &&
        _count <= config.txMaxLimit &&
        balanceOf(_receiver) + _count <= config.walletLimit,
      "SuperChiefEdition: invalid count"
    );
    require(msg.value == _count * config.price, "SuperChiefEdition: invalid price");

    uint256 startTokenId = totalSupply() + 1;
    _mint(_receiver, _count);

    for (uint256 i = 0; i < _count; i++) {
      emit SuperChiefNftMinted(startTokenId + i, msg.sender, 1, tokenURI(startTokenId + i));
    }
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
  ) public view virtual override(ERC2981, ERC721A, IERC721A) returns (bool) {
    return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
  }

  function tokenURI(
    uint256 tokenId
  ) public view virtual override(ERC721A, IERC721A) returns (string memory) {
    if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

    return tokenUri;
  }

  /**
   * @dev update edition config
   * @param _config new config to update
   */
  function updateConfig(EditionConfig calldata _config) external onlyOwner {
    config = _config;
  }

  /**
   * @dev update edition base uri
   * @param _uri new uri to update
   */
  function updateTokenUri(string calldata _uri) external onlyOwner {
    tokenUri = _uri;
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
   * @dev set artist royalty data
   * @param _receiver fee receiver address
   * @param _feeRate fee rate
   */
  function setRoyalty(address _receiver, uint96 _feeRate) external onlyOwner {
    _setDefaultRoyalty(_receiver, _feeRate);
  }

  /**
   * @dev Hook that is called before a set of serially-ordered token IDs
   * are about to be transferred. This includes minting.
   * And also called before burning one token.
   *
   * `startTokenId` - the first token ID to be transferred.
   * `quantity` - the amount to be transferred.
   *
   * Calling conditions:
   *
   * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
   * transferred to `to`.
   * - When `from` is zero, `tokenId` will be minted for `to`.
   * - When `to` is zero, `tokenId` will be burned by `from`.
   * - `from` and `to` are never both zero.
   */
  function _afterTokenTransfers(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal virtual override onlyWhitelistedContract {
    emit SuperChiefTransferSingle(from, to, startTokenId, quantity);
  }
}
