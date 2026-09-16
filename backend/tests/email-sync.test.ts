import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';
import {
  backfillMissingUserEmails,
  syncSingleUserEmail,
} from '../src/auth/emailSyncService.js';
import { ADMIN_COOKIE_NAME, parseCookies } from '../src/admin/adminAuth.js';

describe('Firebase Auth Email Backfill & Synchronization Engine Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    const db = getDbClient();
    await runMigrations(db);
  });

  it('Previews updates in dry-run mode without modifying Turso database records', async () => {
    const db = getDbClient();
    const now = new Date().toISOString();

    // Insert 2 users without email
    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-dry-1', 'fb-dry-user-1', NULL, ?, ?)",
      args: [now, now],
    });
    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-dry-2', 'fb-dry-user-2', '', ?, ?)",
      args: [now, now],
    });

    const result = await backfillMissingUserEmails(db, {
      dryRun: true,
    });

    expect(result.dryRun).toBe(true);
    expect(result.totalChecked).toBe(2);
    expect(result.updated).toBe(2);
    expect(result.errors.length).toBe(0);

    // Verify DB records remain unchanged (still null/empty)
    const user1 = (await db.execute("SELECT email FROM users WHERE id = 'u-dry-1'")).rows[0];
    const user2 = (await db.execute("SELECT email FROM users WHERE id = 'u-dry-2'")).rows[0];
    expect(user1.email).toBeNull();
    expect(user2.email).toBe('');
  });

  it('Populates missing user emails in live mode across Turso database', async () => {
    const db = getDbClient();
    const now = new Date().toISOString();

    // 1 user with missing email, 1 user already populated
    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-live-1', 'fb-live-user-1', NULL, ?, ?)",
      args: [now, now],
    });
    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-live-2', 'fb-live-user-2', 'already@quietpaper.test', ?, ?)",
      args: [now, now],
    });

    const result = await backfillMissingUserEmails(db, {
      dryRun: false,
    });

    expect(result.dryRun).toBe(false);
    expect(result.totalChecked).toBe(1); // Only user 1 had missing email
    expect(result.updated).toBe(1);
    expect(result.errors.length).toBe(0);

    // Verify DB records updated
    const user1 = (await db.execute("SELECT email FROM users WHERE id = 'u-live-1'")).rows[0];
    const user2 = (await db.execute("SELECT email FROM users WHERE id = 'u-live-2'")).rows[0];
    expect(user1.email).toBe('fb-live-user-1@test.local');
    expect(user2.email).toBe('already@quietpaper.test');
  });

  it('Forces refresh of all users when force: true is specified', async () => {
    const db = getDbClient();
    const now = new Date().toISOString();

    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-force-1', 'fb-force-1', 'old@quietpaper.test', ?, ?)",
      args: [now, now],
    });

    const result = await backfillMissingUserEmails(db, {
      force: true,
      dryRun: false,
    });

    expect(result.totalChecked).toBe(1);
    expect(result.updated).toBe(1);

    const user1 = (await db.execute("SELECT email FROM users WHERE id = 'u-force-1'")).rows[0];
    expect(user1.email).toBe('fb-force-1@test.local');
  });

  it('Synchronizes single user email on demand via syncSingleUserEmail', async () => {
    const db = getDbClient();
    const now = new Date().toISOString();

    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-single-1', 'fb-single-1', NULL, ?, ?)",
      args: [now, now],
    });

    const res = await syncSingleUserEmail(db, 'u-single-1');
    expect(res.success).toBe(true);
    expect(res.updated).toBe(true);
    expect(res.email).toBe('fb-single-1@test.local');

    const userRow = (await db.execute("SELECT email FROM users WHERE id = 'u-single-1'")).rows[0];
    expect(userRow.email).toBe('fb-single-1@test.local');
  });

  it('Triggers bulk email synchronization via Admin Panel POST /admin/users/sync-emails', async () => {
    const db = getDbClient();
    const now = new Date().toISOString();

    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-admin-sync-1', 'fb-admin-sync-1', NULL, ?, ?)",
      args: [now, now],
    });

    // Login as admin
    const loginRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/login',
      headers: { 'content-type': 'application/json' },
      body: { password: 'super-secret-password-123' },
    });
    const cookies = parseCookies(loginRes.headers['Set-Cookie']);
    const authCookie = `${ADMIN_COOKIE_NAME}=${cookies[ADMIN_COOKIE_NAME]}`;

    // Trigger email sync form
    const syncRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/users/sync-emails',
      headers: { cookie: authCookie },
    });

    expect(syncRes.statusCode).toBe(302);
    expect(syncRes.headers['Location']).toContain('/admin/users');
    expect(syncRes.headers['Location']).toContain('Synchronized');

    // Verify DB updated
    const userRow = (await db.execute("SELECT email FROM users WHERE id = 'u-admin-sync-1'")).rows[0];
    expect(userRow.email).toBe('fb-admin-sync-1@test.local');
  });

  it('Triggers single user email sync via Admin Panel POST /admin/users/:id/sync-email', async () => {
    const db = getDbClient();
    const now = new Date().toISOString();

    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-admin-single-1', 'fb-admin-single-1', NULL, ?, ?)",
      args: [now, now],
    });

    const loginRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/login',
      headers: { 'content-type': 'application/json' },
      body: { password: 'super-secret-password-123' },
    });
    const cookies = parseCookies(loginRes.headers['Set-Cookie']);
    const authCookie = `${ADMIN_COOKIE_NAME}=${cookies[ADMIN_COOKIE_NAME]}`;

    const syncRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/users/u-admin-single-1/sync-email',
      headers: { cookie: authCookie },
    });

    expect(syncRes.statusCode).toBe(302);
    expect(syncRes.headers['Location']).toContain('/admin/users/u-admin-single-1');

    const userRow = (await db.execute("SELECT email FROM users WHERE id = 'u-admin-single-1'")).rows[0];
    expect(userRow.email).toBe('fb-admin-single-1@test.local');
  });

  it('Allows JSON API bulk email sync via POST /api/admin/users/sync-emails with Bearer password', async () => {
    const db = getDbClient();
    const now = new Date().toISOString();

    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, created_at, updated_at) VALUES ('u-api-sync-1', 'fb-api-sync-1', NULL, ?, ?)",
      args: [now, now],
    });

    const apiRes = await handleApiRequest({
      method: 'POST',
      url: '/api/admin/users/sync-emails',
      headers: {
        authorization: 'Bearer super-secret-password-123',
        'content-type': 'application/json',
      },
      body: { dryRun: false },
    });

    expect(apiRes.statusCode).toBe(200);
    expect(apiRes.body.totalChecked).toBe(1);
    expect(apiRes.body.updated).toBe(1);
  });
});
