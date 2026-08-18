import { AppWallet, MeshTxBuilder } from '@meshsdk/core';
import { checkSignature, getPublicKeyFromCoseKey, blake2b } from '@meshsdk/core-cst';
import { config } from './config.js';
import { createWallet, createProvider, koiosJson } from './cardano.js';

// ---------------------------------------------------------------------------
// CIP-0170 — On-chain identity & attestation layer
//
// State separation (as required):
//   1. Normal off-chain game state     -> this module's in-memory profile map
//   2. CIP-0170 identity/attestation   -> signed W3C-style Verifiable Credential
//   3. Cardano transaction evidence    -> on-chain metadata label 1701 (source of truth)
//
// Issuer identity is a KERI-style Self-Addressing Identifier (SAID):
//   E + base64url( blake2b-256( domain || issuer_public_key ) )
// Attestations are signed by the issuer with a CIP-8 Ed25519 signature.
// ---------------------------------------------------------------------------

const ISSUER_DOMAIN = 'LAB3:CIP0170';
const ANCHOR_LABEL = '1701'; // CIP-0170 attestation anchoring label
const PILOT_LABEL = '674'; // Catalyst pilot message-tag label
const PILOT_TAG = 'LAB3_GODOT_CARDANO_TESTNET';

// Off-chain identity/attestation state (per process; on-chain is the source of truth).
const profiles = new Map(); // playerAddress -> { playerName, registeredAt }
const attestations = new Map(); // `${address}|${achievement}` -> { version, status, txHash, attestation, signature, key, anchor }

function bytesFromHex(hex) {
  return Uint8Array.from(Buffer.from(hex, 'hex'));
}

function chunkHex(str, size = 54) {
  const out = [];
  for (let i = 0; i < str.length; i += size) out.push(str.slice(i, i + size));
  return out;
}

function joinChunks(value) {
  if (Array.isArray(value)) return value.join('');
  return value || '';
}

function bytesFromUtf8(str) {
  return new TextEncoder().encode(str);
}

function stableStringify(value) {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    const keys = Object.keys(value).sort();
    return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(value[k])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function computeKeriAid(pubkeyHex) {
  const digest = blake2b.hash(
    Uint8Array.from(Buffer.concat([Buffer.from(ISSUER_DOMAIN), Buffer.from(pubkeyHex, 'hex')])),
    32,
  );
  return `E${Buffer.from(digest, 'hex').toString('base64url')}`;
}

async function getIssuer() {
  const wallet = await createWallet();
  const address = wallet.getPaymentAddress();
  const { key } = await wallet.signData(address, bytesFromUtf8(ISSUER_DOMAIN).toString('hex'));
  const pubkeyHex = Buffer.from(getPublicKeyFromCoseKey(key)).toString('hex');
  return { wallet, address, pubkeyHex, aid: computeKeriAid(pubkeyHex) };
}

// ---------------------------------------------------------------------------
// 1. Player identity (off-chain game state + wallet link)
// ---------------------------------------------------------------------------
export function registerPlayer({ playerAddress, playerName }) {
  if (!playerAddress || !/^addr_test1/.test(playerAddress)) {
    throw new Error('registerPlayer: a valid testnet address (addr_test1...) is required');
  }
  const profile = {
    playerAddress,
    playerName: playerName || 'Player',
    registeredAt: new Date().toISOString(),
  };
  profiles.set(playerAddress, profile);
  return { ok: true, profile, issuerAid: null, note: 'profile linked to Cardano wallet (off-chain state)' };
}

// ---------------------------------------------------------------------------
// 2. Attestation creation / update + on-chain anchor
// ---------------------------------------------------------------------------
function buildAttestation({ issuer, subject, playerName, achievement, event, questId, tier, progression, version, status }) {
  const vc = {
    '@context': ['https://www.w3.org/2018/credentials/v1'],
    id: `did:cardano:${subject}#${achievement}-v${version}`,
    type: ['VerifiableCredential', 'GameAchievementAttestation'],
    issuer: issuer.aid,
    version,
    status,
    credentialSubject: {
      id: `did:cardano:${subject}`,
      playerName: playerName || 'Player',
      achievement,
      event: event || 'quest_completed',
      questId: questId || achievement,
      tier: tier || 1,
      progression: progression || 'achievement',
    },
  };
  const canonical = stableStringify(vc);
  const attestationHash = blake2b.hash(bytesFromUtf8(canonical), 32);
  return { vc, canonical, attestationHash };
}

async function anchorOnChain(wallet, provider, anchor, attempts = 4) {
  let lastErr = null;
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      const address = wallet.getPaymentAddress();
      const utxos = await provider.fetchAddressUTxOs(address);
      if (!utxos || utxos.length === 0) {
        throw new Error(`Bridge wallet has no UTxOs on ${config.network}. Fund it first.`);
      }
      const txBuilder = new MeshTxBuilder({ fetcher: provider, submitter: provider });
      const unsignedTxHex = await txBuilder
        .setNetwork(config.network)
        .metadataValue(PILOT_LABEL, {
          project: 'LAB3 Godot Cardano Testnet',
          event: 'cip0170_attestation',
          network: config.network,
          tag: PILOT_TAG,
        })
        .metadataValue(ANCHOR_LABEL, anchor)
        .changeAddress(address)
        .selectUtxosFrom(utxos)
        .complete();
      const signedTxHex = await wallet.signTx(unsignedTxHex);
      return await provider.submitTx(signedTxHex);
    } catch (err) {
      lastErr = err;
      const msg = typeof err === 'object' && err !== null ? JSON.stringify(err) : String(err);
      // Retry when the previous tx consumed the UTxO before this one landed
      // (e.g. rapid create -> update). Refetch and rebuild after a short wait.
      if (/spent|MissingInput|inputs?.*(spent|missing)/i.test(msg) && attempt < attempts - 1) {
        await new Promise((resolve) => setTimeout(resolve, 7000));
        continue;
      }
      throw err;
    }
  }
  throw lastErr;
}

