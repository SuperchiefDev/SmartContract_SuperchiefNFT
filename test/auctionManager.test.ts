import { deployments } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Ship, advanceBlockTo, advanceTimeAndBlock, getTime } from "../utils";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  AuctionManager,
  AuctionManager__factory,
  MockERC20,
  MockERC20__factory,
  MockERC721,
  MockERC721__factory,
} from "../types";
import { arrayify, parseUnits, solidityKeccak256, splitSignature } from "ethers/lib/utils";
import { FeeStruct } from "../types/contracts/AuctionManage.sol/AuctionManager";

chai.use(solidity);
const { expect } = chai;

let ship: Ship;
let nft: MockERC721;
let token: MockERC20;
let auctionManager: AuctionManager;

let deployer: SignerWithAddress;
let signer: SignerWithAddress;
let alice: SignerWithAddress;
let bob: SignerWithAddress;

let auctionId: string;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["mocks", "auction-manager"]);

  return {
    ship,
    accounts,
    users,
  };
});

const signToCreate = async (
  sender: string,
  collection: string,
  tokenId: number,
  amount: number,
  fees: FeeStruct[],
) => {
  let hash = solidityKeccak256(
    ["address", "address", "uint256", "uint256"],
    [sender, collection, tokenId, amount],
  );
  for (const fee of fees) {
    hash = solidityKeccak256(["bytes32", "uint16", "address"], [hash, fee.rate, fee.recipient]);
  }
  const sig = await signer.signMessage(arrayify(hash));
  const { r, s, v } = splitSignature(sig);
  return {
    r,
    s,
    v,
  };
};

describe("AuctionManager test", () => {
  before(async () => {
    const { accounts } = await setup();

    deployer = accounts.deployer;
    signer = accounts.signer;
    alice = accounts.alice;
    bob = accounts.bob;

    nft = await ship.connect(MockERC721__factory);
    token = await ship.connect(MockERC20__factory);
    const proxy = await ship.connect("AuctionManagerProxy");
    auctionManager = await ship.connect(AuctionManager__factory, proxy.address);

    await nft.mint(deployer.address, 1);
    await nft.mint(deployer.address, 2);
    await nft.approve(auctionManager.address, 1);
    await nft.approve(auctionManager.address, 2);

    // distribute tokens to do test
    await token.connect(deployer).transfer(alice.address, parseUnits("10"));
    await token.connect(deployer).transfer(bob.address, parseUnits("10"));

    // approve tokens to auction contract
    await token.connect(deployer).approve(auctionManager.address, parseUnits("100"));
    await token.connect(alice).approve(auctionManager.address, parseUnits("100"));
    await token.connect(bob).approve(auctionManager.address, parseUnits("100"));
  });

  it("start auction", async () => {
    const currentTime = await getTime();
    const sign = await signToCreate(deployer.address, nft.address, 1, 1, [
      {
        rate: 100,
        recipient: alice.address,
      },
    ]);
    await expect(
      auctionManager.createAuction(
        {
          collection: nft.address,
          tokenId: 1,
          amount: 1,
          paymentToken: token.address,
          minPrice: parseUnits("1"),
          minWinPercent: 105,
          startTime: currentTime,
          duration: 24 * 60 * 60,
          fees: [
            {
              rate: 100,
              recipient: alice.address,
            },
          ],
        },
        sign,
      ),
    ).to.emit(auctionManager, "NewAuction");

    const blockNumber = await ship.provider.getBlockNumber();
    auctionId = solidityKeccak256(
      ["address", "address", "uint256", "address", "uint256", "uint256"],
      [deployer.address, nft.address, 1, token.address, parseUnits("1"), blockNumber],
    );

    const auctionData = await auctionManager.auctions(auctionId);
    expect(auctionData.assetType).to.eq(0);
    expect(auctionData.collection).to.eq(nft.address);
    expect(auctionData.tokenId).to.eq(1);
    expect(auctionData.paymentToken).to.eq(token.address);
    expect(auctionData.minPrice).to.eq(parseUnits("1"));
    expect(auctionData.owner).eq(deployer.address);

    expect(await nft.ownerOf(1)).to.eq(auctionManager.address);
  });

  it("bids", async () => {
    await expect(auctionManager.connect(alice).bid(auctionId, parseUnits("0.5"))).to.revertedWith(
      "Auction: bid price is low than minimum price",
    );

    await expect(auctionManager.connect(alice).bid(auctionId, parseUnits("1")))
      .to.emit(token, "Transfer")
      .withArgs(alice.address, auctionManager.address, parseUnits("1"))
      .to.emit(auctionManager, "NewBid")
      .withArgs(auctionId, alice.address, parseUnits("1"));

    expect((await auctionManager.auctions(auctionId)).bidPrice).to.eq(parseUnits("1"));
    expect((await auctionManager.auctions(auctionId)).lastBidder).to.eq(alice.address);
    expect(await token.balanceOf(auctionManager.address)).to.eq(parseUnits("1"));

    await expect(auctionManager.connect(bob).bid(auctionId, parseUnits("1.01"))).to.revertedWith(
      "Auction: bid price is low than minimum win price",
    );

    await expect(auctionManager.connect(bob).bid(auctionId, parseUnits("1.5")))
      .to.emit(token, "Transfer")
      .withArgs(bob.address, auctionManager.address, parseUnits("1.5"))
      .to.emit(auctionManager, "NewBid")
      .withArgs(auctionId, bob.address, parseUnits("1.5"));

    expect((await auctionManager.auctions(auctionId)).bidPrice).to.eq(parseUnits("1.5"));
    expect((await auctionManager.auctions(auctionId)).lastBidder).to.eq(bob.address);
    expect(await token.balanceOf(auctionManager.address)).to.eq(parseUnits("1.5"));
  });

  it("finish auction", async () => {
    await expect(auctionManager.finish(auctionId)).to.revertedWith("Auction: auction not finished");

    await advanceTimeAndBlock(24 * 60 * 60 + 10);
    await expect(auctionManager.connect(alice).finish(auctionId)).to.revertedWith(
      "Auction: don't have permission to finish",
    );

    await expect(auctionManager.connect(bob).finish(auctionId))
      .to.emit(auctionManager, "AuctionFinished")
      .withArgs(auctionId, bob.address, parseUnits("1.5"));
  });

  it("cancel auction", async () => {
    await expect(auctionManager.cancel(auctionId)).to.revertedWith("Auction: auction already started");

    await advanceBlockTo(149);
    auctionId = solidityKeccak256(
      ["address", "address", "uint256", "address", "uint256", "uint256"],
      [deployer.address, nft.address, 2, token.address, parseUnits("1"), 150],
    );
    const currentTime = await getTime();
    const sign = await signToCreate(deployer.address, nft.address, 2, 1, [
      {
        rate: 100,
        recipient: alice.address,
      },
    ]);
    await expect(
      auctionManager.createAuction(
        {
          collection: nft.address,
          tokenId: 2,
          amount: 1,
          paymentToken: token.address,
          minPrice: parseUnits("1"),
          minWinPercent: 105,
          startTime: currentTime,
          duration: 24 * 60 * 60,
          fees: [
            {
              rate: 100,
              recipient: alice.address,
            },
          ],
        },
        sign,
      ),
    ).to.emit(auctionManager, "NewAuction");

    await expect(auctionManager.connect(alice).cancel(auctionId)).to.be.revertedWith("Auction: not owner");
  });
});
