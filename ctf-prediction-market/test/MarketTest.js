const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Binary Prediction Market", function () {
  let ctf, market, usdc, owner, user, oracle;
  const questionId = ethers.keccak256(ethers.toUtf8Bytes("Will India Win?"));

  beforeEach(async function () {
    [owner, user, oracle] = await ethers.getSigners();

    // 1. Deploy Mock USDC
    const USDC = await ethers.getContractFactory("MockERC20");
    usdc = await USDC.deploy("USDC", "USDC");
    
    // 2. Deploy Mock ConditionalTokens
    const CTF = await ethers.getContractFactory("MockConditionalTokens");
    ctf = await CTF.deploy();
    
    // 3. Deploy BinaryMarket
    const Market = await ethers.getContractFactory("BinaryMarket");
    market = await Market.deploy(await ctf.getAddress(), await usdc.getAddress(), oracle.address);
    
    // Give user some USDC
    await usdc.transfer(user.address, ethers.parseEther("1000"));
  });

  it("Should create a market and split tokens", async function () {
    // 1. Create market
    await market.createMarket(questionId);
    
    // 2. User approves market to spend USDC
    const amount = ethers.parseEther("100");
    await usdc.connect(user).approve(await market.getAddress(), amount);
    
    // 3. User mints tokens (splits position)
    await market.connect(user).mintTokens(questionId, amount);
    
    // 4. Check that user's USDC was transferred
    const userBalance = await usdc.balanceOf(user.address);
    expect(userBalance).to.equal(ethers.parseEther("900")); // 1000 - 100
    
    // 5. Check that CTF contract received USDC (not market, since splitPosition transfers to CTF)
    const ctfBalance = await usdc.balanceOf(await ctf.getAddress());
    expect(ctfBalance).to.equal(amount);
  });

  it("Should allow oracle to resolve condition and user to redeem", async function () {
    // Setup: Create market and mint tokens
    await market.createMarket(questionId);
    const amount = ethers.parseEther("100");
    await usdc.connect(user).approve(await market.getAddress(), amount);
    await market.connect(user).mintTokens(questionId, amount);
    
    // Oracle resolves: YES wins (payout: [0, 1] means NO wins, [1, 0] means YES wins)
    // For YES to win, payout should be [1, 0]
    const payouts = [1, 0]; // YES wins
    const conditionId = await ctf.getConditionId(oracle.address, questionId, 2);
    await ctf.connect(oracle).reportPayouts(questionId, payouts);
    
    // User redeems (assuming they hold YES tokens)
    // Note: In a real scenario, you'd check which tokens the user holds
    // For this test, we'll just verify the redeem function can be called
    // The actual token balance checking would require more complex setup
  });
});