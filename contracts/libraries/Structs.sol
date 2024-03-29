// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

enum Side {
  Buy,
  Sell
}

enum SignatureVersion {
  Single,
  Bulk
}

enum AssetType {
  ERC721,
  ERC1155
}

struct Fee {
  uint16 rate;
  address payable recipient;
}

struct Order {
  address trader;
  Side side;
  address matchingPolicy;
  address collection;
  uint256 tokenId;
  uint256 amount;
  address paymentToken;
  uint256 price;
  uint256 listingTime;
  /* Order expiration timestamp - 0 for oracle cancellations. */
  uint256 expirationTime;
  Fee[] fees;
  uint256 salt;
  bytes extraParams;
}

struct Input {
  Order order;
  uint8 v;
  bytes32 r;
  bytes32 s;
  bytes extraSignature;
  SignatureVersion signatureVersion;
  uint256 blockNumber;
}

struct Auction {
  AssetType assetType;
  address collection;
  uint256 tokenId;
  uint256 amount;
  address paymentToken;
  uint256 minPrice;
  uint256 minWinPercent;
  uint256 startTime;
  uint256 endTime;
  uint256 duration;
  address owner;
  address lastBidder;
  uint256 bidPrice;
  Fee[] fees;
}

struct AuctionCreateParam {
  address collection;
  uint256 tokenId;
  uint256 amount;
  address paymentToken;
  uint256 minPrice;
  uint256 minWinPercent;
  uint256 startTime;
  uint256 duration;
  Fee[] fees;
}

struct Sig {
  bytes32 r;
  bytes32 s;
  uint8 v;
}

struct EditionConfig {
  uint256 price;
  uint128 startTime;
  uint128 endTime;
  uint64 maxSupply;
  uint64 txMinLimit;
  uint64 txMaxLimit;
  uint64 walletLimit;
}
