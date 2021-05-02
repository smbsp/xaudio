const { expect, assert } = require('chai');
const { utils, BigNumber } = require('ethers');
const { xAudioFixture } = require('./fixtures');
const { expectGreaterThanZero, expectGreaterThan, expectEqual, increaseTime } = require('./utils');

describe("xAUDIO: Stake & Unstake", async() => {
    let xaudio
    let audio
    let deployer, user1, user2

    let oldAdminActiveTimestamp
    let oldWithdrawableFees
    
    before(async() => {
      ({ xaudio, accounts, audio } = await xAudioFixture())
      ;[deployer, user1, user2] = accounts

      oldAdminActiveTimestamp = await xaudio.adminActiveTimestamp() 
      oldWithdrawableFees = await xaudio.withdrawableAudioFees() 
    })

    it('should stake the correct proportion of token', async () => {
        const audioAmount = utils.parseUnits("10",18);
        await audio.transfer(user1.address, audioAmount);
        await audio.connect(user1).approve(xaudio.address, audioAmount);
        await xaudio.connect(user1).mintWithToken(audioAmount);
        await xaudio.stake();
        
        const stakedBal = await xaudio.getStakedBalance();
        const bufferBal = await xaudio.getBufferBalance();
        
        const BUFFER_TARGET = BigNumber.from(20);
        expectEqual(bufferBal.add(stakedBal), bufferBal.mul(BUFFER_TARGET))
    });
    
    it('should not allow non-admin to use permissioned stake function', async () => {
        await expect(xaudio.connect(user1).stake()).to.be.revertedWith('Non-admin caller')
    });
    
    it('should register an increase in withdrawable AUDIO fees', async () => {
        const withdrawableFees = await xaudio.withdrawableAudioFees() 
        expectGreaterThan(withdrawableFees, oldWithdrawableFees)
    });
    
    it('should let admin unstake full quantity if necessary', async () => {
        const stakedBal = await xaudio.getStakedBalance();
        const bufferBalBefore = await xaudio.getBufferBalance()
        const ONE_WEEK = 60 * 60 * 24 * 7 + 1;
        await increaseTime(ONE_WEEK);
        await xaudio.unstake(stakedBal)
        const bufferBalAfter = await xaudio.getBufferBalance()
        expectGreaterThan(bufferBalAfter, bufferBalBefore)
    });
    
})