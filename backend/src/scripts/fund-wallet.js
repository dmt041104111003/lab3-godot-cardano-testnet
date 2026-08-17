/**
 * Prints the funded-wallet addresses for the configured MNEMONIC and checks the
 * current preprod/preview balance via Blockfrost (no external account needed).
 *
 * Run:  npm run fund
 *
 * If the balance is 0, fund the wallet using the official Cardano testnet
 * faucet with the STAKE ADDRESS printed below:
 *   https://docs.cardano.org/cardano-testnet/tools/faucet/
 */
import { BlockfrostProvider } from '@meshsdk/core';
import { config, validateConfig } from '../config.js';
import { getWalletAddresses } from '../cardano.js';

validateConfig();

const { paymentAddress, rewardAddress } = await getWalletAddresses();

const provider = new BlockfrostProvider(config.blockfrostApiKey);

let balanceLovelace = 0;
try {
  const utxos = await provider.fetchAddressUTxOs(paymentAddress);
  for (const utxo of utxos) {
    for (const amt of utxo.output.amount) {
      if (amt.unit === 'lovelace') {
        balanceLovelace += Number(amt.quantity);
      }
    }
  }
} catch {
  balanceLovelace = 0;
}

console.log('==============================================');
console.log(` FUND WALLET  (network: ${config.network})`);
console.log('==============================================');
console.log('PAYMENT ADDRESS:', paymentAddress);
console.log('STAKE ADDRESS: ', rewardAddress);
console.log('');
console.log(`BALANCE: ${(balanceLovelace / 1_000_000).toFixed(6)} tADA (${balanceLovelace} lovelace)`);
console.log('');
if (balanceLovelace > 0) {
  console.log('The wallet already has funds. No faucet needed.');
} else {
  console.log('The wallet has NO funds. Fund it now:');
  console.log('  1. Open https://docs.cardano.org/cardano-testnet/tools/faucet/');
  console.log('  2. Choose the network (' + config.network + ') and paste your STAKE ADDRESS below.');
  console.log('  3. Request test ADA (tADA).');
  console.log('');
  console.log('STAKE ADDRESS:', rewardAddress);
}
console.log('==============================================');