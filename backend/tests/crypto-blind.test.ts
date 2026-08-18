import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import fs from 'fs';
import path from 'path';

describe('Crypto-Blindness & Server Privacy Assurance Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('Verifies notes database table has NO plaintext title, body, or tags columns', async () => {
    const db = getDbClient();
    const tableInfo = await db.execute('PRAGMA table_info(notes)');
    const columnNames = tableInfo.rows.map(r => r.name as string);

    expect(columnNames).not.toContain('title');
    expect(columnNames).not.toContain('body');
    expect(columnNames).not.toContain('tags');
    expect(columnNames).not.toContain('plaintext');
    expect(columnNames).not.toContain('content');

    // Asserts encrypted columns exist
    expect(columnNames).toContain('content_ciphertext');
    expect(columnNames).toContain('content_nonce');
    expect(columnNames).toContain('encryption_key_version');
  });

  it('Verifies backend source code contains NO decryption functions for note content', () => {
    const srcDir = path.resolve(__dirname, '../src');
    const allFiles: string[] = [];

    function scanDir(dir: string) {
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          scanDir(fullPath);
        } else if (entry.name.endsWith('.ts') || entry.name.endsWith('.js')) {
          allFiles.push(fullPath);
        }
      }
    }

    scanDir(srcDir);
    expect(allFiles.length).toBeGreaterThan(0);

    const forbiddenSymbols = [
      'decryptNote',
      'decryptTitle',
      'decryptBody',
      'decryptTags',
      'getMasterEncryptionKey',
      'extractPlaintext',
    ];

    for (const file of allFiles) {
      const content = fs.readFileSync(file, 'utf-8');
      for (const symbol of forbiddenSymbols) {
        expect(content).not.toContain(symbol);
      }
    }
  });
});
