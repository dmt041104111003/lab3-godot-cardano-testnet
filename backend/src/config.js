import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Prefer the repo-root .env (shared with Godot docs), fall back to backend/.env.
dotenv.config({ path: path.join(__dirname, '..', '..', '.env'), quiet: true });
dotenv.config({ path: path.join(__dirname, '..', '.env'), quiet: true });
dotenv.config({ quiet: true });

const rawNetwork = (process.env.NETWORK || 'preprod').toLowerCase();
const network = ['mainnet', 'preprod', 'preview'].includes(rawNetwork) ? rawNetwork : 'preprod';

// AppWallet network id convention (cardano-serialization-lib):
//   0 = testnet networks (preprod / preview), 1 = mainnet.
// Verified at runtime: networkId 0 -> addr_test1..., networkId 1 -> addr1...
const appWalletNetworkId = network === 'mainnet' ? 1 : 0;

const provider = (process.env.PROVIDER || 'koios').toLowerCase() === 'blockfrost' ? 'blockfrost' : 'koios';

const mnemonic = (process.env.MNEMONIC || '')
  .trim()
  .split(/[\s,]+/)
  .filter(Boolean);

const explorerBase =
  network === 'preview'
    ? 'https://preview.cardanoscan.io/transaction'
    : network === 'mainnet'
      ? 'https://cardanoscan.io/transaction'
      : 'https://preprod.cardanoscan.io/transaction';

export const config = {
  network,
  appWalletNetworkId,
  provider,
  mnemonic,
  port: Number(process.env.PORT || 8787),
  blockfrostApiKey: process.env.BLOCKFROST_API_KEY || '',
  databaseUrl: process.env.DATABASE_URL || '',
  explorerUrl: (txHash) => `${explorerBase}/${txHash}`,
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  googleClientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
  googleRedirectUri: process.env.GOOGLE_REDIRECT_URI || 'https://lab3-godot-cardano-bridge.vercel.app/api/auth/callback/google',
  googleFrontendUrl: process.env.GOOGLE_FRONTEND_URL || 'https://vercel-game-alpha.vercel.app',
};

export function validateConfig() {
  if (!mnemonic.length || mnemonic.length < 15) {
    throw new Error(
      'MNEMONIC is missing or too short. Copy .env.example to .env and set MNEMONIC. Generate one with: npm run key',
    );
  }
  if (provider === 'blockfrost' && !config.blockfrostApiKey) {
    throw new Error('PROVIDER=blockfrost requires BLOCKFROST_API_KEY in .env');
  }
}
