import pg from 'pg';

const raw = process.env.DATABASE_URL || '';
let pool = null;

export function isEnabled() {
  return raw.length > 0;
}

function getPool() {
  if (pool) return pool;
  const url = new URL(raw);
  // libpq-specific params the node driver treats differently / ignores.
  url.searchParams.delete('channel_binding');
  if (!url.searchParams.has('sslmode')) url.searchParams.set('sslmode', 'require');
  pool = new pg.Pool({ connectionString: url.toString() });
  pool.on('error', (err) => console.error('[storage] pool error:', err.message));
  return pool;
}

export async function ensureSchema() {
  if (!isEnabled()) return;
  const client = await getPool().connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS players (
        address TEXT PRIMARY KEY,
        data JSONB NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await client.query(`
      CREATE TABLE IF NOT EXISTS presence (
        address TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        x REAL NOT NULL DEFAULT 0,
        y REAL NOT NULL DEFAULT 0,
        level INT NOT NULL DEFAULT 1,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await client.query(`ALTER TABLE presence ADD COLUMN IF NOT EXISTS state TEXT NOT NULL DEFAULT 'idle'`);
    await client.query(`ALTER TABLE presence ADD COLUMN IF NOT EXISTS facing_x REAL NOT NULL DEFAULT 0`);
    await client.query(`ALTER TABLE presence ADD COLUMN IF NOT EXISTS facing_y REAL NOT NULL DEFAULT 1`);
    await client.query(`ALTER TABLE presence ADD COLUMN IF NOT EXISTS hp INT NOT NULL DEFAULT 100`);
    await client.query(`
      CREATE TABLE IF NOT EXISTS chat (
        id BIGSERIAL PRIMARY KEY,
        sender TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
  } finally {
    client.release();
  }
}

export async function savePresence({ address, name, x, y, level, state, facing_x, facing_y, hp }) {
  if (!isEnabled()) return { stored: false, reason: 'database not configured' };
  await ensureSchema();
  const client = await getPool().connect();
  try {
    await client.query(
      `INSERT INTO presence (address, name, x, y, level, state, facing_x, facing_y, hp, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
       ON CONFLICT (address) DO UPDATE SET name = EXCLUDED.name, x = EXCLUDED.x, y = EXCLUDED.y, level = EXCLUDED.level, state = EXCLUDED.state, facing_x = EXCLUDED.facing_x, facing_y = EXCLUDED.facing_y, hp = EXCLUDED.hp, updated_at = now()`,
      [address, name, x, y, level, state, facing_x, facing_y, hp],
    );
    return { stored: true };
  } finally {
    client.release();
  }
}

export async function getPresence(withinSeconds = 20) {
  if (!isEnabled()) return [];
  await ensureSchema();
  const client = await getPool().connect();
  try {
    const r = await client.query(
      `SELECT address, name, x, y, level, state, facing_x, facing_y, hp FROM presence WHERE updated_at > now() - make_interval(secs => $1)`,
      [withinSeconds],
    );
    return r.rows;
  } finally {
    client.release();
  }
}

export async function addChatMessage(sender, text) {
  if (!isEnabled()) return { stored: false, reason: 'database not configured' };
  await ensureSchema();
  const client = await getPool().connect();
  try {
    await client.query(
      `INSERT INTO chat (sender, text) VALUES ($1, $2)`,
      [sender, text],
    );
    return { stored: true };
  } finally {
    client.release();
  }
}

export async function getChatMessages(limit = 40) {
  if (!isEnabled()) return [];
  await ensureSchema();
  const client = await getPool().connect();
  try {
    const r = await client.query(
      `SELECT sender, text, created_at FROM chat ORDER BY id DESC LIMIT $1`,
      [limit],
    );
    return r.rows.reverse();
  } finally {
    client.release();
  }
}

export async function savePlayer(address, data) {
  if (!isEnabled()) return { stored: false, reason: 'database not configured' };
  await ensureSchema();
  const client = await getPool().connect();
  try {
    await client.query(
      `INSERT INTO players (address, data, updated_at)
       VALUES ($1, $2, now())
       ON CONFLICT (address) DO UPDATE SET data = EXCLUDED.data, updated_at = now()`,
      [address, JSON.stringify(data)],
    );
    return { stored: true };
  } finally {
    client.release();
  }
}

export async function loadPlayer(address) {
  if (!isEnabled()) return null;
  await ensureSchema();
  const client = await getPool().connect();
  try {
    const r = await client.query(`SELECT data FROM players WHERE address = $1`, [address]);
    return r.rows.length ? r.rows[0].data : null;
  } finally {
    client.release();
  }
}
