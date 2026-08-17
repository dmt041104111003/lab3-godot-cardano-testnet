import { AppWallet, MeshTxBuilder, KoiosProvider, BlockfrostProvider, resolvePrivateKey } from '@meshsdk/core';
import { config } from './config.js';

const KOIOS_HOSTS = {
  mainnet: 'https://api.koios.rest',
  preprod: 'https://preprod.koios.rest',
  preview: 'https://preview.koios.rest',
};

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

export function createProvider() {
  if (config.provider === 'blockfrost') {
    return new BlockfrostProvider(config.blockfrostApiKey);
  }
  return new KoiosProvider(`${KOIOS_HOSTS[config.network]}/api/v1`);
}

export async function createWallet() {
  const wallet = new AppWallet({
    networkId: config.appWalletNetworkId,
    key: { type: 'mnemonic', words: config.mnemonic },
  });
  await wallet.init();
  return wallet;
}

export async function getWalletAddresses() {
  const wallet = await createWallet();
  return {
    paymentAddress: wallet.getPaymentAddress(),
    rewardAddress: wallet.getRewardAddress(),
    networkId: wallet.getNetworkId(),
  };
}

// ---------------------------------------------------------------------------
// Transaction building, signing and submission
// ---------------------------------------------------------------------------

/**
 * Builds and signs a minimal Cardano testnet transaction that carries the
 * quest-completion metadata under label 674. Change (and fee) return to the
 * bridge wallet. Returns the signed tx hex ready for submission.
 */
export async function buildAndSignProofTx(metadata) {
  const provider = createProvider();
  const { paymentAddress } = await getWalletAddresses();

  const utxos = await provider.fetchAddressUTxOs(paymentAddress);
  if (!utxos || utxos.length === 0) {
    throw new Error(
      `Bridge wallet has no UTxOs on ${config.network}. Fund it first (see docs/testnet-validation.md).`,
    );
  }

  const txBuilder = new MeshTxBuilder({ fetcher: provider, submitter: provider });

  const signedTxHex = await txBuilder
    .setNetwork(config.network)
    .metadataValue(674, metadata)
    .changeAddress(paymentAddress)
    .selectUtxosFrom(utxos)
    .signingKey(resolvePrivateKey(config.mnemonic))
    .complete();

  return { signedTxHex, paymentAddress };
}

/**
 * End-to-end proof submission: build -> sign -> submit.
 * Returns the on-chain transaction hash and metadata for evidence.
 */
export async function submitProof({ questId, playerAddress }) {
  const provider = createProvider();
  const { paymentAddress, rewardAddress } = await getWalletAddresses();

  const metadata = {
    project: 'LAB3 Godot Cardano Testnet Demo',
    event: 'quest_completed',
    quest_id: questId || 'demo_001',
    network: config.network,
    player_address: playerAddress || '',
    bridge_wallet: paymentAddress,
    tag: 'LAB3_GODOT_CARDANO_TRL5_DEMO',
  };

  const { signedTxHex } = await buildAndSignProofTx(metadata);
  const txHash = await provider.submitTx(signedTxHex);

  return {
    txHash,
    network: config.network,
    metadataLabel: 674,
    metadata,
    walletAddress: paymentAddress,
    rewardAddress,
    explorerUrl: config.explorerUrl(txHash),
  };
}

// ---------------------------------------------------------------------------
// Transaction status (public Koios reads, no key required)
// ---------------------------------------------------------------------------

async function koiosJson(p, { method = 'GET', body } = {}) {
  const res = await fetch(`${KOIOS_HOSTS[config.network]}/api/v1/${p}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    throw new Error(`Koios ${p} failed: HTTP ${res.status}`);
  }
  return res.json();
}

export async function txStatus(txHash) {
  const [tip, info] = await Promise.all([
    koiosJson('tip'),
    koiosJson('tx_info', { method: 'POST', body: { _tx_hashes: [txHash] } }),
  ]);

  const tipHeight = tip?.[0]?.block_height ?? null;
  const row = Array.isArray(info) ? info[0] : null;

  if (!row || row.block_height == null) {
    return {
      txHash,
      status: 'not_found',
      confirmations: 0,
      explorerUrl: config.explorerUrl(txHash),
    };
  }

  const confirmations = tipHeight != null ? tipHeight - row.block_height + 1 : 1;
  return {
    txHash,
    status: 'confirmed',
    blockHeight: row.block_height,
    confirmations,
    explorerUrl: config.explorerUrl(txHash),
  };
}