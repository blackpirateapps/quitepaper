import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';
import {
  pushSyncSchema,
  pushVersionsSchema,
  pushTagsSchema,
  pushPlaceAliasesSchema,
  pushDocumentAnnotationsSchema,
  pushOcrPagesSchema,
  syncReferencesSchema,
  createShareSchema,
  fetchMissingNotesSchema,
  noteChangeSchema,
} from '../src/validation/schemas.js';

describe('Bounded validation after the Zod security upgrade', () => {
  it.each([
    { schema: pushSyncSchema, field: 'changes', max: 100 },
    { schema: pushVersionsSchema, field: 'versions', max: 100 },
    { schema: pushTagsSchema, field: 'tags', max: 100 },
    { schema: pushPlaceAliasesSchema, field: 'placeAliases', max: 100 },
    { schema: pushDocumentAnnotationsSchema, field: 'annotations', max: 500 },
    { schema: pushOcrPagesSchema, field: 'pages', max: 500 },
    { schema: syncReferencesSchema, field: 'references', max: 500 },
  ])('rejects oversized $field before reading child objects', ({ schema, field, max }) => {
    const unreadableChild = new Proxy({}, {
      get() { throw new Error('Oversized collection must not validate child properties'); },
    });
    const result = schema.safeParse({ [field]: new Array(max + 1).fill(unreadableChild) });

    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues).toEqual([
        expect.objectContaining({ code: 'too_big', path: [field], maximum: max }),
      ]);
    }
  });

  it('rejects oversized public share attachments before reading their properties', () => {
    const unreadableChild = new Proxy({}, {
      get() { throw new Error('Oversized attachments must not be traversed'); },
    });
    const result = createShareSchema.safeParse({
      noteId: '11111111-1111-1111-1111-111111111111',
      attachments: new Array(201).fill(unreadableChild),
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues).toEqual([
        expect.objectContaining({ code: 'too_big', path: ['attachments'], maximum: 200 }),
      ]);
    }
  });

  it('keeps accepting legacy UUID-shaped IDs and rejecting malformed IDs', () => {
    const legacyId = '11111111-1111-1111-1111-111111111111';
    expect(fetchMissingNotesSchema.parse({ ids: [legacyId] }).ids).toEqual([legacyId]);
    expect(fetchMissingNotesSchema.safeParse({ ids: ['not-an-id'] }).success).toBe(false);
  });

  it('preserves note defaults and tombstones while requiring live-note ciphertext', () => {
    const base = {
      id: '11111111-1111-1111-1111-111111111111',
      createdAt: '2026-11-18T00:00:00Z',
      updatedAt: '2026-11-18T00:00:00Z',
    };
    expect(noteChangeSchema.parse({ ...base, isDeleted: true })).toMatchObject({
      isDeleted: true, contentCiphertext: '', contentNonce: '', pinned: false,
      archived: false, trashed: false, contentVersion: 1, encryptionKeyVersion: 1,
    });
    const live = noteChangeSchema.safeParse(base);
    expect(live.success).toBe(false);
    if (!live.success) {
      expect(live.error.issues.map(issue => issue.path)).toEqual([
        ['contentCiphertext'], ['contentNonce'],
      ]);
    }
  });
});

describe('Validation errors retain HTTP 400 responses', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    await runMigrations(getDbClient());
  });

  it.each([
    '/api/v1/attachments/upload-auth',
    '/api/v1/attachments/confirm',
    '/api/v1/documents/upload-auth',
    '/api/v1/documents/confirm',
    '/api/v1/shares',
  ])('returns structured issues for an invalid %s request', async (url) => {
    const response = await handleApiRequest({
      method: 'POST', url, headers: { authorization: 'Bearer mock:validation-user' }, body: {},
    });
    expect(response.statusCode).toBe(400);
    expect(response.body.error.code).toBe('BAD_REQUEST');
    expect(response.body.error.details).toEqual(expect.any(Array));
  });
});
