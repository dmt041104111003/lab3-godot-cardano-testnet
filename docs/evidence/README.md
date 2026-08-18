# Evidence Bundle

## Live product

- **Live web build:** https://dmt041104111003.github.io/lab3-godot-cardano-testnet/
- **Repository:** https://github.com/dmt041104111003/lab3-godot-cardano-testnet
- **Bridge (Vercel):** https://lab3-godot-cardano-bridge.vercel.app

## Current commit

_Update after each release._ Latest tag: `v1.2.0` (see git tags; current commit
reported at the end of the deployment pipeline).

## Architecture

See [docs/architecture.md](../architecture.md) and the Mermaid diagram in the
[README](../../README.md). Flow:

```
Player → Godot gameplay → milestone validation (bridge) → CIP-0170 attestation
→ Cardano Preprod transaction → on-chain confirmation → verified achievement
```

## Screenshots

_Place screenshots in `docs/evidence/screenshots/` and link them here._

- Main menu
- Game level (quest 1)
- Quest complete / verification panel
- Achievements screen

## Test matrix

| # | Flow | Result | Evidence |
| - | ---- | ------ | -------- |
| 1 | Godot → bridge proof tx (label 674) | ✅ | see transactions |
| 2 | Attestation create (label 1701) | ✅ | see transactions |
| 3 | Attestation update (version+1) | ✅ | `f1bb626b31b98db84dcd95fdc969c3e8d2f8d13b6ccbeb37833b70b81f33b338` |
| 4 | Verification (`verified: true`) | ✅ | create/update verify returned true |
| 5 | CIP-30 player-signed attestation | ✅ | `e2f8d274f2030b199c604208404ec699e74f9e06aabe3ce007209ce8ebe5cf49` |
| 6 | Gameplay-triggered quest flow (3 quests) | ✅ | see transactions below |

## Preprod transactions (real)

Open any hash at `https://preprod.cardanoscan.io/transaction/<hash>`.

| Step | Tx hash |
| ---- | ------- |
| quest_1 proof (674) | `34f6b17f77041da3e51d674de19b8727465f5376c8b9d908b46b3793c4ac2e80` |
| quest_1 attestation (1701) | `0c00567a45b62d289915af29facc65429e4d0d9f1acd39edbd03cd9921623fc9` |
| quest_2 attestation (1701) | `99755b126d276f20eed57191882b02d7de163364a7a8822cd5924bcfc343451f` |
| quest_3 proof (674) | `20a497f1cba6152aeabb8ef82a51ad3a6823062e9329a3fdb484f42fc5620d19` |
| quest_3 attestation (1701) | `815925ee36b4e22ccdfe10a7f102d96081ed26657616d49d0f72730e2b07db4e` |
| baseline TX #1 | `30219e447faf3a89784c73f27916ee15882bdd7575478152a0d01500173e8162` |
| baseline TX #2 | `4a4b87a9e9b398526308c2c7ba239d0e185f0857bd22935dfae5e6d5bb00e501` |
| CIP-0170 create v1 | `cff3a0ea4e6fd13cf926c9c16b2072726d64871fa948206aedbae93337d85873` |
| CIP-0170 update v2 | `f1bb626b31b98db84dcd95fdc969c3e8d2f8d13b6ccbeb37833b70b81f33b338` |
| CIP-30 player-signed | `e2f8d274f2030b199c604208404ec699e74f9e06aabe3ce007209ce8ebe5cf49` |

## Exact flow that produced each transaction

```
Player completes quest milestone (gameplay)
 → game calls POST /api/quest/complete {questId, playerAddress}   [proof, label 674]
 → bridge builds+signs+submits → returns txHash
 → game polls /api/tx/{hash} until confirmed
 → game calls POST /api/attestation/prepare → attestationHash
 → game calls POST /api/attestation/create [label 1701, CIP-0170]
   (player wallet signs first when CIP-30 connected)
 → polls attestation tx → verified ✓
```

## Known limitations

- CIP-0170 is implemented as an attestation layer (W3C VC + KERI-style AID +
  CIP-8 signature + on-chain anchor). Full CIP-0170 compliance (did:cardano,
  on-chain status registry / MPT) is **planned Pilot work**, not claimed done.
- Network is **Preprod**; mainnet deployment is the Pilot Milestone 1 target.
- Local profile persistence uses the browser's `user://` storage.
- CIP-30 wallet signing requires a CIP-30 extension in the browser.
