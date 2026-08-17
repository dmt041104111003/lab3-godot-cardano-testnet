# Validation & Evidence

Everything needed to verify that this prototype really works — the live chain
checks, the executed transactions, and the checklist for independent review.

## What was validated

- A functional Godot 4 application that reads live Cardano Preprod data
  (tip height, address balance) from the public Koios API.
- A real testnet transaction initiated from the Godot gameplay flow, signed by a
  funded testnet wallet through the local bridge, submitted on-chain, and
  confirmed in a block.
- The submitted transaction carries verifiable metadata under **label 674**.

> This prototype does not yet implement CIP-0170. CIP-0170 is the next
> integration step that will build on this validated Godot × Cardano baseline.

## Live chain checks (independent, read-only)

```bash
# 1. Chain tip
curl -s https://preprod.koios.rest/api/v1/tip

# 2. Address balance
curl -s -X POST https://preprod.koios.rest/api/v1/address_info \
  -H "Content-Type: application/json" \
  -d '{"_addresses":["addr_test1qp6el7vnjgr2gqd5m7dcz92uw5pwqaddpp520jgy3xvd9l4fg96w0twerwjcahs5djhttqgj5slgt9yd6xftgecum22qraq6v4"]}'

# 3. Transaction confirmation status
curl -s -X POST https://preprod.koios.rest/api/v1/tx_info \
  -H "Content-Type: application/json" \
  -d '{"_tx_hashes":["30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162"]}'
```

## Executed transactions (Preprod, 2026-08-17)

| # | Transaction hash | Explorer |
| - | ---------------- | -------- |
| 1 | `30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162` | https://preprod.cardanoscan.io/transaction/30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162 |
| 2 | `4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501` | https://preprod.cardanoscan.io/transaction/4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501 |

Full details (block heights, fees, inputs/outputs, metadata) are in
[docs/testnet-validation.md](testnet-validation.md).

## Review checklist

| # | Item | Status | Link / value |
| - | ---- | ------ | ------------ |
| 1 | Repository URL | ✅ | `https://github.com/dmt041104111003/lab3-godot-cardano-testnet` |
| 2 | Tagged release / commit | ⏳ | add a `v1.0.0` tag and record the commit hash |
| 3 | Godot screenshots | ⏳ | add to `docs/screenshots/` and link |
| 4 | Demo video URL | ⏳ | record per `docs/demo-video-script.md` |
| 5 | Cardano network | ✅ | **Preprod** |
| 6 | Transaction #1 hash | ✅ | `30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162` |
| 7 | Transaction #2 hash | ✅ | `4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501` |
| 8 | Explorer link #1 | ✅ | https://preprod.cardanoscan.io/transaction/30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162 |
| 9 | Explorer link #2 | ✅ | https://preprod.cardanoscan.io/transaction/4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501 |
| 10 | Date tested | ✅ | 2026-08-17 |
| 11 | Exact gameplay flow | ✅ | below |

## Exact gameplay flow (as executed)

```
Godot launch
  → queries Cardano (GET /api/v1/tip, POST /api/v1/address_info)      [live data]
  → user pastes testnet address, balance shown in tADA                [live data]
  → Complete Quest (demo_001 / demo_002)                              [in-app]
  → Submit Testnet Proof → POST bridge /api/quest/complete            [sign + submit]
  → receive tx hash in Godot                                          [real hash]
  → poll POST /api/v1/tx_info until block height appears              [live chain]
  → CONFIRMED (block height) shown in Godot, Open Explorer            [live chain]
```

## Integrity statement

- The live path (`OFFLINE_MODE=false`) uses only real Cardano network responses.
- Both transaction hashes above were produced by real wallet-signed submissions
  and confirmed in Preprod blocks — none are fabricated.
- The Blockfrost API key and wallet mnemonic used are testnet-only and are not
  committed to the repository (they live in the gitignored `.env`).