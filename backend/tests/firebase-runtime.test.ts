import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

// Vercel's loader can reject require(esm) even when local Node enables it.
// Use a fresh process so Vitest's module loader cannot mask that failure.
function runWithoutRequireEsm(source: string) {
  const result = spawnSync(process.execPath, [
    '--no-experimental-require-module',
    '--input-type=module',
    '--eval',
    source,
  ], {
    cwd: fileURLToPath(new URL('../', import.meta.url)),
    encoding: 'utf8',
    timeout: 10_000,
  });

  expect(result.error).toBeUndefined();
  expect(result.status, result.stderr).toBe(0);
  expect(result.stderr).toBe('');
}

describe('Firebase serverless runtime compatibility', () => {
  it('loads Firebase Auth and App Check without require(esm)', () => {
    runWithoutRequireEsm(`
      import { strict as assert } from 'node:assert';
      import { initializeApp, deleteApp } from 'firebase-admin/app';
      import { getAuth } from 'firebase-admin/auth';
      import { getAppCheck } from 'firebase-admin/app-check';

      const app = initializeApp({ projectId: 'quietpaper-runtime-test' });
      assert.equal(typeof getAuth(app).verifyIdToken, 'function');
      assert.equal(typeof getAppCheck(app).verifyToken, 'function');
      await deleteApp(app);
    `);
  });

  it('resolves a JWKS RSA key and verifies its signature without require(esm)', () => {
    runWithoutRequireEsm(`
      import { strict as assert } from 'node:assert';
      import { generateKeyPairSync, sign, verify } from 'node:crypto';
      import { createRequire } from 'node:module';

      const require = createRequire(import.meta.url);
      const firebaseRequire = createRequire(require.resolve('firebase-admin/auth'));
      const jwksClient = firebaseRequire('jwks-rsa');
      const { publicKey, privateKey } = generateKeyPairSync('rsa', {
        modulusLength: 2048,
      });
      const jwk = publicKey.export({ format: 'jwk' });
      const client = jwksClient({
        cache: false,
        rateLimit: false,
        fetcher: async () => ({ keys: [{
          ...jwk, kid: 'runtime-key', alg: 'RS256', use: 'sig',
        }] }),
      });

      const key = await client.getSigningKey('runtime-key');
      const payload = Buffer.from('quietpaper-runtime-test');
      const signature = sign('RSA-SHA256', payload, privateKey);
      assert.equal(key.kid, 'runtime-key');
      assert.equal(verify('RSA-SHA256', payload, key.getPublicKey(), signature), true);
      assert.equal(verify('RSA-SHA256', Buffer.from('tampered'), key.getPublicKey(), signature), false);
    `);
  });
});
