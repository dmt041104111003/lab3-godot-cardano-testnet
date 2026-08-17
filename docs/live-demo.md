# Live Demo — Web Deployment

The best way for anyone (curators, developers) to verify this project is the
**trio**:

1. **GitHub repo** — full source, docs, and evidence.
   https://github.com/dmt041104111003/lab3-godot-cardano-testnet
2. **Live demo (web)** — a browser playable build of the Godot app (HTML5 export)
   deployed on GitHub Pages / Netlify / Vercel.
3. **Public testnet transaction** — a Cardanoscan Preprod/Preprod link proving the
   on-chain interaction is real.

> The explorer link is the most important proof. The live demo lets a reviewer
> open the app directly and test it themselves.

## Current status

- [x] Godot web build committed to the **`gh-pages` branch** (root).
- [x] `master` branch contains the full source + docs + evidence.
- [ ] **One manual step:** enable GitHub Pages on the repo:
      `Settings → Pages → Deploy from a branch → branch: gh-pages → / (root) → Save`.
      URL will be: `https://dmt041104111003.github.io/lab3-godot-cardano-testnet/`
- [ ] *(optional)* Deploy the bridge so the browser demo can also submit
      transactions (see Step 2 below). Without it, the web demo shows live
      reads; submission needs the desktop app or a hosted bridge.

## What the browser build can do

The web build reads live Preprod data directly from **Blockfrost** (CORS-enabled,
using a public Preprod demo key embedded in the build) — no hosted backend needed
for balance/network/tx-status. Submissions are sent to the bridge URL; on the
static demo that shows a clear "bridge unreachable" message until a hosted bridge
is deployed.

## How the web build talks to Cardano

Browser builds cannot call Koios directly (Koios sends no
`Access-Control-Allow-Origin` header), so the web build routes **all reads and
submissions** through the CORS-enabled bridge:

```
Godot Web (browser)  ──►  hosted bridge (CORS)  ──►  Cardano Preprod
   GET  /api/tip            (Node.js + Mesh SDK)
   POST /api/address_info       │ reads  → Koios
   POST /api/tx_info            │ submit → Blockfrost/Koios
   POST /api/quest/complete
```

Godot detects the web build automatically (`OS.has_feature("web")`) and switches
the read URLs to the bridge endpoints (`/api/tip`, `/api/address_info`,
`/api/tx_info`). Desktop builds keep talking to Koios directly.

## Step 1 — Export the Godot project for Web

1. Install Godot 4.x and open `godot/project.godot`.
2. Install the **Web export templates**: Editor → `Editor > Manage Export Templates`
   → download/install the templates for your Godot version.
3. `Project > Export…` → the `Web` preset (from `godot/export_presets.cfg`)
   should be listed. If not, click **Add** → **Web**.
4. Set **Export Path** to `build/web/index.html`.
5. Click **Export Project** → produces `build/web/` (`index.html`, `index.js`,
   `index.wasm`, `*.pck`).

## Step 2 — Host the bridge publicly

The demo needs a reachable bridge. Example: **Render.com** free tier.

1. Push the `backend/` folder to a new repo (or the same repo root).
2. Create a new **Web Service** on Render → pick the repo, root = `backend/`.
3. Build command: `npm install`
   Start command: `node src/server.js`
4. Add environment variables:
   - `NETWORK=preprod`
   - `PROVIDER=blockfrost`
   - `BLOCKFROST_API_KEY=<preprod key>`
   - `MNEMONIC=<demo wallet mnemonic>`
   - `PORT=10000`
5. Render gives you a public URL, e.g. `https://lab3-bridge.onrender.com`.
   > Use a **dedicated demo wallet** funded only with tADA. The mnemonic on a
   > hosted service is exposed to whoever controls that service — never reuse a
   > wallet you care about, and never use mainnet funds.

## Step 3 — Deploy the web build

### GitHub Pages

1. In the repo: `Settings → Pages → Source → GitHub Actions`.
2. Create `.github/workflows/deploy-web.yml`:

```yaml
name: Deploy Godot Web
on:
  push:
    branches: [main]
  workflow_dispatch:
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy static build
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./godot/build/web
```

3. Add the built `godot/build/web/` files to the repo (or build them in CI and
   adjust the workflow).

### Netlify / Vercel (alternative)

- Netlify: drag-and-drop the `godot/build/web/` folder to
  https://app.netlify.com/drop → instant URL.
- Vercel: `vercel deploy --prod` pointing at `godot/build/web/`.

## Step 4 — Point Godot at the hosted bridge

In `godot/scripts/main.gd`, set the bridge URL (or provide it at runtime via the
`LAB3_BRIDGE_URL` OS environment variable):

```gdscript
const BRIDGE_URL_DEFAULT := "https://lab3-bridge.onrender.com"
```

Rebuild the web export and redeploy. Desktop builds can keep
`http://127.0.0.1:8787` for local use.

## Verification checklist for the live demo

- [ ] Live URL loads in a normal browser (no console CORS errors).
- [ ] Network row shows `preprod` and a live tip height.
- [ ] Pasting the demo wallet address shows a non-zero tADA balance.
- [ ] Complete Quest → Submit Testnet Proof returns a real tx hash.
- [ ] Status flips to **CONFIRMED (block height …)** and the explorer link opens.

## Keep the evidence consistent

Whenever you demonstrate the live demo, submit a fresh transaction and record it
in [docs/testnet-validation.md](testnet-validation.md) and
[docs/evidence.md](evidence.md) so the explorer link always reflects a real,
recent interaction.