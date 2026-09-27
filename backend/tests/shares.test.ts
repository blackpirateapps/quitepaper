import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';
import { runGarbageCollection } from '../src/gc/garbageCollector.js';
import { encryptShareContent, decryptShareContent, generateShareSlug } from '../src/share/shareCrypto.js';
import { renderMarkdown } from '../src/share/shareRenderer.js';

const AUTH = (uid: string) => ({ authorization: `Bearer mock:${uid}` });

async function createShare(uid: string, body: Record<string, any>) {
  return handleApiRequest({
    method: 'POST',
    url: '/api/v1/shares',
    headers: AUTH(uid),
    body,
  });
}

/**
 * Mock auth maps a Firebase uid to an internal user row with a generated UUID id,
 * so the `user_id` stored on shares/jobs is that UUID — not the raw `mock:` uid.
 * Resolve it when a test needs to query or run GC by the internal user id.
 */
async function internalUserId(firebaseUid: string): Promise<string> {
  const db = getDbClient();
  const res = await db.execute({
    sql: 'SELECT id FROM users WHERE firebase_uid = ? LIMIT 1',
    args: [firebaseUid],
  });
  return res.rows[0].id as string;
}

describe('Public Note Sharing', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    process.env.CLOUDINARY_CLOUD_NAME = 'test-cloud';
    process.env.CLOUDINARY_API_KEY = '123456789012345';
    process.env.CLOUDINARY_API_SECRET = 'abcdefghijklmnopqrstuvwxyz12345';
    process.env.CLOUDINARY_FOLDER = 'quitepaper_test';
    process.env.CLOUDINARY_PUBLIC_FOLDER = 'quietpaper_public_test';
    process.env.PUBLIC_SHARE_BASE_URL = 'https://share.example.com';

    const db = getDbClient();
    await runMigrations(db);
  });

  it('generates unguessable base62 slugs of the requested length', () => {
    const a = generateShareSlug();
    const b = generateShareSlug();
    expect(a).toHaveLength(12);
    expect(a).toMatch(/^[A-Za-z0-9]+$/);
    expect(a).not.toBe(b);
  });

  it('round-trips password-encrypted content and fails on the wrong password', () => {
    const enc = encryptShareContent('# Secret\n\nhello world', 'hunter2');
    expect(decryptShareContent(enc, 'hunter2')).toBe('# Secret\n\nhello world');
    expect(decryptShareContent(enc, 'wrong')).toBeNull();
  });

  it('creates a public share and renders it as HTML at /note/:slug', async () => {
    const res = await createShare('user-share-1', {
      noteId: '11111111-1111-1111-1111-111111111111',
      title: 'My Public Note',
      contentMarkdown: '# Heading\n\nSome **bold** text.',
      visibility: 'public',
    });
    expect(res.statusCode).toBe(200);
    expect(res.body.shareId).toMatch(/^[A-Za-z0-9]{12}$/);
    expect(res.body.url).toBe(`https://share.example.com/note/${res.body.shareId}`);

    const view = await handleApiRequest({
      method: 'GET',
      url: `/note/${res.body.shareId}`,
      headers: {},
    });
    expect(view.statusCode).toBe(200);
    expect(view.headers['Content-Type']).toContain('text/html');
    expect(view.body).toContain('My Public Note');
    expect(view.body).toContain('<strong>bold</strong>');
  });

  it('renders unlisted shares the same as public (reachable only by slug)', async () => {
    const res = await createShare('user-share-2', {
      noteId: '22222222-2222-2222-2222-222222222222',
      title: 'Unlisted',
      contentMarkdown: 'plain body',
      visibility: 'unlisted',
    });
    const view = await handleApiRequest({ method: 'GET', url: `/note/${res.body.shareId}`, headers: {} });
    expect(view.statusCode).toBe(200);
    expect(view.body).toContain('plain body');
  });

  it('gates password shares behind a password prompt', async () => {
    const res = await createShare('user-share-3', {
      noteId: '33333333-3333-3333-3333-333333333333',
      title: 'Locked',
      contentMarkdown: 'secret content here',
      visibility: 'password',
      password: 'letmein',
    });
    expect(res.statusCode).toBe(200);

    // No password -> prompt, content not leaked
    const prompt = await handleApiRequest({ method: 'GET', url: `/note/${res.body.shareId}`, headers: {} });
    expect(prompt.statusCode).toBe(200);
    expect(prompt.body).toContain('Password required');
    expect(prompt.body).not.toContain('secret content here');

    // Wrong password -> 401
    const wrong = await handleApiRequest({
      method: 'POST',
      url: `/note/${res.body.shareId}`,
      headers: {},
      body: 'password=nope',
    });
    expect(wrong.statusCode).toBe(401);
    expect(wrong.body).toContain('Incorrect password');

    // Correct password -> 200 with content
    const ok = await handleApiRequest({
      method: 'POST',
      url: `/note/${res.body.shareId}`,
      headers: {},
      body: 'password=letmein',
    });
    expect(ok.statusCode).toBe(200);
    expect(ok.body).toContain('secret content here');
  });

  it('returns 410 for an expired share (read-time gate)', async () => {
    const res = await createShare('user-share-4', {
      noteId: '44444444-4444-4444-4444-444444444444',
      title: 'Old',
      contentMarkdown: 'body',
      visibility: 'public',
    });
    const db = getDbClient();
    await db.execute({
      sql: `UPDATE note_shares SET expires_at = ? WHERE id = ?`,
      args: ['2000-01-01T00:00:00.000Z', res.body.shareId],
    });

    const view = await handleApiRequest({ method: 'GET', url: `/note/${res.body.shareId}`, headers: {} });
    expect(view.statusCode).toBe(410);
    expect(view.body).toContain('expired');
  });

  it('returns 404 for an unknown slug', async () => {
    const view = await handleApiRequest({ method: 'GET', url: '/note/doesnotexist99', headers: {} });
    expect(view.statusCode).toBe(404);
  });

  it('lists a user shares and updates visibility', async () => {
    const created = await createShare('user-share-5', {
      noteId: '55555555-5555-5555-5555-555555555555',
      title: 'Listed',
      contentMarkdown: 'body text',
      visibility: 'public',
    });

    const list = await handleApiRequest({ method: 'GET', url: '/api/v1/shares', headers: AUTH('user-share-5') });
    expect(list.statusCode).toBe(200);
    expect(list.body.shares).toHaveLength(1);
    expect(list.body.shares[0].shareId).toBe(created.body.shareId);

    const patched = await handleApiRequest({
      method: 'PATCH',
      url: `/api/v1/shares/${created.body.shareId}`,
      headers: AUTH('user-share-5'),
      body: { visibility: 'unlisted' },
    });
    expect(patched.statusCode).toBe(200);
    expect(patched.body.visibility).toBe('unlisted');
  });

  it('deletes a share and enqueues destruction jobs for its attachments', async () => {
    const created = await createShare('user-share-6', {
      noteId: '66666666-6666-6666-6666-666666666666',
      title: 'WithImage',
      contentMarkdown: '![img](https://res.cloudinary.com/x.png)',
      visibility: 'public',
      attachments: [
        {
          cloudPublicId: 'quietpaper_public_test/user-share-6_share_abc',
          cloudUrl: 'https://res.cloudinary.com/test-cloud/image/upload/x.png',
          resourceType: 'image',
          byteSize: 2048,
        },
      ],
    });

    const del = await handleApiRequest({
      method: 'DELETE',
      url: `/api/v1/shares/${created.body.shareId}`,
      headers: AUTH('user-share-6'),
    });
    expect(del.statusCode).toBe(200);
    expect(del.body.destructionJobsCreated).toBe(1);

    // Share no longer viewable
    const view = await handleApiRequest({ method: 'GET', url: `/note/${created.body.shareId}`, headers: {} });
    expect(view.statusCode).toBe(404);

    const db = getDbClient();
    const jobs = await db.execute({
      sql: `SELECT operation, resource_type FROM destruction_jobs WHERE user_id = ?`,
      args: [await internalUserId('user-share-6')],
    });
    expect(jobs.rows.length).toBe(1);
    expect(jobs.rows[0].operation).toBe('delete_share_attachment');
  });

  it('issues signed public upload authorization within the size limit', async () => {
    const auth = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/shares/upload-auth',
      headers: AUTH('user-share-7'),
      body: { uploadId: 'abc-123', kind: 'image', mimeType: 'image/png', byteSize: 5000 },
    });
    expect(auth.statusCode).toBe(200);
    expect(auth.body.signature).toMatch(/^[a-f0-9]{40}$/);
    expect(auth.body.resourceType).toBe('image');
    expect(auth.body.uploadUrl).toContain('/image/upload');
    expect(auth.body.folder).toBe('quietpaper_public_test');
  });

  it('rejects oversized share uploads', async () => {
    const auth = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/shares/upload-auth',
      headers: AUTH('user-share-8'),
      body: { uploadId: 'big', kind: 'file', byteSize: 999_999_999 },
    });
    expect(auth.statusCode).toBe(413);
  });

  it('expires shares past their TTL during garbage collection', async () => {
    const created = await createShare('user-share-9', {
      noteId: '99999999-9999-9999-9999-999999999999',
      title: 'GC me',
      contentMarkdown: 'body',
      visibility: 'public',
      attachments: [
        {
          cloudPublicId: 'quietpaper_public_test/user-share-9_share_z',
          cloudUrl: 'https://res.cloudinary.com/test-cloud/image/upload/z.png',
          resourceType: 'image',
          byteSize: 1024,
        },
      ],
    });

    const db = getDbClient();
    await db.execute({
      sql: `UPDATE note_shares SET expires_at = ? WHERE id = ?`,
      args: ['2000-01-01T00:00:00.000Z', created.body.shareId],
    });

    const summary = await runGarbageCollection(db, await internalUserId('user-share-9'), {});
    expect(summary.sharesExpired).toBe(1);

    const row = await db.execute({ sql: `SELECT status FROM note_shares WHERE id = ?`, args: [created.body.shareId] });
    expect(row.rows[0].status).toBe('expired');
  });

  it('escapes HTML to prevent stored XSS in rendered markdown', () => {
    const html = renderMarkdown('<script>alert(1)</script>\n\n[x](javascript:alert(1))');
    expect(html).not.toContain('<script>');
    expect(html).toContain('&lt;script&gt;');
    // javascript: URLs are not emitted as links
    expect(html).not.toContain('href="javascript:');
  });

  it('renders headings, emphasis and inline code', () => {
    const html = renderMarkdown('# Title\n\n**b** _i_ ~~s~~ ==h== `c`');
    expect(html).toContain('<h1>Title</h1>');
    expect(html).toContain('<strong>b</strong>');
    expect(html).toContain('<em>i</em>');
    expect(html).toContain('<del>s</del>');
    expect(html).toContain('<mark>h</mark>');
    expect(html).toContain('<code>c</code>');
  });

  it('renders GFM pipe tables', () => {
    const html = renderMarkdown('| Name | Age |\n|:-----|----:|\n| Bo | 30 |');
    expect(html).toContain('<table>');
    expect(html).toContain('<th style="text-align:left">Name</th>');
    expect(html).toContain('<td style="text-align:right">30</td>');
  });

  it('renders task lists and nested lists', () => {
    const html = renderMarkdown('- [ ] todo\n- [x] done\n- parent\n  - child');
    expect(html).toContain('type="checkbox" disabled>');
    expect(html).toContain('type="checkbox" disabled checked>');
    // nested <ul> lives inside the parent <li>
    expect(html).toContain('parent<ul><li>');
  });

  it('autolinks bare URLs and mailto links but not javascript', () => {
    const html = renderMarkdown('see https://example.com now and [m](mailto:a@b.com)');
    expect(html).toContain('href="https://example.com"');
    expect(html).toContain('href="mailto:a@b.com"');
  });

  it('does not italicize snake_case identifiers', () => {
    const html = renderMarkdown('my_var_name stays intact');
    expect(html).toContain('my_var_name');
    expect(html).not.toContain('<em>');
  });

  it('renders fenced code with a language class and escapes its contents', () => {
    const html = renderMarkdown('```js\nconst x = "<b>";\n```');
    expect(html).toContain('<pre><code class="language-js">');
    expect(html).toContain('&lt;b&gt;');
  });
});
