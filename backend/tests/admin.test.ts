import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';
import { parseCookies, ADMIN_COOKIE_NAME } from '../src/admin/adminAuth.js';

describe('Admin Panel & Authentication Tests', () => {
  const originalAdminPassword = process.env.ADMIN_PASSWORD;

  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    delete process.env.ADMIN_PASSWORD;
    delete process.env.ADMIN_SECRET;

    const db = getDbClient();
    await runMigrations(db);
  });

  afterEach(() => {
    if (originalAdminPassword) {
      process.env.ADMIN_PASSWORD = originalAdminPassword;
    } else {
      delete process.env.ADMIN_PASSWORD;
    }
  });

  it('Returns 503 when ADMIN_PASSWORD is not configured', async () => {
    const resHtml = await handleApiRequest({
      method: 'GET',
      url: '/admin',
      headers: {},
    });
    expect(resHtml.statusCode).toBe(503);
    expect(resHtml.body).toContain('Admin Panel Not Configured');

    const resJson = await handleApiRequest({
      method: 'GET',
      url: '/api/admin/stats',
      headers: {},
    });
    expect(resJson.statusCode).toBe(503);
    expect(resJson.body.error.code).toBe('ADMIN_DISABLED');
  });

  it('Serves login page when unauthenticated', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    const res = await handleApiRequest({
      method: 'GET',
      url: '/admin/login',
      headers: {},
    });
    expect(res.statusCode).toBe(200);
    expect(res.headers['Content-Type']).toContain('text/html');
    expect(res.body).toContain('Quiet Paper Admin');
    expect(res.body).toContain('Sign In to Dashboard');
  });

  it('Redirects unauthenticated requests from /admin to /admin/login', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    const res = await handleApiRequest({
      method: 'GET',
      url: '/admin',
      headers: {},
    });
    expect(res.statusCode).toBe(302);
    expect(res.headers['Location']).toBe('/admin/login');
  });

  it('Rejects invalid password attempt on POST /admin/login with 401', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    const res = await handleApiRequest({
      method: 'POST',
      url: '/admin/login',
      headers: { 'content-type': 'application/json' },
      body: { password: 'wrong-password' },
    });
    expect(res.statusCode).toBe(401);
    expect(res.body).toContain('Invalid administrator password');
  });

  it('Authenticates valid password, sets HMAC session cookie, and allows access', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    // 1. Login
    const loginRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/login',
      headers: { 'content-type': 'application/json' },
      body: { password: 'super-secret-password-123' },
    });
    expect(loginRes.statusCode).toBe(302);
    expect(loginRes.headers['Location']).toBe('/admin');
    const setCookie = loginRes.headers['Set-Cookie'];
    expect(setCookie).toBeDefined();
    expect(setCookie).toContain(ADMIN_COOKIE_NAME);

    // Extract cookie token
    const cookies = parseCookies(setCookie);
    const sessionToken = cookies[ADMIN_COOKIE_NAME];
    expect(sessionToken).toBeDefined();

    // 2. Access /admin with valid session cookie
    const adminRes = await handleApiRequest({
      method: 'GET',
      url: '/admin',
      headers: {
        cookie: `${ADMIN_COOKIE_NAME}=${sessionToken}`,
      },
    });
    expect(adminRes.statusCode).toBe(200);
    expect(adminRes.headers['Content-Type']).toContain('text/html');
    expect(adminRes.body).toContain('Platform Overview');
    expect(adminRes.body).toContain('Total Users');
    expect(adminRes.body).toContain('DB');
  });

  it('Rejects tampered session token and redirects to login', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    const fakeToken = 'eyJleHAiOjE5OTk5OTk5OTl9.invalid-signature';
    const res = await handleApiRequest({
      method: 'GET',
      url: '/admin',
      headers: {
        cookie: `${ADMIN_COOKIE_NAME}=${fakeToken}`,
      },
    });
    expect(res.statusCode).toBe(302);
    expect(res.headers['Location']).toBe('/admin/login');
  });

  it('Allows API access to /api/admin/stats using Bearer ADMIN_PASSWORD', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    const res = await handleApiRequest({
      method: 'GET',
      url: '/api/admin/stats',
      headers: {
        authorization: 'Bearer super-secret-password-123',
      },
    });
    expect(res.statusCode).toBe(200);
    expect(res.body.users.total).toBe(0);
    expect(res.body.notes.total).toBe(0);
    expect(res.body.syncActivity).toBeDefined();
    expect(res.body.dbPingMs).toBeGreaterThanOrEqual(0);
  });

  it('Renders Users list and User detail with zero-knowledge assurance', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    // Seed a user and an encrypted note via standard sync
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:admin-test-user' },
      body: {
        changes: [
          {
            id: '22222222-2222-2222-2222-222222222222',
            clientRevision: 1,
            contentCiphertext: 'ZW5jcnlwdGVkLWJsb2I=',
            contentNonce: 'bm9uY2UtMTIzNDU2Nzg5MDEy',
            contentVersion: 1,
            encryptionKeyVersion: 1,
            isDeleted: false,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          },
        ],
      },
    });

    const sessionRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/login',
      headers: { 'content-type': 'application/json' },
      body: { password: 'super-secret-password-123' },
    });
    const cookies = parseCookies(sessionRes.headers['Set-Cookie']);
    const authCookie = `${ADMIN_COOKIE_NAME}=${cookies[ADMIN_COOKIE_NAME]}`;

    // 1. List users
    const usersRes = await handleApiRequest({
      method: 'GET',
      url: '/admin/users',
      headers: { cookie: authCookie },
    });
    expect(usersRes.statusCode).toBe(200);
    expect(usersRes.body).toContain('admin-test-user');
    expect(usersRes.body).toContain('1 notes');

    // Extract user ID from database
    const db = getDbClient();
    const userRow = (await db.execute('SELECT id FROM users LIMIT 1')).rows[0];
    const userId = String(userRow.id);

    // 2. View User detail
    const detailRes = await handleApiRequest({
      method: 'GET',
      url: `/admin/users/${userId}`,
      headers: { cookie: authCookie },
    });
    expect(detailRes.statusCode).toBe(200);
    expect(detailRes.body).toContain('User Audit &amp; Control');
    expect(detailRes.body).toContain('End-to-End Encryption Guarantee');
    expect(detailRes.body).toContain(userId);

    // Ensure zero-knowledge invariant: No plaintext note title or body exists in the HTML
    expect(detailRes.body).not.toContain('Plaintext Note');

    // 3. Trigger User GC Dry Run
    const gcRes = await handleApiRequest({
      method: 'POST',
      url: `/admin/users/${userId}/gc`,
      headers: {
        cookie: authCookie,
        'content-type': 'application/json',
      },
      body: { dryRun: true },
    });
    expect(gcRes.statusCode).toBe(302);
    expect(gcRes.headers['Location']).toContain('Dry%20Run');
  });

  it('Renders Storage & GC view and allows destruction job retry', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    const db = getDbClient();
    const now = new Date().toISOString();
    const jobId = '99999999-9999-9999-9999-999999999999';

    // Insert user and failed destruction job
    await db.execute({
      sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
      args: ['u-test-job', 'fb-test-job', now, now],
    });
    await db.execute({
      sql: `INSERT INTO destruction_jobs
            (id, user_id, resource_type, resource_id, cloudinary_public_id, operation, state, attempt_count, available_at, last_error, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        jobId,
        'u-test-job',
        'attachment',
        'res-123',
        'cld-123',
        'delete_cloudinary',
        'failed',
        3,
        now,
        'Cloudinary 500 error',
        now,
        now,
      ],
    });

    const sessionRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/login',
      headers: { 'content-type': 'application/json' },
      body: { password: 'super-secret-password-123' },
    });
    const cookies = parseCookies(sessionRes.headers['Set-Cookie']);
    const authCookie = `${ADMIN_COOKIE_NAME}=${cookies[ADMIN_COOKIE_NAME]}`;

    // 1. Inspect Storage view
    const storageRes = await handleApiRequest({
      method: 'GET',
      url: '/admin/storage',
      headers: { cookie: authCookie },
    });
    expect(storageRes.statusCode).toBe(200);
    expect(storageRes.body).toContain('Cloud Storage &amp; Destruction Jobs');
    expect(storageRes.body).toContain('failed');
    expect(storageRes.body).toContain('Cloudinary 500 error');

    // 2. Retry Destruction Job
    const retryRes = await handleApiRequest({
      method: 'POST',
      url: `/admin/jobs/${jobId}/retry`,
      headers: { cookie: authCookie },
    });
    expect(retryRes.statusCode).toBe(302);
    expect(retryRes.headers['Location']).toContain('/admin/storage');

    // Verify DB state reset to pending
    const updatedJob = (
      await db.execute({
        sql: 'SELECT state, attempt_count, last_error FROM destruction_jobs WHERE id = ?',
        args: [jobId],
      })
    ).rows[0];
    expect(updatedJob.state).toBe('pending');
    expect(updatedJob.attempt_count).toBe(0);
    expect(updatedJob.last_error).toBeNull();
  });

  it('Logs out and clears session cookie on POST /admin/logout', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';

    const logoutRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/logout',
      headers: {},
    });
    expect(logoutRes.statusCode).toBe(302);
    expect(logoutRes.headers['Location']).toBe('/admin/login');
    expect(logoutRes.headers['Set-Cookie']).toContain('Max-Age=0');
  });

  it('Searches users by email, changes user plan to Premium, reconciles storage, and logs audit', async () => {
    process.env.ADMIN_PASSWORD = 'super-secret-password-123';
    const db = getDbClient();
    const now = new Date().toISOString();
    const targetUserId = 'u-admin-plan-test';

    // Insert user with email
    await db.execute({
      sql: "INSERT INTO users (id, firebase_uid, email, plan, storage_used_bytes, created_at, updated_at) VALUES (?, 'fb-admin-plan', 'alice@quietpaper.test', 'free', 5000, ?, ?)",
      args: [targetUserId, now, now],
    });

    const sessionRes = await handleApiRequest({
      method: 'POST',
      url: '/admin/login',
      headers: { 'content-type': 'application/json' },
      body: { password: 'super-secret-password-123' },
    });
    const cookies = parseCookies(sessionRes.headers['Set-Cookie']);
    const authCookie = `${ADMIN_COOKIE_NAME}=${cookies[ADMIN_COOKIE_NAME]}`;

    // 1. Search by email
    const searchRes = await handleApiRequest({
      method: 'GET',
      url: '/admin/users?q=alice%40quietpaper.test',
      headers: { cookie: authCookie },
    });
    expect(searchRes.statusCode).toBe(200);
    expect(searchRes.body).toContain('alice@quietpaper.test');
    expect(searchRes.body).toContain('Free');

    // 2. Change plan to Premium
    const changePlanRes = await handleApiRequest({
      method: 'POST',
      url: `/admin/users/${targetUserId}/plan`,
      headers: {
        cookie: authCookie,
        'content-type': 'application/json',
      },
      body: { plan: 'premium' },
    });
    expect(changePlanRes.statusCode).toBe(302);
    expect(changePlanRes.headers['Location']).toContain('/admin/users');

    // Verify DB user plan updated
    const userRow = (await db.execute({ sql: 'SELECT plan FROM users WHERE id = ?', args: [targetUserId] })).rows[0];
    expect(userRow.plan).toBe('premium');

    // Verify Audit log created
    const auditLogs = (await db.execute({ sql: 'SELECT * FROM admin_audit_logs WHERE user_id = ?', args: [targetUserId] })).rows;
    expect(auditLogs.length).toBeGreaterThan(0);
    expect(auditLogs[0].action).toBe('PLAN_CHANGED');
    expect(auditLogs[0].old_value).toBe('free');
    expect(auditLogs[0].new_value).toBe('premium');

    // 3. Reconcile storage counters
    const reconcileRes = await handleApiRequest({
      method: 'POST',
      url: `/admin/users/${targetUserId}/reconcile`,
      headers: { cookie: authCookie },
    });
    expect(reconcileRes.statusCode).toBe(302);

    // 4. View User Detail Page and verify Premium status & Audit log displayed
    const detailRes = await handleApiRequest({
      method: 'GET',
      url: `/admin/users/${targetUserId}`,
      headers: { cookie: authCookie },
    });
    expect(detailRes.statusCode).toBe(200);
    expect(detailRes.body).toContain('PREMIUM');
    expect(detailRes.body).toContain('Administrative Audit Log');
    expect(detailRes.body).toContain('PLAN_CHANGED');

    // 5. Unauthenticated request to change plan is rejected
    const unauthRes = await handleApiRequest({
      method: 'POST',
      url: `/admin/users/${targetUserId}/plan`,
      body: { plan: 'free' },
    });
    expect(unauthRes.statusCode).toBe(302);
    expect(unauthRes.headers['Location']).toContain('/admin/login');
  });
});

