# Demo Video Script (60–90 seconds)

Title: **LAB3 Godot × Cardano Testnet Demo — real Preprod transaction**

## Scene-by-scene

### 1. GitHub repo (0–10 s)
- Open `https://github.com/dmt041104111003/lab3-godot-cardano-testnet`
- Scroll the README: show "What this prototype proves", architecture, setup steps.
- Narration: "This is a Godot 4 game prototype that talks to a real Cardano
  testnet. The repository contains the full source, docs and evidence."

### 2. Godot project running (10–22 s)
- Open Godot, import `godot/project.godot`, press Play.
- Show the UI: player profile, network status, balance, quest, proof panel, log.
- Narration: "The game UI is built in Godot 4. It queries the public Koios API
  for live Cardano Preprod data."

### 3. Network = Preprod (22–28 s)
- Point at the **Network** row showing `preprod` and a live tip height.
- Narration: "We are on Cardano Preprod, the public testnet. All data is live."

### 4. Live balance / UTxO lookup (28–38 s)
- Paste the bridge testnet address into **Wallet address**.
- Click **Refresh Cardano Data** → balance appears in tADA.
- Narration: "Paste any testnet address — the app fetches the real balance and
  UTxOs straight from the chain."

### 5. Complete Quest action (38–46 s)
- Click **Complete Quest** → status becomes "Completed".
- Narration: "Complete a simple gameplay milestone. This unlocks the proof step."

### 6. Submit testnet transaction (46–58 s)
- Click **Submit Testnet Proof**.
- Show the bridge console (`npm start`) logging the request.
- Narration: "Godot asks the local signing bridge to build and sign a real
  Preprod transaction containing our quest metadata. No keys leave the bridge."

### 7. Transaction hash appears in Godot (58–68 s)
- The hash appears in the **Transaction hash** row; status shows pending.
- Narration: "The bridge returns the transaction hash and Godot starts polling
  the chain for confirmation."

### 8. Open explorer (68–80 s)
- Click **Open Explorer** → `preprod.cardanoscan.io` opens the transaction.
- Show the confirmed transaction, the 674 metadata, and the change output.
- Narration: "Here is the confirmed transaction on the public explorer. The
  metadata under label 674 contains our project tag and quest data."

### 9. Confirmed transaction (80–90 s)
- Back in Godot, status shows **CONFIRMED (block height …)**.
- Narration: "Confirmed on-chain. Godot read real Cardano data, triggered a real
  testnet transaction, and verified its confirmation — a working Godot × Cardano
  product baseline."

## Recording tips
- Use 1080p, 60 fps, normal UI zoom, no sensitive `.env` content on screen.
- Do NOT show the mnemonic or `.env` file contents.
- Keep the bridge console visible in a corner window to prove every value is
  fetched live from the real chain.