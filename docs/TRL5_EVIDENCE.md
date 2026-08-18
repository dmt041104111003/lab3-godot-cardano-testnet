# TRL5 Evidence

## Claim

The **existing product** (LAB3 Godot × Cardano Game) is at **TRL 5 — technology
validated in a relevant environment** (public Cardano **Preprod** testnet).

## What is validated

- A playable Godot 4 game runs in a realistic environment (public web build and
  desktop), and a full **gameplay → milestone → Cardano transaction → on-chain
  confirmation → verified achievement** flow works end-to-end on Cardano Preprod.
- Transactions are real, submitted by the hosted bridge, and confirmed on-chain
  (explorer-verifiable, no fabricated hashes).

## Evidence

| Item | Value |
| ---- | ----- |
| Repository | https://github.com/dmt041104111003/lab3-godot-cardano-testnet |
| Live web build | https://dmt041104111003.github.io/lab3-godot-cardano-testnet/ |
| Bridge | https://lab3-godot-cardano-bridge.vercel.app |
| Network | Cardano Preprod |
| Confirmed transactions | see [docs/evidence/README.md](evidence/README.md) |
| Example explorer link | https://preprod.cardanoscan.io/transaction/34f6b17f77041da3e51d674de19b8727465f5376c8b9d908b46b3793c4ac2e80 |

## Honest boundaries

- This validates the product on a **public testnet** (relevant environment).
  It is **not** on mainnet and does not claim production history, real users, or
  sustained volume.
- **CIP-0170** is the **new integration** the Catalyst Pilot funds. A working
  attestation layer is tested on Preprod, but full CIP-0170 compliance and
  mainnet deployment are the Pilot's scope — not claimed as complete.
