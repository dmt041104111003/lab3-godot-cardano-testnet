import express from 'express';
import cors from 'cors';
import { config, validateConfig } from './config.js';
import { submitProof, txStatus, koiosJson } from './cardano.js';

validateConfig();

const app = express();
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

app.get('/api/tx/:hash', async (req, res) => {
  try {
    const result = await txStatus(req.params.hash);
    res.json({ ok: true, ...result });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

app.listen(config.port, () => {
  console.log(`[bridge] LAB3 Godot x Cardano bridge listening on http://127.0.0.1:${config.port}`);
  console.log(`[bridge] network=${config.network} provider=${config.provider}`);
});