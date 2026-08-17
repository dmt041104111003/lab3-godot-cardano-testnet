import { AppWallet, MeshTxBuilder, KoiosProvider, resolvePrivateKey, resolveTxHash, generateMnemonic } from '@meshsdk/core';

const words = generateMnemonic(256).split(' ');

const wallet = new AppWallet({ networkId: 1, key: { type: 'mnemonic', words } });
await wallet.init();
console.log('payment:', wallet.getPaymentAddress());
console.log('reward: ', wallet.getRewardAddress());
console.log('key ok:', resolvePrivateKey(words).slice(0, 20) + '...');

const provider = new KoiosProvider('https://preprod.koios.rest/api/v1');
const addr = wallet.getPaymentAddress();
const utxos = await provider.fetchAddressUTxOs(addr);
console.log('live utxos for test wallet:', utxos.length);

const fakeUtxo = {
  input: { outputIndex: 0, txHash: '0000000000000000000000000000000000000000000000000000000000000000' },
  output: { address: addr, amount: [{ unit: 'lovelace', quantity: '20000000' }] },
};

const builder = new MeshTxBuilder({ fetcher: provider, submitter: provider });
builder
  .metadataValue(674, { project: 'test', event: 'quest_completed', quest_id: 'x', network: 'preprod', player_address: 'addr_test_xyz' })
  .changeAddress(addr)
  .selectUtxosFrom([fakeUtxo])
  .signingKey(resolvePrivateKey(words));

const txHex = await builder.complete();
console.log('signed tx hex length:', txHex.length);
console.log('tx hash:', resolveTxHash(txHex));