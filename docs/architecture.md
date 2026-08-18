# Architecture

## Overview

```
┌───────────────────────────┐   HTTPS (browser)    ┌──────────────────────────────┐
│  Godot 4 client           │ ───────────────────► │  Blockfrost (Preprod, reads)  │
│  (godot/ — GDScript)      │ GET /addresses/{a}   │  https://cardano-preprod.    │
│  - Player profile panel   │ GET /block/latest    │  blockfrost.io/api/v0        │
│  - Network status         │ GET /txs/{hash}      │  (CORS-enabled)              │
│  - Balance lookup         │                      └──────────────────────────────┘
│  - Complete Quest         │   HTTPS (browser)    ┌──────────────────────────────┐
│  - Submit Testnet Proof   │ ───────────────────► │  Signing bridge (Vercel,     │
│  - Tx hash + explorer     │ POST /api/quest/     │  https://lab3-godot-cardano- │
└───────────────────────────┘ complete             │  bridge.vercel.app)          │
                                                   │  - reads Koios (tip, address, │
                                                   │    tx status) via proxy       │
                                                   │  - builds + signs tx          │
                                                   │  - embeds metadata (label 674)│
                                                   └───────────────┬──────────────┘
                                                                   │ submit
                                                           ┌───────▼────────┐
                                                           │ Cardano Preprod│
                                                           │ (public testnet)│
                                                           └────────────────┘

Desktop builds: reads go straight to Koios (https://preprod.koios.rest/api/v1),
submit goes to a local bridge (http://127.0.0.1:8787) or the hosted bridge.
```

## Why a signing bridge?

Native Godot 4 has **no access to browser-based CIP-30 wallet extensions** (the way
web apps sign transactions). To send a real Cardano transaction the app must hold a
signing key somewhere. The solution is a **bridge service** that:

1. Holds a funded **testnet-only** wallet (mnemonic read from environment
   variables — `.env` locally, Vercel env vars in production).
2. Builds a transaction with Mesh SDK (`@meshsdk/core`), signs it, and submits it
   to Cardano Preprod.
3. Never exposes the mnemonic to the Godot client — Godot only sends a small JSON
   request (`questId` + `playerAddress`).

> **Godot initiates the workflow; the bridge performs the signing.**

## Live deployment (production)

- **Web demo (frontend):** Godot HTML5 export served by **GitHub Pages**
  (`https://dmt041104111003.github.io/lab3-godot-cardano-testnet/`).
- **Bridge (backend):** deployed on **Vercel** (production)
  `https://lab3-godot-cardano-bridge.vercel.app` with env vars:
  `NETWORK=preprod`, `PROVIDER=blockfrost`, `BLOCKFROST_API_KEY`, `MNEMONIC`.
- The web build auto-detects the browser (`OS.has_feature("web")`) and points
  reads at Blockfrost and submissions at the hosted bridge — visitors can test
  real transactions with no local setup.

## Data flow (as executed on 2026-08-17)

1. Godot starts → queries the chain tip → shows network + live tip height.
   - Web: `GET /block/latest` (Blockfrost) · Desktop: `GET /api/v1/tip` (Koios).
2. User pastes an address → live balance in tADA.
   - Web: `GET /addresses/{addr}` (Blockfrost) · Desktop: `POST /api/v1/address_info` (Koios).
3. User clicks **Complete Quest** → quest flag set locally.
4. User clicks **Submit Testnet Proof** → `POST /api/quest/complete` on the bridge
   (hosted URL on web, localhost on desktop) with `{ questId, playerAddress }`.
5. Bridge builds a tx with metadata (label 674), signs with the testnet wallet,
   submits via Blockfrost, returns `txHash`.
6. Godot polls the tx status every 3 s until the tx is in a block.
7. Godot shows the confirmed hash + block height and opens the explorer.

## Metadata payload (label 674)

```json
{
  "project": "LAB3 Godot Cardano Testnet Demo",
  "event": "quest_completed",
  "quest_id": "demo_001",
  "network": "preprod",
  "player_addr_a": "<first 54 chars of player address>",
  "player_addr_b": "<remaining chars of player address>",
  "tag": "LAB3_GODOT_CARDANO_TRL5_DEMO"
}
```

> Cardano metadata strings are limited to **64 bytes**. Full Bech32 addresses are
> ~103 chars, so the player address is split across `player_addr_a` + `player_addr_b`
> (concatenate to recover the full address). This is verified on-chain in the
> executed transactions (see [testnet-validation.md](testnet-validation.md)).

## Components

| Path | Role |
| ---- | ---- |
| `godot/project.godot` | Godot 4 project (GL Compatibility renderer). |
| `godot/export_presets.cfg` | Web (HTML5) export preset. |
| `godot/scenes/main.tscn` | Minimal main scene (UI is built in code for clarity). |
| `godot/scripts/main.gd` | UI, live reads (Koios/Blockfrost), submit flow, polling. |
| `backend/src/app.js` | Express app: `/health`, read proxies, `/api/quest/complete`, `/api/tx/:hash`. |
| `backend/src/server.js` | Local dev server (binds `127.0.0.1:8787`). |
| `backend/api/index.js` | Vercel serverless entry (exports the Express app). |
| `backend/vercel.json` | Vercel function config + routing. |
| `backend/src/cardano.js` | Mesh SDK wallet, tx build/sign/submit, Koios tx status. |
| `backend/src/config.js` | Env loading, network mapping, validation. |
| `backend/src/scripts/gen-wallet.js` | Generate a fresh testnet wallet. |
| `backend/src/scripts/fund-wallet.js` | Show addresses + current balance (faucet guidance). |

## Network / provider mapping

- `NETWORK=preprod` (default) or `preview` — testnet only, never mainnet.
- `PROVIDER=koios` (default, no key) or `blockfrost` (needs `BLOCKFROST_API_KEY`).
- Mesh `AppWallet` network id: `0` = testnet (preprod/preview), `1` = mainnet
  (verified at runtime: `0 → addr_test1…`, `1 → addr1…`).

## Security notes

- The mnemonic lives only in environment variables — `.env` locally (gitignored)
  or Vercel env vars in production. It is never committed.
- The Godot client never sees the mnemonic; it only talks to the bridge.
- All activity is on Cardano **testnet** (Preprod) — testnet funds only.
- The web build embeds a **public Preprod-only Blockfrost key** for reads (free,
  testnet, CORS-enabled); it is not a mainnet credential.