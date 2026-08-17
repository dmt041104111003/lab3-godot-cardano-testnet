import express from 'express';
import cors from 'cors';
import { config, validateConfig } from './config.js';
import { submitProof, txStatus } from './cardano.js';

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