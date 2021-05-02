// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');
const { utils, BigNumber } = require("ethers");

// mainnet
const ADDRESSES = {
	audio: '0x22A9CCfdd10382D9cD18cA4437ff375bd7A87BBd',
	delegateManager: '0x612B4367a7Ae2cf346dC3759623a9c22102ff8d6',
};

// run on mainnet fork
async function main() {
	const accounts = await ethers.getSigners();
	const [deployer, user1, user2] = accounts;

	const xAudio = await ethers.getContractFactory('xAUDIO');
	const xaudio = await xAudio.deploy();

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
		ADDRESSES.audio,
		ADDRESSES.delegateManager,
		FEE_DIVISORS.MINT_FEE,
		FEE_DIVISORS.BURN_FEE,
		FEE_DIVISORS.CLAIM_FEE
	);

	console.log('xaudioProxyCast:', xaudioProxyCast.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});