import { app } from './app.js';
import { config } from './config.js';

// Local development server. On Vercel the app is served by api/index.js instead.
app.listen(config.port, () => {
  console.log(`[bridge] LAB3 Godot x Cardano bridge listening on http://127.0.0.1:${config.port}`);
  console.log(`[bridge] network=${config.network} provider=${config.provider}`);
});