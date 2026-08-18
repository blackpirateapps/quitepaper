import { Client } from '@libsql/client';
import { ApiError } from '../errors/apiError.js';
import { WrappedKeyInput, wrappedKeySchema } from '../validation/schemas.js';
import crypto from 'crypto';

export async function getEncryptionKey(db: Client, userId: string): Promise<WrappedKeyInput | null> {
  const result = await db.execute({
    sql: `SELECT key_version, wrapped_master_key, wrapped_nonce, kdf_algorithm, kdf_salt, kdf_parameters,
                 encryption_format_version, recovery_wrapped_master_key, recovery_nonce, recovery_salt, recovery_parameters
          FROM encryption_keys
          WHERE user_id = ?
          ORDER BY key_version DESC
          LIMIT 1`,
    args: [userId],
  });

  if (result.rows.length === 0) {
    return null;
  }

  const row = result.rows[0];
  return {
    keyVersion: Number(row.key_version),
    wrappedMasterKey: row.wrapped_master_key as string,
    wrappedNonce: row.wrapped_nonce as string,
    kdfAlgorithm: 'argon2id',
    kdfSalt: row.kdf_salt as string,
    kdfParameters: JSON.parse(row.kdf_parameters as string),
    encryptionFormatVersion: Number(row.encryption_format_version),
    recoveryWrappedMasterKey: (row.recovery_wrapped_master_key as string) || undefined,
    recoveryNonce: (row.recovery_nonce as string) || undefined,
    recoverySalt: (row.recovery_salt as string) || undefined,
    recoveryParameters: row.recovery_parameters ? JSON.parse(row.recovery_parameters as string) : undefined,
  };
}

export async function putEncryptionKey(db: Client, userId: string, rawInput: unknown): Promise<WrappedKeyInput> {
  const parsed = wrappedKeySchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError('BAD_REQUEST', `Invalid key payload: ${parsed.error.message}`, 400, parsed.error.format());
  }

  const data = parsed.data;
  const now = new Date().toISOString();
  const id = crypto.randomUUID();

  // Insert or update key version
  await db.execute({
    sql: `INSERT INTO encryption_keys (
            id, user_id, key_version, wrapped_master_key, wrapped_nonce,
            kdf_algorithm, kdf_salt, kdf_parameters, encryption_format_version,
            recovery_wrapped_master_key, recovery_nonce, recovery_salt, recovery_parameters,
            created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    args: [
      id,
      userId,
      data.keyVersion,
      data.wrappedMasterKey,
      data.wrappedNonce,
      data.kdfAlgorithm,
      data.kdfSalt,
      JSON.stringify(data.kdfParameters),
      data.encryptionFormatVersion,
      data.recoveryWrappedMasterKey || null,
      data.recoveryNonce || null,
      data.recoverySalt || null,
      data.recoveryParameters ? JSON.stringify(data.recoveryParameters) : null,
      now,
      now,
    ],
  });

  return data;
}
