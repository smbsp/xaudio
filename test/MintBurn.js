const { expect } = require("chai");
const { utils, BigNumber } = require("ethers");
const { xAudioFixture } = require("./fixtures");
const { expectGreaterThanZero, expectGreaterThan } = require("./utils");

describe("xAUDIO: MintBurn", async () => {
  const provider = ethers.provider;

  let xaudio;
  let audio;
  let deployer, user1, user2;

  before(async () => {
    ({ xaudio, accounts, audio } = await xAudioFixture());
    [deployer, user1, user2] = accounts;
  });

  it("should mint xAUDIO tokens to user sending AUDIO", async () => {
    const audioAmount = utils.parseUnits("10",18);
    await audio.transfer(deployer.address, audioAmount);
    await audio.connect(deployer).approve(xaudio.address, audioAmount);
    await xaudio.connect(deployer).mintWithToken(audioAmount);
    const xaudioBal = await xaudio.balanceOf(deployer.address);
    expectGreaterThanZero(xaudioBal);
  });

  it("should register a fee in AUDIO", async () => {
    const audioBal = await xaudio.withdrawableAudioFees();
    expectGreaterThanZero(audioBal);
  });

  it("should burn xAUDIO tokens for AUDIO", async () => {
    const audioBalBefore = await audio.balanceOf(deployer.address);
    const xaudioBal = await xaudio.balanceOf(deployer.address);
    const bnBal = BigNumber.from(xaudioBal);

    const xaudioToRedeem = bnBal.div(BigNumber.from(100));
    await xaudio.burn(xaudioToRedeem.toString());

    const audioBalAfter = await audio.balanceOf(deployer.address);
    expectGreaterThan(audioBalAfter, audioBalBefore);
  });

  it("should not mint with AUDIO if contract is paused", async () => {
    await xaudio.pauseContract();
    const audioAmount = utils.parseEther("10");
    await audio.transfer(user1.address, audioAmount);
    await audio.connect(user1).approve(xaudio.address, audioAmount);
    await expect(
      xaudio.connect(user1).mintWithToken(audioAmount)
    ).to.be.revertedWith("Pausable: paused");
  });
});
