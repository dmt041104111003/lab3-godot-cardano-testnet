# Tester Guide

Thank you for testing **LAB3 Godot Ã— Cardano Game**. This takes ~5 minutes and
produces a real Cardano Preprod transaction.

## Steps

1. **Open the game** â€” https://dmt041104111003.github.io/lab3-godot-cardano-testnet/
   (best in Chrome/Edge; keep a CIP-30 wallet like Eternl handy if you want to try
   wallet signing).
2. **Start** â€” click **Play**.
3. **Player Profile** â€” set a name and paste a Cardano **Preprod** address
   (`addr_test1...`) if you have one. You can also play without one.
4. **Play the quests**:
   - Quest 1: collect **5 coins** (move ←/→, jump Space/↑).
   - Quest 2: activate **2 terminals**.
   - Quest 3: reach the **exit**.
5. **Cardano verification** â€” when you complete a quest, the game shows a
   **transaction hash** and confirms it **Verified on Cardano**.
6. **Save your tx link** â€” copy the transaction hash and open
   `https://preprod.cardanoscan.io/transaction/<hash>` to verify on-chain.
7. **Feedback** â€” reply with:
   - device/browser
   - how it went (worked / issues)
   - the transaction hash(es) you saw
   - anything that was confusing

Results are recorded honestly in `docs/EXTERNAL_TESTING.md` (never fabricated).

