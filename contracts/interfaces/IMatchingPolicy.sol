// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Order, AssetType} from "../libraries/Structs.sol";

interface IMatchingPolicy {
  function canMatchMakerAsk(
    Order calldata makerAsk,
    Order calldata takerBid
  ) external view returns (bool, uint256, uint256, uint256, AssetType);

  function canMatchMakerBid(
    Order calldata makerBid,
    Order calldata takerAsk
  ) external view returns (bool, uint256, uint256, uint256, AssetType);
}
