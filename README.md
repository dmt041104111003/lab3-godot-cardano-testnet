# LAB3 Godot × Cardano Testnet Demo

A minimal but **real** Godot 4 application that connects to the **Cardano Preprod
testnet**, reads live on-chain data, lets a player complete a quest, and submits a
**real testnet transaction** carrying verifiable metadata — then shows the
confirmed transaction hash inside the game.

This is the **validated Godot × Cardano product baseline** that a future CIP-0170
integration will build on. It is **not** the CIP-0170 integration itself.

---

## ✅ What this prototype proves

> This prototype demonstrates a functional Godot application interacting with a
> public Cardano testnet environment. It retrieves live Cardano data, initiates a
> testnet blockchain interaction from a gameplay flow, receives the resulting
> transaction hash, and verifies confirmation on-chain.

## ⛔ What it does NOT prove

> The prototype does not yet implement CIP-0170. CIP-0170 is the next
> integration step that will build on this validated Godot × Cardano baseline.

---

## Real on-chain evidence (Preprod, 2026-08-17)

Two independent testnet transactions were submitted and confirmed from this
workflow. No hashes on this page are fabricated.

| # | Transaction hash | Explorer |
| - | ---------------- | -------- |
| 1 | `30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162` | https://preprod.cardanoscan.io/transaction/30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162 |
| 2 | `4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501` | https://preprod.cardanoscan.io/transaction/4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501 |

Both transactions carry metadata under **label 674** with tag
`LAB3_GODOT_CARDANO_TRL5_DEMO` (verified on-chain via Blockfrost — see
[docs/testnet-validation.md](docs/testnet-validation.md)).

## Verify it yourself — the trio

1. **Source** — this repository (everything is documented and runnable).
2. **Live demo** — a browser playable build (Godot Web export) deployed to
   GitHub Pages / Netlify / Vercel: see [docs/live-demo.md](docs/live-demo.md).
3. **On-chain proof** — the real Preprod transactions above, openable in any
   Cardano explorer.

> The explorer link is the strongest proof; the live demo lets a reviewer open
> the app and test it directly. Recording a demo video is optional.

---

## How it works (10-second version)

```
Godot 4  ──reads live data──►  Koios public API (Preprod)
   │                              (balance / tip / tx status)
   │  POST /api/quest/complete
   ▼
Local signing bridge (Node.js + Mesh SDK)  ──signs + submits──►  Cardano Preprod
   │
   └──► returns tx hash ──► Godot polls chain ──► CONFIRMED + explorer link
```

Godot initiates the workflow; the small local bridge performs the signing (native
Godot cannot reach browser CIP-30 wallets). Full detail:
[docs/architecture.md](docs/architecture.md).

---

## Repository structure

```
.
├── README.md                 ← you are here
├── LICENSE                   MIT
├── .env.example              ← template for local secrets (gitignored)
├── .gitignore
├── docs/
│   ├── architecture.md       ← system design, data flow, security
│   ├── testnet-validation.md ← REAL executed transactions + how to reproduce
│   ├── evidence.md           ← validation & evidence checklist
│   ├── live-demo.md          ← Godot Web export + GitHub Pages deployment
│   ├── demo-video-script.md  ← optional 60–90 s demo video script
│   └── trl5-evidence.md      ← ready-to-paste TRL5 wording (fill demo URL)
├── godot/
│   ├── project.godot
│   ├── export_presets.cfg    ← Web (HTML5) export preset
│   ├── scenes/main.tscn
│   └── scripts/
│       ├── main.gd           ← UI + Koios reads + submit flow + polling
│       └── offline_data.gd   ← offline dev data (OFFLINE_MODE, separated)
└── backend/
    ├── package.json
    └── src/
        ├── server.js         ← Express bridge API
        ├── cardano.js        ← Mesh SDK wallet / build / sign / submit
        ├── config.js         ← env + network mapping
        └── scripts/
            ├── gen-wallet.js ← generate a fresh testnet wallet
            └── fund-wallet.js← show addresses + balance + faucet guidance
```

---

## Prerequisites (clean machine)

- **Godot 4.x** — https://godotengine.org/download (any 4.x; GL Compatibility renderer)
- **Node.js 18+** — https://nodejs.org (tested with Node 20)

No Cardano node, cardano-cli, or Docker required.

---

## Setup

### 1. Clone & install backend

```bash
git clone https://github.com/dmt041104111003/lab3-godot-cardano-testnet.git
cd lab3-godot-cardano-testnet/backend
npm install
```

### 2. Configure environment

```bash
cp ../.env.example ../.env
```

Edit `../.env` (this file is **gitignored**, never commit it):

```dotenv
NETWORK=preprod
PORT=8787
PROVIDER=koios            # or blockfrost (needs BLOCKFROST_API_KEY)
# BLOCKFROST_API_KEY=preprodXXXX
MNEMONIC=<24-word testnet mnemonic>
```