async function attest({ playerAddress, playerName, achievement, event, questId, tier, progression, update, playerSignature, playerKey, playerAddressCip30 }) {
  const subject = playerAddress;
  if (!subject || !/^addr_test1/.test(subject)) {
    throw new Error('attest: a valid testnet address (addr_test1...) is required');
  }
  const issuer = await getIssuer();
  const provider = createProvider();

  const key = `${subject}|${achievement}`;
  const prev = attestations.get(key);
  const version = update && prev ? prev.version + 1 : 1;
  const status = version === 1 ? 'created' : 'updated';

  const { vc, canonical, attestationHash } = buildAttestation({
    issuer,
    subject,
    playerName,
    achievement,
    event,
    questId,
    tier,
    progression,
    version,
    status,
  });

  // Sign the canonical attestation hash with the issuer key (CIP-8 Ed25519).
  const { signature, key: sigKey } = await issuer.wallet.signData(issuer.address, attestationHash);

  // Optional CIP-30 player authorization: the player signs the SAME hash with
  // their own wallet. This is validated before anchoring (reject invalid).
  let playerAuth = null;
  if (playerSignature && playerKey) {
    const signingAddress = playerAddressCip30 || playerAddress;
    let valid = false;
    try {
      valid = await checkSignature(attestationHash, { key: playerKey, signature: playerSignature }, signingAddress);
    } catch (err) {
      throw new Error(`attest: invalid player signature (${err.message})`);
    }
    if (!valid) throw new Error('attest: player signature does not verify');
    playerAuth = { playerSignature, playerKey, playerAddress: signingAddress };
  }

  const anchor = {
    attestationHash,
    issuer: issuer.aid,
    // Cardano metadata strings are capped at 64 bytes, so long addresses are
    // split across a/b fields (concatenate to recover the full address).
    issuer_addr_a: issuer.address.slice(0, 54),
    issuer_addr_b: issuer.address.slice(54),
    subject_a: subject.slice(0, 54),
    subject_b: subject.slice(54),
    achievement,
    event: event || 'quest_completed',
    status,
    version,
    timestamp: new Date().toISOString(),
    tag: 'LAB3_CIP0170',
  };
  if (playerAuth) {
    anchor.player_addr_a = playerAuth.playerAddress.slice(0, 54);
    anchor.player_addr_b = playerAuth.playerAddress.slice(54);
    anchor.player_key = chunkHex(playerAuth.playerKey);
    anchor.player_sig = chunkHex(playerAuth.playerSignature);
  }

  const txHash = await anchorOnChain(issuer.wallet, provider, anchor);

  const record = {
    version,
    status,
    txHash,
    attestation: vc,
    canonical,
    attestationHash,
    signature,
    key: sigKey,
    anchor,
    playerAuth,
  };
  attestations.set(key, record);

  return {
    ok: true,
    standard: 'CIP-0170',
    txHash,
    network: config.network,
    issuerAid: issuer.aid,
    issuerAddr: issuer.address,
    version,
    status,
    attestationHash,
    attestation: vc,
    signature,
    verificationKey: sigKey,
    playerSignature: playerAuth ? playerAuth.playerSignature : null,
    playerKey: playerAuth ? playerAuth.playerKey : null,
    playerAddress: playerAuth ? playerAuth.playerAddress : null,
    explorerUrl: config.explorerUrl(txHash),
  };
}

export function createAttestation(params) {
  return attest({ ...params, update: false });
}

export function updateAttestation(params) {
  return attest({ ...params, update: true });
}

/**
 * Phase 1 of CIP-30 signing: build the attestation and return the hash the
 * player must sign with their own wallet (CIP-30 signData). Then call
 * createAttestation with the resulting playerSignature + playerKey.
 */
