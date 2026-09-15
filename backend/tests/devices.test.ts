import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';

describe('Devices & Sessions Backend Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();
    await runMigrations(db);
  });

  it('1. Registers an authenticated device with full metadata', async () => {
    const res = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-device-1' },
      body: {
        deviceId: 'dev-pixel-9',
        deviceName: 'Pixel 9 Pro',
        platform: 'Android',
        model: 'Pixel 9 Pro',
        osVersion: 'Android 15',
        appVersion: '1.5.8',
      },
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.device).toBeDefined();
    expect(res.body.device.deviceId).toBe('dev-pixel-9');
    expect(res.body.device.deviceName).toBe('Pixel 9 Pro');
    expect(res.body.device.platform).toBe('Android');
    expect(res.body.device.model).toBe('Pixel 9 Pro');
    expect(res.body.device.osVersion).toBe('Android 15');
    expect(res.body.device.appVersion).toBe('1.5.8');
    expect(res.body.device.revokedAt).toBeNull();
  });

  it('2. Device registration is idempotent and updates existing record', async () => {
    // Initial registration
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-device-1' },
      body: {
        deviceId: 'dev-macbook-1',
        deviceName: 'MacBook Air',
        platform: 'macOS',
        model: 'Mac14,2',
        osVersion: 'macOS 14.4',
        appVersion: '1.5.7',
      },
    });

    // Re-registration / app update
    const updateRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-device-1' },
      body: {
        deviceId: 'dev-macbook-1',
        deviceName: 'Work MacBook',
        platform: 'macOS',
        model: 'Mac14,2',
        osVersion: 'macOS 15.0',
        appVersion: '1.5.8',
      },
    });

    expect(updateRes.statusCode).toBe(200);
    expect(updateRes.body.device.deviceId).toBe('dev-macbook-1');
    expect(updateRes.body.device.deviceName).toBe('Work MacBook');
    expect(updateRes.body.device.appVersion).toBe('1.5.8');

    // Verify only 1 device exists for user
    const listRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/devices',
      headers: { authorization: 'Bearer mock:user-device-1' },
    });
    expect(listRes.body.devices.length).toBe(1);
  });

  it('3. Lists active devices for authenticated user in order of activity', async () => {
    // Register 2 devices
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-device-1' },
      body: {
        deviceId: 'dev-phone',
        deviceName: 'Phone',
        platform: 'Android',
      },
    });

    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-device-1' },
      body: {
        deviceId: 'dev-tablet',
        deviceName: 'Tablet',
        platform: 'Android',
      },
    });

    const res = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/devices',
      headers: { authorization: 'Bearer mock:user-device-1' },
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.devices.length).toBe(2);
    const deviceIds = res.body.devices.map((d: any) => d.deviceId);
    expect(deviceIds).toContain('dev-phone');
    expect(deviceIds).toContain('dev-tablet');
  });

  it('4. Enforces strict authorization isolation across different users', async () => {
    // User A registers dev-a
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-A' },
      body: { deviceId: 'dev-A-1', deviceName: "User A's Phone" },
    });

    // User B registers dev-b
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-B' },
      body: { deviceId: 'dev-B-1', deviceName: "User B's Phone" },
    });

    // User A cannot see User B's devices
    const listA = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/devices',
      headers: { authorization: 'Bearer mock:user-A' },
    });
    expect(listA.body.devices.length).toBe(1);
    expect(listA.body.devices[0].deviceId).toBe('dev-A-1');

    // User A cannot rename User B's device
    const renameRes = await handleApiRequest({
      method: 'PATCH',
      url: '/api/v1/devices/dev-B-1',
      headers: { authorization: 'Bearer mock:user-A' },
      body: { deviceName: 'Hacked Phone' },
    });
    expect(renameRes.statusCode).toBe(404);

    // User A cannot revoke User B's device
    const revokeRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/dev-B-1/revoke',
      headers: { authorization: 'Bearer mock:user-A' },
    });
    expect(revokeRes.statusCode).toBe(404);
  });

  it('5. Successfully renames a device and returns updated metadata', async () => {
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-rename' },
      body: { deviceId: 'dev-target', deviceName: 'Old Name' },
    });

    const patchRes = await handleApiRequest({
      method: 'PATCH',
      url: '/api/v1/devices/dev-target',
      headers: { authorization: 'Bearer mock:user-rename' },
      body: { deviceName: 'New Refined Name' },
    });

    expect(patchRes.statusCode).toBe(200);
    expect(patchRes.body.device.deviceName).toBe('New Refined Name');

    const getRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/devices',
      headers: { authorization: 'Bearer mock:user-rename' },
    });
    expect(getRes.body.devices[0].deviceName).toBe('New Refined Name');
  });

  it('6. Rejects invalid device names (empty, spaces only, control characters, too long)', async () => {
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-val' },
      body: { deviceId: 'dev-val', deviceName: 'Valid' },
    });

    // Empty name
    const emptyRes = await handleApiRequest({
      method: 'PATCH',
      url: '/api/v1/devices/dev-val',
      headers: { authorization: 'Bearer mock:user-val' },
      body: { deviceName: '' },
    });
    expect(emptyRes.statusCode).toBe(400);

    // Whitespace only
    const spaceRes = await handleApiRequest({
      method: 'PATCH',
      url: '/api/v1/devices/dev-val',
      headers: { authorization: 'Bearer mock:user-val' },
      body: { deviceName: '   ' },
    });
    expect(spaceRes.statusCode).toBe(400);

    // Control characters
    const ctrlRes = await handleApiRequest({
      method: 'PATCH',
      url: '/api/v1/devices/dev-val',
      headers: { authorization: 'Bearer mock:user-val' },
      body: { deviceName: 'Bad\x00Name' },
    });
    expect(ctrlRes.statusCode).toBe(400);

    // Exceeds max length
    const longRes = await handleApiRequest({
      method: 'PATCH',
      url: '/api/v1/devices/dev-val',
      headers: { authorization: 'Bearer mock:user-val' },
      body: { deviceName: 'A'.repeat(70) },
    });
    expect(longRes.statusCode).toBe(400);
  });

  it('7. Revokes a specific device and excludes it from active device list', async () => {
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-revoke' },
      body: { deviceId: 'dev-to-revoke', deviceName: 'Old Phone' },
    });

    const revokeRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/dev-to-revoke/revoke',
      headers: { authorization: 'Bearer mock:user-revoke' },
    });

    expect(revokeRes.statusCode).toBe(200);
    expect(revokeRes.body.success).toBe(true);

    // No longer in active list
    const listRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/devices',
      headers: { authorization: 'Bearer mock:user-revoke' },
    });
    expect(listRes.body.devices.length).toBe(0);
  });

  it('8. Revokes all other devices while preserving the current device', async () => {
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-multi' },
      body: { deviceId: 'current-dev', deviceName: 'Current Phone' },
    });
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-multi' },
      body: { deviceId: 'other-dev-1', deviceName: 'Other Laptop' },
    });
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-multi' },
      body: { deviceId: 'other-dev-2', deviceName: 'Other Tablet' },
    });

    const res = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/revoke-others',
      headers: { authorization: 'Bearer mock:user-multi' },
      body: { currentDeviceId: 'current-dev' },
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.revokedCount).toBe(2);

    // Current device is still active in list
    const listRes = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/devices',
      headers: { authorization: 'Bearer mock:user-multi' },
    });
    expect(listRes.body.devices.length).toBe(1);
    expect(listRes.body.devices[0].deviceId).toBe('current-dev');
  });

  it('9. Revoked device receives structured DEVICE_REVOKED on sync push & pull', async () => {
    // Register device
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-sync-rev' },
      body: { deviceId: 'revoked-phone', deviceName: 'Revoked Device' },
    });

    // Revoke device
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/revoked-phone/revoke',
      headers: { authorization: 'Bearer mock:user-sync-rev' },
    });

    // Attempt sync pull with X-Device-Id header
    const pullRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: {
        authorization: 'Bearer mock:user-sync-rev',
        'x-device-id': 'revoked-phone',
      },
      body: { cursor: 0 },
    });
    expect(pullRes.statusCode).toBe(403);
    expect(pullRes.body.error.code).toBe('DEVICE_REVOKED');

    // Attempt sync push with deviceId in body
    const pushRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/push',
      headers: { authorization: 'Bearer mock:user-sync-rev' },
      body: {
        deviceId: 'revoked-phone',
        changes: [{
          id: '11111111-1111-1111-1111-111111111111',
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          archived: false,
          trashed: false,
          pinned: false,
          contentCiphertext: 'ciphertext',
          contentNonce: 'nonce-12345678',
          contentVersion: 1,
          encryptionKeyVersion: 1,
        }],
      },
    });
    expect(pushRes.statusCode).toBe(403);
    expect(pushRes.body.error.code).toBe('DEVICE_REVOKED');
  });

  it('10. Repeated revoke calls are safe and idempotent', async () => {
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-idem' },
      body: { deviceId: 'dev-idem' },
    });

    const rev1 = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/dev-idem/revoke',
      headers: { authorization: 'Bearer mock:user-idem' },
    });
    expect(rev1.statusCode).toBe(200);

    const rev2 = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/dev-idem/revoke',
      headers: { authorization: 'Bearer mock:user-idem' },
    });
    expect(rev2.statusCode).toBe(200);
    expect(rev2.body.success).toBe(true);
  });

  it('11. Re-signing in un-revokes the device explicitly and allows sync again', async () => {
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-reconnect' },
      body: { deviceId: 'dev-reconnect' },
    });

    // Revoke it
    await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/dev-reconnect/revoke',
      headers: { authorization: 'Bearer mock:user-reconnect' },
    });

    // Sync is blocked
    const blockedRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: {
        authorization: 'Bearer mock:user-reconnect',
        'x-device-id': 'dev-reconnect',
      },
      body: { cursor: 0 },
    });
    expect(blockedRes.statusCode).toBe(403);
    expect(blockedRes.body.error.code).toBe('DEVICE_REVOKED');

    // User signs in again -> explicit device registration
    const reRegisterRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/devices/register',
      headers: { authorization: 'Bearer mock:user-reconnect' },
      body: { deviceId: 'dev-reconnect', deviceName: 'Reconnected Phone' },
    });
    expect(reRegisterRes.statusCode).toBe(200);
    expect(reRegisterRes.body.device.revokedAt).toBeNull();

    // Sync now succeeds!
    const successRes = await handleApiRequest({
      method: 'POST',
      url: '/api/v1/sync/pull',
      headers: {
        authorization: 'Bearer mock:user-reconnect',
        'x-device-id': 'dev-reconnect',
      },
      body: { cursor: 0 },
    });
    expect(successRes.statusCode).toBe(200);
  });

  it('12. Successfully migrates a legacy database with pre-v10 sync_devices schema without errors', async () => {
    resetGlobalClient();
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    const db = getDbClient();

    // Create minimal pre-v10 schema with users and legacy sync_devices (from migration 007)
    await db.execute(`
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        firebase_uid TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    await db.execute(`
      CREATE TABLE sync_devices (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        device_name TEXT,
        client_version TEXT,
        last_acknowledged_revision INTEGER NOT NULL DEFAULT 0,
        last_seen_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    `);
    await db.execute(`CREATE INDEX idx_sync_devices_user ON sync_devices (user_id, last_seen_at);`);

    // Insert legacy user and legacy device
    const now = new Date().toISOString();
    await db.execute({
      sql: `INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)`,
      args: ['user-legacy-1', 'user-legacy-1', now, now],
    });
    await db.execute({
      sql: `INSERT INTO sync_devices (id, user_id, device_name, client_version, last_acknowledged_revision, last_seen_at, created_at, updated_at)
            VALUES (?, ?, ?, ?, 0, ?, ?, ?)`,
      args: ['legacy-dev-123', 'user-legacy-1', 'Old Device', '1.5.0', now, now, now],
    });

    // Run migration - MUST NOT throw 'no such column' error!
    await expect(runMigrations(db)).resolves.not.toThrow();

    // Query devices via API
    const res = await handleApiRequest({
      method: 'GET',
      url: '/api/v1/devices',
      headers: { authorization: 'Bearer mock:user-legacy-1' },
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.devices).toHaveLength(1);
    expect(res.body.devices[0].deviceId).toBe('legacy-dev-123');
    expect(res.body.devices[0].deviceName).toBe('Old Device');
    expect(res.body.devices[0].appVersion).toBe('1.5.0');
    expect(res.body.devices[0].revokedAt).toBeNull();
  });
});
