const { expect, assert } = require("chai");
const { utils, BigNumber } = require("ethers");
const { xAudioFixture } = require("./fixtures");
const {
  expectGreaterThanZero,
  expectGreaterThan,
  expectEqual,
  increaseTime,
} = require("./utils");

describe("xAUDIO: Util Functions", async () => {
  let xaudio;
  let audio;
  let deployer, user1, user2, user3;

  let FEE_DIVISORS;

  before(async () => {
    ({ xaudio, accounts, audio, FEE_DIVISORS } = await xAudioFixture());
    [deployer, user1, user2, user3] = accounts;
  });

  it("should register correct fee divisors", async () => {
    const feeDivisors = await xaudio.feeDivisors();
    expectEqual(feeDivisors.mintFee, FEE_DIVISORS.MINT_FEE);
    expectEqual(feeDivisors.burnFee, FEE_DIVISORS.BURN_FEE);
    expectEqual(feeDivisors.claimFee, FEE_DIVISORS.CLAIM_FEE);
  });

  it("should not let non-admin unstake full quantity", async () => {
    const audioAmount = utils.parseEther("10");
    await audio.transfer(user1.address, audioAmount);
    await audio.connect(user1).approve(xaudio.address, audioAmount);
    await xaudio.connect(user1).mintWithToken(audioAmount);
    await xaudio.stake();

    const stakedBal = await xaudio.getStakedBalance();
    expectGreaterThanZero(stakedBal);

    await expect(xaudio.connect(user1).unstake(stakedBal)).to.be.revertedWith('Non-admin caller')
  });

  it("should not let admin unstake full quantity if liquidation period has not elapsed", async () => {
    const stakedBal = await xaudio.getStakedBalance();

    await expect(xaudio.connect(deployer).unstake(stakedBal)).to.be.revertedWith('Liquidation time not elapsed')
  });

  it("should allow for a permissioned manager to be set", async () => {
    await xaudio.setManager(user3.address);
    await xaudio.connect(user3).stake();

    assert(true); // if no revert, test passes
  });
});
