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