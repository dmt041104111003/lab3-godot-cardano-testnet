# Architecture

## Overview

```
┌───────────────────────────┐        HTTPS        ┌──────────────────────────────┐
│      Godot 4 client       │  ─────────────────► │   Public Koios API (reads)    │
│  (godot/ — GDScript)      │  POST /address_info │  https://preprod.koios.rest  │
│                           │  POST /tx_info      │  - address balance / UTxOs    │
│  - Player profile panel   │  GET  /tip          │  - transaction status         │
│  - Network status         │                     └──────────────────────────────┘
│  - Balance lookup         │
│  - Complete Quest         │        HTTP         ┌──────────────────────────────┐
│  - Submit Testnet Proof   │  ─────────────────► │  Local signing bridge         │
│  - Tx hash + explorer     │  POST /api/quest/   │  (backend/ — Node.js + Mesh) │
│                           │  complete           │  - builds + signs tx          │
└───────────────────────────┘                     │  - embeds metadata (label 674)│
                                                  │  - submits to Cardano         │
                                                  └───────────────┬──────────────┘
                                                                  │ submit
                                                          ┌───────▼────────┐
                                                          │ Cardano Preprod│
                                                          │ / Preview      │
                                                          └────────────────┘
```

## Why a signing bridge?

Native Godot 4 has **no access to browser-based CIP-30 wallet extensions** (the way
web apps sign transactions). To send a real Cardano transaction the app must hold a
signing key somewhere. The smallest, safest option is a **local bridge process**
that:

1. Holds a funded **testnet-only** wallet (mnemonic read from `.env`, gitignored).
2. Builds a transaction with Mesh SDK (`@meshsdk/core`), signs it, and submits it to
   Cardano Preprod/Preview.
3. Never exposes the mnemonic to the Godot client — Godot only sends a small JSON
   request (`questId` + `playerAddress`).

> **Godot initiates the workflow; the bridge performs the signing.** This matches
> the "external wallet/bridge performs signing" allowance in the requirements.

## Data flow (real evidence path)

1. Godot starts → `GET /api/v1/tip` (Koios) → shows network + tip height.
2. User pastes an address → `POST /api/v1/address_info` → live balance in tADA.
3. User clicks **Complete Quest** → quest flag set locally.
4. User clicks **Submit Testnet Proof** → `POST http://127.0.0.1:8787/api/quest/complete`
   with `{ questId, playerAddress }`.
5. Bridge builds a tx with metadata (label 674), signs with the testnet wallet,
   submits via Blockfrost, returns `txHash`.
6. Godot polls `POST /api/v1/tx_info` (Koios) every 3 s until the tx is in a block.
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
> (concatenate to recover the full address). This is verified on-chain.

## Components

| Path | Role |
| ---- | ---- |
| `godot/project.godot` | Godot 4 project (GL Compatibility renderer). |
| `godot/scenes/main.tscn` | Minimal main scene (UI is built in code for clarity). |
| `godot/scripts/main.gd` | UI, Koios reads, submit flow, confirmation polling. |
| `godot/scripts/offline_data.gd` | Offline development data, **strictly separated** (OFFLINE_MODE). |
| `backend/src/server.js` | Express bridge: `/health`, `/api/quest/complete`, `/api/tx/:hash`. |
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

- The mnemonic lives only in `.env` (gitignored) or environment variables.
- No seed phrases, private keys, or API keys are committed.
- The bridge binds to `127.0.0.1` and is intended for local use only.
- All addresses in metadata are testnet (`addr_test1…`) addresses.