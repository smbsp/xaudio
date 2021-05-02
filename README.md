# Staking AUDIO tokens using Figment Node Operator

Audius is a new streaming platform designed for musicians–they can build a fanbase, share works in progress, and finally share completed tracks with the world.

The code is forked from xToken protocol. xToken builds wrappers around complicated token models, usually "staking".

## Description

Audius native token, AUDIO, is used to stake (to earn fees and rewards), for feature access on the platform, and to participate in on-chain governance. The most important aspects of the staking process are:

Stake/Staking - The act of escrowing Audius tokens to the contracts in order to run a Service. Staking can happen by either Service Providers (Figment) or through Delegators (xToken) on behalf of Service Providers. Good actors can claim rewards, whereas there could be a Slashing penalty for bad actors.

Service Provider - Anyone that hosts a Service. A requirement to be a Service Provider is to meet the minimum token Stake. Staked, Figment are some examples.

Delegator - Anyone that holds Audius tokens and wants to participate in the staking process but does not run a service directly like a Service Provider does. Instead, delegators direct their funds on behalf of a specified Service Provider so the provider can leverage delegator funds to register additional Services

## General flow

1. User sends AUDIO tokens to the smart contract<br>
2. xAUDIO tokens are minted for the amount of AUDIO tokens sent after deducting the fee<br>
3. User can at any point burn there xAUDIO tokens and withdraw AUDIO tokens<br>
4. xAUDIO pools the AUDIO tokens and stake it to the AUDIUS protocol using Figment Service Provider<br>
5. xAUDIO can withdraw the staked AUDIO along with the rewards in AUDIO token after a period of 7 days<br>

## Benefits

1. Saves gas fee for users by pooling the AUDIO tokens<br>
2. Non-custodial<br>

## Installation

Clone the repository, add ALCHEMY_KEY in the .env file and run the following commands.

```
npm install
npx hardhat test
```

## Improvements

1. Claiming rewards for individual users is not implemented yet<br>
2. Service Provider is hard-coded at the moment. Better to have an admin function for changing node operators<br>
3. Creating a front-end to demonstrate the functionality
