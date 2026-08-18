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

| # | Transaction hash | Origin | Explorer |
| - | ---------------- | ------ | -------- |
| 1 | `30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162` | desktop bridge | https://preprod.cardanoscan.io/transaction/30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162 |
| 2 | `4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501` | desktop bridge | https://preprod.cardanoscan.io/transaction/4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501 |
| 3 | `7b07014ddd39cd56abfaaefa8663c2dcde0b10a0930e0724ed937eb6364b4120` | desktop bridge | https://preprod.cardanoscan.io/transaction/7b07014ddd39cd56abfaaefa8663c2dcde0b10a0930e0724ed937eb6364b4120 |
| 4 | `73aa0613c47b890de10c51849322ae25afb78c718e9f2cc8b54eb18578b415c4` | **hosted Vercel bridge** | https://preprod.cardanoscan.io/transaction/73aa0613c47b890de10c51849322ae25afb78c718e9f2cc8b54eb18578b415c4 |

Full details (block heights, fees, inputs/outputs, metadata) are in
[docs/testnet-validation.md](testnet-validation.md).

## Review checklist

| # | Item | Status | Link / value |
| - | ---- | ------ | ------------ |
| 1 | Repository URL | ✅ | `https://github.com/dmt041104111003/lab3-godot-cardano-testnet` |
| 2 | Tagged release / commit | ⏳ | add a `v1.0.0` tag and record the commit hash |
| 3 | Cardano network | ✅ | **Preprod** |
| 4 | Transaction #1 hash | ✅ | `30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162` |
| 5 | Transaction #2 hash | ✅ | `4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501` |
| 6 | Transaction #3 hash | ✅ | `7b07014ddd39cd56abfaaefa8663c2dcde0b10a0930e0724ed937eb6364b4120` |
| 7 | Transaction #4 hash (hosted bridge) | ✅ | `73aa0613c47b890de10c51849322ae25afb78c718e9f2cc8b54eb18578b415c4` |
| 8 | Hosted bridge URL | ✅ | `https://lab3-godot-cardano-bridge.vercel.app` |
| 9 | Date tested | ✅ | 2026-08-17 (baseline) / 2026-08-18 (CIP-0170) |
| 10 | Exact gameplay flow | ✅ | below |
| 11 | CIP-0170 create v1 | ✅ | `cff3a0ea4e6fd13cf926c9c16b2072726d64871fa948206aedbae93337d85873` (block 5069691) |
| 12 | CIP-0170 update v2 | ✅ | `f1bb626b31b98db84dcd95fdc969c3e8d2f8d13b6ccbeb37833b70b81f33b338` (block 5069692) |
| 13 | CIP-0170 hosted-bridge create | ✅ | `359f1a6034aefe1353a31d8a31f17305bc4595d3bb56216344320a061e63c321` |
| 14 | CIP-0170 verification | ✅ | `verified: true` (hash match + CIP-8 signature) |

## Exact gameplay flow (as executed)

```
Godot launch
  → queries Cardano (GET /api/v1/tip, POST /api/v1/address_info)      [live data]
  → user pastes testnet address, balance shown in tADA                [live data]
  → Complete Quest (quest_001)                                       [in-app]
  → Submit Testnet Proof → POST bridge /api/quest/complete            [sign + submit]
  → receive tx hash in Godot                                          [real hash]
  → poll POST /api/v1/tx_info until block height appears              [live chain]
  → CONFIRMED (block height) shown in Godot, Open Explorer            [live chain]
```

## Integrity statement

- Every value in the app is fetched live from the Cardano Preprod network (Koios,
  Blockfrost, or the hosted bridge) — there is no simulated or local-only path in
  the shipped code.
- All four transaction hashes in this document were produced by real
  wallet-signed submissions and confirmed in Preprod blocks — none are
  fabricated.
- The Blockfrost API key and wallet mnemonic used are testnet-only and are not
  committed to the repository (local `.env` is gitignored; production secrets
  live in Vercel env vars).