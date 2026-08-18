# Architecture

## Overview

```
┌───────────────────────────┐   HTTPS (browser)    ┌──────────────────────────────┐
│  Godot 4 client           │ ───────────────────► │  Signing bridge (Vercel)      │
│  (godot/ — GDScript)      │ /api/tip            │  https://lab3-godot-cardano-  │
│  - Player profile panel   │ /api/address_info   │  bridge.vercel.app            │
│  - Network status         │ /api/tx_info        │  ├ reads (Koios proxy)         │
│  - Balance lookup         │ /api/quest/complete │  ├ CIP-68 NFT mint            │
│  - Quest + proof          │ /api/quest/complete-│  ├ CIP-0170 attestation       │
│  - CIP-0170 attestation   │   nft               │  └ signs + submits on-chain   │
│  - Tx hash + explorer     │ /api/attestation/*  └───────────────┬──────────────┘
└───────────────────────────┘                                     │ submit
                                                          ┌───────▼────────┐
                                                          │ Cardano Preprod│
                                                          │ (public testnet)│
                                                          └────────────────┘

Desktop builds: reads go straight to Koios (https://preprod.koios.rest/api/v1),
submit goes to a local bridge (http://127.0.0.1:8787) or the hosted bridge.
```

## Signing bridge

Native Godot 4 has **no access to browser CIP-30 wallet extensions**, so a bridge
service holds the testnet wallet and performs signing:

1. Holds a funded **testnet-only** wallet (mnemonic in env vars — `.env` locally,
   Vercel env vars in production).
2. Builds transactions with Mesh SDK (`@meshsdk/core`), signs, and submits.
3. Godot never sees the mnemonic — it sends small JSON requests and receives
   transaction hashes.

> **Godot initiates the workflow; the bridge performs the signing.**

## Live deployment

- **Web build (frontend):** Godot HTML5 export on **GitHub Pages**
  (`https://dmt041104111003.github.io/lab3-godot-cardano-testnet/`).
- **Bridge (backend):** **Vercel** production
  `https://lab3-godot-cardano-bridge.vercel.app` with env vars:
  `NETWORK=preprod`, `PROVIDER=blockfrost`, `BLOCKFROST_API_KEY`, `MNEMONIC`.
- Web builds detect the browser (`OS.has_feature("web")`) and route all reads and
  submissions through the hosted bridge (CORS-enabled). Desktop builds read from
  Koios directly.

## Data flow (baseline)

1. Godot queries the chain tip → shows `preprod` + live tip height.
   (Web: `/api/tip` on the bridge · Desktop: Koios `/tip`.)
2. User pastes a testnet address → live balance in tADA.
3. User clicks **Complete Quest** → quest flag set locally.
4. User clicks **Submit Testnet Proof** → `POST /api/quest/complete`
   `{ questId, playerAddress }`.
5. Bridge builds a tx with metadata **label 674**, signs, submits, returns `txHash`.
6. Godot polls tx status until it is in a block.
7. Godot shows **CONFIRMED (block height …)** and opens the explorer.

## CIP-0170 attestation flow (new integration)

1. Player links a profile to a Cardano wallet (`/api/player/register`).
2. A qualifying milestone → `POST /api/attestation/create` (or `/update`).
3. Backend validates the event and issues a **signed W3C VerifiableCredential**
   (issuer = KERI-style AID, CIP-8 Ed25519 signature).
4. The attestation is **anchored on-chain** — metadata **label 1701** holds
   `attestationHash`, issuer AID, subject, status, version.
5. Godot calls `/api/attestation/verify`; the bridge recomputes the hash and
   verifies the issuer signature against the on-chain anchor.
6. Only then is the achievement shown as **verified**.

State separation:

| # | Layer | Where |
| - | ----- | ----- |
| 1 | Off-chain game state | player profile (backend, per-process) |
| 2 | CIP-0170 attestation | signed VerifiableCredential (held by client/bridge) |
| 3 | Cardano transaction evidence | on-chain anchor, label 1701 (source of truth) |

## On-chain metadata

- **Label 674** — baseline proof / pilot message tag (`LAB3_GODOT_CARDANO_TESTNET`).
- **Label 1701** — CIP-0170 attestation anchor (`tag: LAB3_CIP0170`).
- Cardano metadata strings are capped at **64 bytes**; long addresses are split
  across `_a`/`_b` fields (concatenate to recover).

## Components

| Path | Role |
| ---- | ---- |
| `godot/project.godot` | Godot 4 project (GL Compatibility renderer). |
| `godot/scenes/main.tscn` | Main scene (game hub). |
| `godot/game/game.gd` | Screens: menu, profile, play, verify, achievements, settings. |
| `godot/game/world.gd` | Playable level (Kenney CC0 tiles): fragments, terminals, exit. |
| `godot/autoload/profile.gd` | Persistent player profile + XP (user://profile.json). |
| `godot/autoload/quest_state.gd` | Run-time quest state. |
| `godot/services/cardano_service.gd` | Async bridge client (proof, attestation, tx status). |
| `godot/services/cip30.gd` | CIP-30 wallet connector (browser). |
| `backend/src/app.js` | Express app: read proxies, quest, CIP-68 mint, CIP-0170 endpoints. |
| `backend/src/cardano.js` | Mesh SDK wallet, tx build/sign/submit, CIP-68 mint, Koios reads. |
| `backend/src/cip0170.js` | CIP-0170: issuer AID, VC signing, on-chain anchor, verification. |
| `backend/src/config.js` | Env loading, network mapping, validation. |
| `backend/api/index.js` | Vercel serverless entry. |
| `backend/vercel.json` | Vercel function config + routing. |

## Network / provider

- `NETWORK=preprod` (default) or `preview` — testnet only.
- `PROVIDER=koios` (default, no key) or `blockfrost` (needs `BLOCKFROST_API_KEY`).
- Mesh `AppWallet` network id: `0` = testnet (preprod/preview), `1` = mainnet.

## Security

- Mnemonic lives only in env vars (`.env` gitignored locally; Vercel in prod).
- Godot never holds the mnemonic.
- All activity is on Cardano **testnet** (Preprod).
