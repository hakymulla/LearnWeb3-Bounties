'use strict';

const {
    getDefaultProvider,
    Contract,
    constants: { AddressZero },
} = require('ethers');
const {
    utils: { deployContract },
} = require('@axelar-network/axelar-local-dev');

const { sleep } = require('../../utils');
const DistributionExecutable = require('../../artifacts/examples/bounty/Bounty.sol/Bounty.json');
const Gateway = require('../../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol/IAxelarGateway.json');
const IERC20 = require('../../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol/IERC20.json');

async function deploy(chain, wallet) {
    console.log(`Deploying DistributionExecutable for ${chain.name}.`);
    const contract = await deployContract(wallet, DistributionExecutable, [chain.gateway, chain.gasReceiver]);
    chain.distributionExecutable = contract.address;
    console.log(`Deployed DistributionExecutable for ${chain.name} at ${chain.distributionExecutable}.`);
}

async function test(chains, wallet, options) {
    const args = options.args || [];
    const getGasPrice = options.getGasPrice;
    const source = chains.find((chain) => chain.name === (args[0] || 'Avalanche'));
    const destination = chains.find((chain) => chain.name === (args[1] || 'Fantom'));
    const amount = Math.floor(parseFloat(args[2])) * 1e6 || 10e6;
    // const account = args[3];
    const account = args[3];
    const accounts = [account]

    const message = args[4];


    // if (account.length === 0) accounts.push(wallet.address);

    for (const chain of [source, destination]) {
        const provider = getDefaultProvider(chain.rpc);
        chain.wallet = wallet.connect(provider);
        chain.contract = new Contract(chain.distributionExecutable, DistributionExecutable.abi, chain.wallet);
        chain.gateway = new Contract(chain.gateway, Gateway.abi, chain.wallet);
        const usdcAddress = chain.gateway.tokenAddresses('aUSDC');
        chain.usdc = new Contract(usdcAddress, IERC20.abi, chain.wallet);
    }


    async function logAccountBalances() {
        for (const account of accounts) {
            console.log(`Balance of ${wallet.address} at ${source.name} is ${await source.usdc.balanceOf(wallet.address) / 1e6} aUSDC`);
            console.log(`${account} has ${(await destination.usdc.balanceOf(account)) / 1e6} aUSDC`);
            const val = await destination.contract.messages(account);
            console.log(`${account} Message is ${val} `);
        }
    }

    console.log('--- Initially ---');
    await logAccountBalances();

    const gasLimit = 3e10;
    let gasPrice = await getGasPrice(source, destination, AddressZero);
    const balance = BigInt(await destination.usdc.balanceOf(accounts[0]));

    const approveTx = await source.usdc.approve(source.contract.address, amount);
    await approveTx.wait();

    const sendTx = await source.contract.sendToMany(destination.name, destination.distributionExecutable, accounts, message, 'aUSDC', amount,
        {
            // value: BigInt(Math.floor(gasLimit * gasPrice)),
            value: BigInt(4e17),
            gasLimit: 3e6
        }
    );
    await sendTx.wait();

    while (BigInt(await destination.usdc.balanceOf(accounts[0])) === balance) {
        await sleep(5000);
    }

    console.log('--- After ---');
    await logAccountBalances();
}

module.exports = {
    deploy,
    test,
};