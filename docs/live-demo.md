# Deployment — GitHub Pages (web build) + Vercel (bridge)

This project runs in two parts, both already deployed for production:

| Part | Where | URL |
| ---- | ----- | --- |
| Godot web build | GitHub Pages (`gh-pages` branch) | `https://dmt041104111003.github.io/lab3-godot-cardano-testnet/` |
| Signing bridge | Vercel (production) | `https://lab3-godot-cardano-bridge.vercel.app` |

## Current state

- [x] Bridge deployed on Vercel with env vars:
      `NETWORK=preprod`, `PROVIDER=blockfrost`, `BLOCKFROST_API_KEY`, `MNEMONIC`.
- [x] Real Preprod transactions submitted through the hosted bridge
      (see [testnet-validation.md](testnet-validation.md), TX #4).
- [ ] Enable GitHub Pages: `Settings → Pages → Deploy from a branch →
      gh-pages → / (root) → Save`.

## How the browser build talks to Cardano

- **Reads:** the web build reads live Preprod data directly from **Blockfrost**
  (CORS-enabled, public Preprod key embedded in the build).
- **Submissions:** `POST /api/quest/complete` goes to the hosted bridge, which
  signs with the testnet wallet (mnemonic only in Vercel env vars) and submits
  on-chain. Visitors need zero local setup.
- Godot detects the browser via `OS.has_feature("web")` and switches the bridge
  URL automatically. Desktop builds read from Koios and submit to
  `http://127.0.0.1:8787` or the hosted bridge.

## Quick check (no setup)

```bash
curl https://lab3-godot-cardano-bridge.vercel.app/health
curl https://lab3-godot-cardano-bridge.vercel.app/api/tip
```

## Redeploying the bridge (if you change the backend)

```bash
cd backend
vercel link --yes --project lab3-godot-cardano-bridge   # once
vercel env add NETWORK production                       # as needed
vercel env add PROVIDER production
vercel env add BLOCKFROST_API_KEY production
vercel env add MNEMONIC production
vercel deploy --prod --yes
```

## Rebuilding + redeploying the web build

1. Open `godot/project.godot` in Godot 4.x (install the Web export templates:
   `Editor → Manage Export Templates`).
2. `Project → Export…` → preset **Web** → Export to `godot/build/web/index.html`.
3. Commit `godot/build/web/` on `master`, then rebuild the `gh-pages` branch with
   only those files and force-push:

```bash
git checkout gh-pages
git rm -rf .
cp godot/build/web/* .
git add -A && git commit -m "Update web build"
git push -f origin gh-pages
git checkout master
```

> Keep the `gh-pages` branch limited to the web build files. The branch has a
> `.gitignore` that blocks `.env` and `node_modules` from ever being committed.

## Verification checklist (real test on Preprod)

- [ ] Open the GitHub Pages URL in a browser — network row shows `preprod` + a live tip height.
- [ ] Paste the bridge wallet address → non-zero tADA balance from Preprod.
- [ ] **Complete Quest** → **Submit Testnet Proof** → a real tx hash is returned.
- [ ] Status flips to **CONFIRMED (block height …)** and the explorer link opens.
- [ ] The hash is findable on `preprod.cardanoscan.io` with metadata label 674.
- [ ] Record every fresh transaction in [testnet-validation.md](testnet-validation.md)
      so the evidence always reflects a real, recent interaction.