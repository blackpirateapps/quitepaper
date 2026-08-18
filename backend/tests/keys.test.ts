import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Backend Wrapped Master Key Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Returns 404 when user has no configured keys', async () => {
    const res = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-fresh' },
    });
    expect(res.statusCode).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('Stores and retrieves wrapped master key and KDF metadata', async () => {
    const keyPayload = {
      keyVersion: 1,
      wrappedMasterKey: 'd3JhcHBlZC1tYXN0ZXIta2V5LWNpcGhlcnRleHQ=',
      wrappedNonce: 'bm9uY2UtMTIzNDU2Nzg5MDEy',
      kdfAlgorithm: 'argon2id',
      kdfSalt: 'c2FsdC0xMjM0NTY3ODkwMTI=',
      kdfParameters: {
        memory: 19456,
        iterations: 2,
        parallelism: 1,
        hashLength: 32,
      },
      encryptionFormatVersion: 1,
      recoveryWrappedMasterKey: 'cmVjb3Zlcnktd3JhcHBlZC1tYXN0ZXIta2V5',
      recoveryNonce: 'cmVjb3Zlcnktbm9uY2UtMTI=',
      recoverySalt: 'cmVjb3Zlcnktc2FsdC0xMjM0NTY3OA==',
      recoveryParameters: {
        memory: 19456,
        iterations: 2,
        parallelism: 1,
        hashLength: 32,
      },
    };

    const putRes = await handleApiRequest({
      method: 'PUT',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-1' },
      body: keyPayload,
    });
    expect(putRes.statusCode).toBe(200);

    const getRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-1' },
    });
    expect(getRes.statusCode).toBe(200);
    expect(getRes.body.wrappedMasterKey).toBe(keyPayload.wrappedMasterKey);
    expect(getRes.body.wrappedNonce).toBe(keyPayload.wrappedNonce);
    expect(getRes.body.kdfSalt).toBe(keyPayload.kdfSalt);
    expect(getRes.body.recoveryWrappedMasterKey).toBe(keyPayload.recoveryWrappedMasterKey);
  });

  it('Supports updating wrapped key during password rotation', async () => {
    const keyV1 = {
      keyVersion: 1,
      wrappedMasterKey: 'd3JhcHBlZC12MQ==',
      wrappedNonce: 'bm9uY2UtdjEtMTIzNDU2',
      kdfAlgorithm: 'argon2id',
      kdfSalt: 'c2FsdC12MS0xMjM0NTY3OA==',
      kdfParameters: { memory: 19456, iterations: 2, parallelism: 1, hashLength: 32 },
      encryptionFormatVersion: 1,
    };

    await handleApiRequest({
      method: 'PUT',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-rotate' },
      body: keyV1,
    });

    const keyV2 = {
      ...keyV1,
      keyVersion: 2,
      wrappedMasterKey: 'd3JhcHBlZC12Mg==',
      wrappedNonce: 'bm9uY2UtdjItMTIzNDU2',
      kdfSalt: 'c2FsdC12Mi0xMjM0NTY3OA==',
    };

    await handleApiRequest({
      method: 'PUT',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-rotate' },
      body: keyV2,
    });

    const getRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-rotate' },
    });
    expect(getRes.statusCode).toBe(200);
    expect(getRes.body.keyVersion).toBe(2);
    expect(getRes.body.wrappedMasterKey).toBe('d3JhcHBlZC12Mg==');
  });

  it('Rejects key rotation with duplicate version or mismatched commitment', async () => {
    const keyV1 = {
      keyVersion: 1,
      wrappedMasterKey: 'd3JhcHBlZC12MQ==',
      wrappedNonce: 'bm9uY2UtdjEtMTIzNDU2',
      kdfAlgorithm: 'argon2id',
      kdfSalt: 'c2FsdC12MS0xMjM0NTY3OA==',
      kdfParameters: { memory: 19456, iterations: 2, parallelism: 1, hashLength: 32 },
      encryptionFormatVersion: 1,
      keyAuthCommitment: 'valid-master-key-commitment-1234567890',
    };

    await handleApiRequest({
      method: 'PUT',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-verify' },
      body: keyV1,
    });

    // 1. Same version should be rejected with 409
    const duplicateRes = await handleApiRequest({
      method: 'PUT',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-verify' },
      body: keyV1,
    });
    expect(duplicateRes.statusCode).toBe(409);

    // 2. Mismatched commitment should be rejected with 403
    const fakeKeyV2 = {
      ...keyV1,
      keyVersion: 2,
      keyAuthCommitment: 'wrong-attacker-commitment-9999999999',
    };
    const rejectedRes = await handleApiRequest({
      method: 'PUT',
      url: '/api/v1/keys',
      headers: { authorization: 'Bearer mock:user-verify' },
      body: fakeKeyV2,
    });
    expect(rejectedRes.statusCode).toBe(403);
  });
});
