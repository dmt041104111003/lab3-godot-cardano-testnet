/**
 * Generates a fresh testnet wallet (mnemonic + addresses).
 * Run:  npm run key
 *
 * NEVER commit the printed mnemonic. Put it in `.env` (gitignored) instead.
 */
import { generateMnemonic, AppWallet } from '@meshsdk/core';
import { config } from '../config.js';

const strength = Number(process.argv[2] || 256); // 128,160,192,224,256 bits
const words = generateMnemonic(strength).split(' ');

const wallet = new AppWallet({
  networkId: config.appWalletNetworkId,
  key: { type: 'mnemonic', words },
});
await wallet.init();

const paymentAddress = wallet.getPaymentAddress();
const stakeAddress = wallet.getRewardAddress();

console.log('==============================================');
console.log(` NEW TESTNET WALLET (network: ${config.network})`);
console.log('==============================================');
console.log(`MNEMONIC (${words.length} words):`);
console.log(words.join(' '));
console.log('');
console.log('PAYMENT ADDRESS (used by the bridge, and by MeshFaucet/Blockfrost funding):');
console.log(paymentAddress);
console.log('');
console.log('STAKE ADDRESS (needed by the official Cardano faucet):');
console.log(stakeAddress);
console.log('');
console.log('Next steps:');
console.log('  1. Copy the MNEMONIC into your .env file.');
console.log('  2. Fund it:  npm run fund   (or paste the stake address into the official faucet).');
console.log('  3. Start the bridge:  npm start');
console.log('==============================================');