- `PROVIDER=koios` works with **no API key** (public Koios).
- `PROVIDER=blockfrost` uses a free Preprod project id
  (https://blockfrost.io → create a **Preprod** project). It is more reliable for
  submission.

### 3. Create a test wallet safely

```bash
cd backend
npm run key        # prints a fresh 24-word mnemonic + addresses
```

- Put the generated mnemonic in `.env` → `MNEMONIC=...`.
- **Never share or commit the mnemonic.** It only funds testnet tADA.
- To check an existing mnemonic's addresses: `npm run fund`.

### 4. Fund the test wallet (testnet faucet)

```bash
npm run fund       # shows payment + stake address and current balance
```

If the balance is 0, use the **official Cardano testnet faucet**:

1. Open https://docs.cardano.org/cardano-testnet/tools/faucet/
2. Choose **Preprod**.
3. Paste your **stake address** (`stake_test1…`, printed by `npm run fund`).
4. Request test ADA (tADA). ~2–3 blocks later it arrives.

### 5. Start the bridge

```bash
npm start          # → [bridge] listening on http://127.0.0.1:8787
```

Check it: `curl http://127.0.0.1:8787/health`

### 6. Run the Godot app

1. Open Godot → **Import** → select `godot/project.godot`.
2. Press **Play (F5)**.
3. Paste a testnet address (`addr_test1…`) into **Wallet address**.
4. Click **Refresh Cardano Data** → live balance appears.
5. Click **Complete Quest** → then **Submit Testnet Proof**.
6. Wait for the tx hash → **CONFIRMED (block height …)**.
7. Click **Open Explorer** to verify on-chain.

---

## Environment variables

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `NETWORK` | `preprod` | `preprod` or `preview` (testnet only) |
| `PORT` | `8787` | Bridge HTTP port |
| `PROVIDER` | `koios` | `koios` (no key) or `blockfrost` |
| `BLOCKFROST_API_KEY` | *(empty)* | Preprod Blockfrost project id |
| `MNEMONIC` | *(empty)* | 15/24-word testnet wallet mnemonic |
| `LAB3_BRIDGE_URL` | `http://127.0.0.1:8787` | Godot → bridge URL (OS env override) |
| `LAB3_KOIOS_URL` | `https://preprod.koios.rest/api/v1` | Godot read API (OS env override) |
| `LAB3_NETWORK` | `preprod` | Godot display network name |
| `LAB3_EXPLORER` | `https://preprod.cardanoscan.io/transaction` | Explorer base URL |
| `LAB3_QUEST_ID` | `demo_001` | Quest id written into metadata |

Godot reads its overrides from **OS environment variables** (set them before
launching Godot) — `.env` is consumed by the bridge only.

---

## Execute a real testnet transaction (exact steps)

1. Bridge running (`npm start` in `backend/`).
2. Godot app running, a funded testnet address pasted, balance visible.
3. **Complete Quest** → **Submit Testnet Proof**.
4. Godot calls `POST http://127.0.0.1:8787/api/quest/complete` with
   `{"questId":"demo_001","playerAddress":"addr_test1…"}`.
5. The bridge builds a tx with metadata label 674, signs it with the funded
   testnet wallet, and submits it to Preprod via Blockfrost/Koios.
6. The bridge returns the **tx hash**; Godot polls `POST /tx_info` (Koios) until
   the tx appears in a block.
7. Status flips to **CONFIRMED (block height …)**; **Open Explorer** shows the
   on-chain transaction and its metadata.

Verify independently:

```bash
curl -s -X POST https://preprod.koios.rest/api/v1/tx_info \
  -H "Content-Type: application/json" \
  -d '{"_tx_hashes":["30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162"]}'
```

---

## Security

- **Never commit:** seed phrases, private keys, API secrets.
- The mnemonic and Blockfrost key live only in gitignored `.env`.
- The bridge binds to `127.0.0.1` and is intended for local development.
- Godot never sees the mnemonic — it only talks to the local bridge.
- All activity is on Cardano **testnet** (Preprod/Preview) — testnet funds only.

## Offline development mode

For offline UI development, set `OFFLINE_MODE := true` at the top of
`godot/scripts/main.gd`. The app then uses `godot/scripts/offline_data.gd`
(clearly labeled `[OFFLINE]`) and never touches the live network. The live path
runs with `OFFLINE_MODE = false` and uses real, verified on-chain data.

## Web (browser) builds

Browser builds cannot call Koios directly (no CORS headers), so on web builds
Godot automatically routes reads through the CORS-enabled bridge
(`/api/tip`, `/api/address_info`, `/api/tx_info`). See
[docs/live-demo.md](docs/live-demo.md) for deployment.

---

## Docs

- [architecture.md](docs/architecture.md) — system design & data flow
- [testnet-validation.md](docs/testnet-validation.md) — real executed transactions
- [evidence.md](docs/evidence.md) — validation & evidence checklist
- [live-demo.md](docs/live-demo.md) — Godot Web export + GitHub Pages deployment
- [demo-video-script.md](docs/demo-video-script.md) — optional demo video script
- [trl5-evidence.md](docs/trl5-evidence.md) — ready-to-paste TRL5 wording

## License

MIT — see [LICENSE](LICENSE).