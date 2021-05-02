const { deployments } = require('hardhat');
const { utils } = require('ethers');

const xAudioFixture = deployments.createFixture(async ({ ethers }, options) => {
	const accounts = await ethers.getSigners();
	const [deployer, user1, user2] = accounts;

	const Audio = await ethers.getContractFactory('MockAudio');
	const audio = await Audio.deploy();

	const DelegateManager = await ethers.getContractFactory('MockDelegateManager');
	const delegateManager = await DelegateManager.deploy(audio.address);

	const xAUDIO = await ethers.getContractFactory('xAUDIO');
	const xaudio = await xAUDIO.deploy();

	const xAUDIOProxy = await ethers.getContractFactory('xAUDIOProxy');
	const xaudioProxy = await xAUDIOProxy.deploy(xaudio.address, user2.address); // transfer ownership to multisig
	const xaudioProxyCast = await ethers.getContractAt('xAUDIO', xaudioProxy.address);

	const FEE_DIVISORS = {
		MINT_FEE: '500',
		BURN_FEE: '500',
		CLAIM_FEE: '100',
	};

	await xaudioProxyCast.initialize(
		'xAUDIO',
		audio.address,
		delegateManager.address,
		FEE_DIVISORS.MINT_FEE,
		FEE_DIVISORS.BURN_FEE,
		FEE_DIVISORS.CLAIM_FEE
	);

	await xaudioProxyCast.approveAudio(delegateManager.address);

	return {
		xaudio: xaudioProxyCast,
		audio: audio,
		accounts,
		FEE_DIVISORS,
	};
});

module.exports = { xAudioFixture };
