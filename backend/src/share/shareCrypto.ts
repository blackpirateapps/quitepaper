import crypto from 'crypto';

/**
 * Cryptographic primitives for public note sharing.
 *
 * Slugs are unguessable, URL-safe base62 identifiers decoupled from the internal
 * note UUID. Password-protected shares are encrypted at rest with a key derived
 * from the visitor password (scrypt) and sealed with AES-256-GCM. The server only
 * ever holds the password transiently to derive the key and decrypt in memory.
 */

const BASE62_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const DEFAULT_SLUG_LENGTH = 12;

/** scrypt cost parameters (RFC 7914). N=16384 keeps per-view derivation cheap while resisting brute force. */
const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const KEY_LENGTH = 32; // AES-256
const SALT_LENGTH = 16;
const IV_LENGTH = 12; // GCM standard nonce length

/**
 * Generates an unguessable base62 share slug from cryptographically secure random bytes.
 * Rejection sampling keeps the distribution uniform across the 62-char alphabet.
 */
export function generateShareSlug(length: number = DEFAULT_SLUG_LENGTH): string {
  const out: string[] = [];
  while (out.length < length) {
    const bytes = crypto.randomBytes(length * 2);
    for (let i = 0; i < bytes.length && out.length < length; i++) {
      const b = bytes[i];
      // 62 * 4 = 248; reject the top 8 values to avoid modulo bias.
      if (b < 248) {
        out.push(BASE62_ALPHABET[b % 62]);
      }
    }
  }
  return out.join('');
}

export interface EncryptedShareContent {
  ciphertext: string; // base64
  salt: string; // base64
  iv: string; // base64
  tag: string; // base64
}

function deriveKey(password: string, salt: Buffer): Buffer {
  return crypto.scryptSync(password, salt, KEY_LENGTH, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P,
    // scrypt needs a higher maxmem than the default to allow N=16384.
    maxmem: 128 * SCRYPT_N * SCRYPT_R * 2,
  });
}

/**
 * Encrypts share content with a password-derived key (scrypt + AES-256-GCM).
 * A fresh random salt and IV are generated per share.
 */
export function encryptShareContent(plaintext: string, password: string): EncryptedShareContent {
  const salt = crypto.randomBytes(SALT_LENGTH);
  const iv = crypto.randomBytes(IV_LENGTH);
  const key = deriveKey(password, salt);

  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();

  return {
    ciphertext: ciphertext.toString('base64'),
    salt: salt.toString('base64'),
    iv: iv.toString('base64'),
    tag: tag.toString('base64'),
  };
}

/**
 * Decrypts password-protected share content. Returns null when the password is
 * wrong (GCM authentication failure) or the stored blob is malformed, so callers
 * can surface an "incorrect password" message without leaking crypto detail.
 */
export function decryptShareContent(
  enc: EncryptedShareContent,
  password: string
): string | null {
  try {
    const salt = Buffer.from(enc.salt, 'base64');
    const iv = Buffer.from(enc.iv, 'base64');
    const tag = Buffer.from(enc.tag, 'base64');
    const ciphertext = Buffer.from(enc.ciphertext, 'base64');
    const key = deriveKey(password, salt);

    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    return plaintext.toString('utf8');
  } catch {
    return null;
  }
}