export async function prepareAttestation({ playerAddress, playerName, achievement, event, questId, tier, progression, update }) {
  const subject = playerAddress;
  if (!subject || !/^addr_test1/.test(subject)) {
    throw new Error('prepareAttestation: a valid testnet address (addr_test1...) is required');
  }
  const issuer = await getIssuer();
  const key = `${subject}|${achievement}`;
  const prev = attestations.get(key);
  const version = update && prev ? prev.version + 1 : 1;
  const status = version === 1 ? 'created' : 'updated';

  const { vc, canonical, attestationHash } = buildAttestation({
    issuer,
    subject,
    playerName,
    achievement,
    event,
    questId,
    tier,
    progression,
    version,
    status,
  });

  return {
    ok: true,
    standard: 'CIP-0170',
    attestation: vc,
    canonical,
    attestationHash,
    issuerAid: issuer.aid,
    issuerAddr: issuer.address,
    version,
    status,
    note: 'Sign attestationHash with your wallet (CIP-30 signData) then call /api/attestation/create with playerSignature + playerKey.',
  };
}

// ---------------------------------------------------------------------------
// 3. Verification — on-chain evidence + signature
// ---------------------------------------------------------------------------
export async function getOnChainAnchor(txHash) {
  const rows = await koiosJson('tx_metadata', { method: 'POST', body: { _tx_hashes: [txHash] } });
  const row = (rows || [])[0];
  if (!row) return null;
  // Koios shape: { tx_hash, metadata: { "<label>": {...} } }
  if (row.metadata && typeof row.metadata === 'object') {
    return row.metadata[ANCHOR_LABEL] ?? null;
  }
  // Blockfrost shape fallback: [{ label, json_metadata }]
  const bf = (rows || []).find((r) => String(r.label) === ANCHOR_LABEL);
  return bf ? bf.json_metadata : null;
}

export async function verifyAttestation({ txHash, attestation, signature, key, issuerAddr, playerSignature, playerKey, playerAddr }) {
  if (!txHash) throw new Error('verifyAttestation: txHash is required');
  const anchor = await getOnChainAnchor(txHash);
  if (!anchor) {
    return { verified: false, reason: 'no CIP-0170 anchor found on-chain for this tx' };
  }

  // Recover full addresses from their split a/b fields (or the caller's values).
  const anchorIssuerAddr = anchor.issuer_addr_a && anchor.issuer_addr_b
    ? anchor.issuer_addr_a + anchor.issuer_addr_b
    : anchor.issuerAddr || '';
  const effectiveIssuerAddr = issuerAddr || anchorIssuerAddr;

  // 1. Recompute the attestation hash and compare with the on-chain anchor.
  let hashMatch = false;
  if (attestation) {
    const canonical = stableStringify(attestation);
    const hash = blake2b.hash(bytesFromUtf8(canonical), 32);
    hashMatch = hash === anchor.attestationHash;
  }

  // 2. Verify the issuer's Ed25519 signature (CIP-8) over the attestation hash.
  let signatureValid = false;
  let signatureError = null;
  if (signature && key) {
    try {
      signatureValid = await checkSignature(anchor.attestationHash, { key, signature }, effectiveIssuerAddr);
    } catch (err) {
      signatureError = err.message;
    }
  }

  // 3. If the player authorized with their own wallet (CIP-30), verify that too.
  let playerValid = null; // null = not provided; true/false = provided and checked
  let playerError = null;
  const anchorPlayerAddr = anchor.player_addr_a && anchor.player_addr_b
    ? anchor.player_addr_a + anchor.player_addr_b
    : null;
  const sigForPlayer = playerSignature || joinChunks(anchor.player_sig);
  const keyForPlayer = playerKey || joinChunks(anchor.player_key);
  if (sigForPlayer && keyForPlayer) {
    try {
      playerValid = await checkSignature(
        anchor.attestationHash,
        { key: keyForPlayer, signature: sigForPlayer },
        playerAddr || anchorPlayerAddr,
      );
    } catch (err) {
      playerError = err.message;
    }
  }

  const verified = hashMatch && signatureValid && playerValid !== false;
  const parts = [
    `hash_match=${hashMatch}`,
    `issuer_signature=${signatureValid}${signatureError ? ` (${signatureError})` : ''}`,
  ];
  if (playerValid !== null) parts.push(`player_signature=${playerValid}${playerError ? ` (${playerError})` : ''}`);
  return {
    verified,
    txHash,
    reason: verified
      ? 'on-chain anchor matches, issuer signature valid, player authorization valid'
      : parts.join(' '),
    anchor,
    hashMatch,
    signatureValid,
    playerValid,
  };
}

export function getAttestationRecord({ playerAddress, achievement }) {
  const key = `${playerAddress}|${achievement}`;
  return attestations.get(key) || null;
}

export function getPlayerProfiles() {
  return Array.from(profiles.values());
}