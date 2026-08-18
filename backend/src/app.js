import express from 'express';
import cors from 'cors';
import { config, validateConfig } from './config.js';
import { submitProof, txStatus, koiosJson, mintAchievement } from './cardano.js';
import {
  registerPlayer,
  createAttestation,
  updateAttestation,
  verifyAttestation,
  getAttestationRecord,
  getOnChainAnchor,
  prepareAttestation,
} from './cip0170.js';
import { savePlayer, loadPlayer, ensureSchema } from './storage.js';

validateConfig();
ensureSchema().catch((err) => console.error('[storage] schema init failed:', err.message));

export const app = express();
app.use(cors());
app.use(express.json({ limit: '64kb' }));

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'lab3-godot-cardano-bridge',
    network: config.network,
    provider: config.provider,
    time: new Date().toISOString(),
  });
});

// Read-only proxies. Browser builds of the Godot app cannot call Koios directly
// (no CORS headers), so the bridge re-exposes the public reads with CORS enabled.
app.get('/api/tip', async (_req, res) => {
  try {
    res.json(await koiosJson('tip'));
  } catch (err) {
    res.status(502).json({ ok: false, error: err.message });
  }
});

app.post('/api/address_info', async (req, res) => {
  try {
    const { _addresses } = req.body || {};
    if (!Array.isArray(_addresses) || _addresses.length === 0) {
      return res.status(400).json({ ok: false, error: '_addresses (array) is required' });
    }
    res.json(await koiosJson('address_info', { method: 'POST', body: req.body }));
  } catch (err) {
    res.status(502).json({ ok: false, error: err.message });
  }
});

app.post('/api/tx_info', async (req, res) => {
  try {
    const { _tx_hashes } = req.body || {};
    if (!Array.isArray(_tx_hashes) || _tx_hashes.length === 0) {
      return res.status(400).json({ ok: false, error: '_tx_hashes (array) is required' });
    }
    res.json(await koiosJson('tx_info', { method: 'POST', body: req.body }));
  } catch (err) {
    res.status(502).json({ ok: false, error: err.message });
  }
});

app.post('/api/quest/complete', async (req, res) => {
  try {
    const { questId, playerAddress } = req.body || {};
    if (!questId || typeof questId !== 'string') {
      return res.status(400).json({ ok: false, error: 'questId (string) is required' });
    }
    const result = await submitProof({ questId, playerAddress });
    res.json({ ok: true, ...result });
  } catch (err) {
    console.error('[submit] failed:', err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post('/api/quest/complete-nft', async (req, res) => {
  try {
    const { questId, playerAddress } = req.body || {};
    if (!questId || typeof questId !== 'string') {
      return res.status(400).json({ ok: false, error: 'questId (string) is required' });
    }
    const result = await mintAchievement({ questId, playerAddress });
    res.json({ ok: true, ...result });
  } catch (err) {
    console.error('[mint] failed:', err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.get('/api/tx/:hash', async (req, res) => {
  try {
    const result = await txStatus(req.params.hash);
    res.json({ ok: true, ...result });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// ---------------------------------------------------------------------------
// CIP-0170 — on-chain identity & attestation
// ---------------------------------------------------------------------------
app.post('/api/player/register', async (req, res) => {
  try {
    const { playerAddress, playerName } = req.body || {};
    const result = registerPlayer({ playerAddress, playerName });
    res.json(result);
  } catch (err) {
    res.status(400).json({ ok: false, error: err.message });
  }
});

// Off-chain player progression (Postgres / Neon). On-chain evidence is separate.
app.post('/api/player/save', async (req, res) => {
  try {
    const { address, data } = req.body || {};
    if (!address || typeof address !== 'string' || address.length < 40) {
      return res.status(400).json({ ok: false, error: 'a valid address is required' });
    }
    const result = await savePlayer(address, data || {});
    res.json({ ok: true, ...result });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.get('/api/player/:address', async (req, res) => {
  try {
    const data = await loadPlayer(req.params.address);
    res.json({ ok: true, data });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post('/api/attestation/prepare', async (req, res) => {
  try {
    const { playerAddress, playerName, achievement, event, questId, tier, progression, update } = req.body || {};
    if (!achievement || typeof achievement !== 'string') {
      return res.status(400).json({ ok: false, error: 'achievement (string) is required' });
    }
    const result = await prepareAttestation({ playerAddress, playerName, achievement, event, questId, tier, progression, update });
    res.json(result);
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post('/api/attestation/create', async (req, res) => {
  try {
    const { playerAddress, playerName, achievement, event, questId, tier, progression, playerSignature, playerKey, playerAddressCip30 } = req.body || {};
    if (!achievement || typeof achievement !== 'string') {
      return res.status(400).json({ ok: false, error: 'achievement (string) is required' });
    }
    const result = await createAttestation({ playerAddress, playerName, achievement, event, questId, tier, progression, playerSignature, playerKey, playerAddressCip30 });
    res.json(result);
  } catch (err) {
    console.error('[attest] failed:', err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post('/api/attestation/update', async (req, res) => {
  try {
    const { playerAddress, playerName, achievement, event, questId, tier, progression, playerSignature, playerKey, playerAddressCip30 } = req.body || {};
    if (!achievement || typeof achievement !== 'string') {
      return res.status(400).json({ ok: false, error: 'achievement (string) is required' });
    }
    const result = await updateAttestation({ playerAddress, playerName, achievement, event, questId, tier, progression, playerSignature, playerKey, playerAddressCip30 });
    res.json(result);
  } catch (err) {
    console.error('[attest-update] failed:', err.message);
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.post('/api/attestation/verify', async (req, res) => {
  try {
    const { txHash, attestation, signature, key, issuerAddr, playerSignature, playerKey, playerAddr } = req.body || {};
    if (!txHash) return res.status(400).json({ ok: false, error: 'txHash is required' });
    const result = await verifyAttestation({ txHash, attestation, signature, key, issuerAddr, playerSignature, playerKey, playerAddr });
    res.json({ ok: true, ...result });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.get('/api/attestation/onchain/:txHash', async (req, res) => {
  try {
    const anchor = await getOnChainAnchor(req.params.txHash);
    res.json({ ok: true, anchor });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});