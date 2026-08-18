# Testnet Validation — REAL On-Chain Evidence

This page records the **real, executed** Cardano testnet transactions produced by
this prototype. No transaction hash on this page is fabricated.

**Status: ✅ VALIDATED on Cardano Preprod (2026-08-17).**

## Summary

- Network: **Preprod** (public Cardano testnet)
- Bridge wallet (payment): `addr_test1qp6el7vnjgr2gqd5m7dcz92uw5pwqaddpp520jgy3xvd9l4fg96w0twerwjcahs5djhttqgj5slgt9yd6xftgecum22qraq6v4`
- Bridge wallet (stake): `stake_test1uz55za884hv3hfvwmc2xet44syf2g059jjxary45vuwd49q5wyv5w`
- Metadata label: **674** — tag `LAB3_GODOT_CARDANO_TRL5_DEMO`
- Verified via: Blockfrost (submit + metadata) and Koios (tip + tx_info)

## Real transactions

### TX #1 — `quest_id: demo_001`

| Field | Value |
| ----- | ----- |
| Transaction hash | `30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162` |
| Explorer URL | https://preprod.cardanoscan.io/transaction/30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162 |
| Block | `5066198` (block hash `1a4ef0065c10f1244de998073666072b012350e77d08218d266176751fe91939`) |
| Slot | `131278066` |
| Timestamp | 2026-08-17 (block_time `1786961266`) |
| Fee | `179097` lovelace (0.179097 tADA) |
| Size | 538 bytes |
| Input(s) | `addr_test1qp6el…` — 10,000,000,000 lovelace |
| Output(s) | `addr_test1qp6el…` — 9,999,820,903 lovelace (change) |
| Metadata (label 674) | confirmed on-chain (see below) |

### TX #2 — `quest_id: demo_002` (independent repeat run)

| Field | Value |
| ----- | ----- |
| Transaction hash | `4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501` |
| Explorer URL | https://preprod.cardanoscan.io/transaction/4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501 |
| Block | `5066209` |
| Metadata (label 674) | confirmed on-chain |

### TX #3 — `quest_id: demo_003` (desktop bridge, repeat run)

| Field | Value |
| ----- | ----- |
| Transaction hash | `7b07014ddd39cd56abfaaefa8663c2dcde0b10a0930e0724ed937eb6364b4120` |
| Explorer URL | https://preprod.cardanoscan.io/transaction/7b07014ddd39cd56abfaaefa8663c2dcde0b10a0930e0724ed937eb6364b4120 |
| Metadata (label 674) | confirmed on-chain |

### TX #4 — `quest_id: demo_hosted_001` (HOSTED Vercel bridge, repeat run)

| Field | Value |
| ----- | ----- |
| Transaction hash | `73aa0613c47b890de10c51849322ae25afb78c718e9f2cc8b54eb18578b415c4` |
| Explorer URL | https://preprod.cardanoscan.io/transaction/73aa0613c47b890de10c51849322ae25afb78c718e9f2cc8b54eb18578b415c4 |
| Block | `5068791` (verified via Blockfrost) |
| Fee | `179405` lovelace |
| Metadata (label 674) | confirmed on-chain (tag `LAB3_GODOT_CARDANO_TRL5_DEMO`) |

> TX #4 proves the **hosted bridge** (`https://lab3-godot-cardano-bridge.vercel.app`)
> signs and submits real Preprod transactions — the same endpoint the browser
> web build uses.

### TX #5 — `quest_id: quest_001` (current code, hosted Vercel bridge)

| Field | Value |
| ----- | ----- |
| Transaction hash | `4fcd249e079df4487ba9bdca408fddcee7a08a6ea18fe767cd0a1d83e6a1008c` |
| Explorer URL | https://preprod.cardanoscan.io/transaction/4fcd249e079df4487ba9bdca408fddcee7a08a6ea18fe767cd0a1d83e6a1008c |
| Block | `5068907` (verified via Blockfrost) |
| Fee | `178833` lovelace |
| Metadata (label 674) | confirmed on-chain — tag `LAB3_GODOT_CARDANO_TESTNET`, project `LAB3 Godot Cardano Testnet`, quest_id `quest_001` |

> TX #5 was produced by the **current** code (new product naming) through the
> hosted bridge — identical to the flow a browser visitor performs.

> Five independent runs confirm the flow **repeats without failure**.

## Metadata verified on-chain (TX #1)

Queried from Blockfrost `GET /txs/{hash}/metadata`:

```json
{
  "label": "674",
  "json_metadata": {
    "tag": "LAB3_GODOT_CARDANO_TRL5_DEMO",
    "event": "quest_completed",
    "network": "preprod",
    "project": "LAB3 Godot Cardano Testnet Demo",
    "quest_id": "demo_001",
    "player_addr_a": "addr_test1qp6el7vnjgr2gqd5m7dcz92uw5pwqaddpp520jgy3xvd",
    "player_addr_b": "9l4fg96w0twerwjcahs5djhttqgj5slgt9yd6xftgecum22qraq6v4"
  }
}
```

Concatenating `player_addr_a + player_addr_b` reproduces the full bridge/player
address exactly.

## How to reproduce

1. Install Node.js 18+ and Godot 4.x.
2. Copy `.env.example` → `.env`, set `MNEMONIC` (funded testnet wallet) and,
   optionally, `BLOCKFROST_API_KEY` + `PROVIDER=blockfrost`.
3. `cd backend && npm install && npm start` (bridge on `http://127.0.0.1:8787`).
4. Open the Godot project (`godot/project.godot`), paste a testnet address in the
   **Wallet address** field, click **Refresh Cardano Data**.
5. Click **Complete Quest** (default quest id `quest_001`), then **Submit Testnet
   Proof**. A real Preprod transaction is built, signed, and submitted; the app
   polls until it is confirmed and shows the block height.
6. Click **Open Explorer** and verify the transaction + metadata (label 674) on-chain.

> New transactions produced by the current code use tag `LAB3_GODOT_CARDANO_TESTNET`
> and quest id `quest_001`. The TX #1–#4 records above were produced earlier with
> tag `LAB3_GODOT_CARDANO_TRL5_DEMO` and quest ids `demo_001`–`demo_003`/
> `demo_hosted_001` — they are documented verbatim because that is exactly what
> is written on-chain.

## Verify with a shell one-liner (read-only, no key)

```bash
# chain tip
curl -s https://preprod.koios.rest/api/v1/tip

# tx confirmation status
curl -s -X POST https://preprod.koios.rest/api/v1/tx_info \
  -H "Content-Type: application/json" \
  -d '{"_tx_hashes":["30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162"]}'

# metadata on-chain (Blockfrost; needs a free preprod project id)
curl -s https://cardano-preprod.blockfrost.io/api/v0/txs/30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162/metadata \
  -H "project_id: <your_preprod_key>"
```

## Tested with

- Node.js v20.20.2 (portable), `@meshsdk/core` (current), Express 4, Blockfrost preprod.
- Network traffic to `preprod.koios.rest` and `cardano-preprod.blockfrost.io`.