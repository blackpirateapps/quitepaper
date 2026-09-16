import { describe, it, expect, beforeEach } from 'vitest';
import { getDbClient, resetGlobalClient } from '../src/db/client.js';
import { runMigrations } from '../src/db/migrate.js';
import { handleApiRequest } from '../src/api/handler.js';
import {
  PLAN_LIMITS,
  MAX_FILE_SIZE_BYTES,
  getUserQuotaProfile,
  reserveUploadStorage,
  commitUploadStorage,
  releaseStorageForResource,
  cleanupExpiredReservations,
  recalculateUserStorageUsage,
  reconcileUserStorageUsage,
  changeUserPlan,
} from '../src/storage/quotaService.js';
import { ApiError } from '../src/errors/apiError.js';

describe('Storage Quota, Reservations, and Entitlement Engine Tests', () => {
  beforeEach(async () => {
    resetGlobalClient();
    process.env.NODE_ENV = 'test';
    process.env.TURSO_DATABASE_URL = 'file::memory:';
    process.env.CLOUDINARY_CLOUD_NAME = 'test-cloud';
    process.env.CLOUDINARY_API_KEY = '123456789012345';
    process.env.CLOUDINARY_API_SECRET = 'abcdefghijklmnopqrstuvwxyz12345';
    process.env.CLOUDINARY_FOLDER = 'quitepaper_test';

    const db = getDbClient();
    await runMigrations(db);
  });

  describe('1. Plan Limits & Constants', () => {
    it('Defines accurate decimal storage quota and file size constants', () => {
      expect(PLAN_LIMITS.free).toBe(1_000_000_000); // 1 GB decimal
      expect(PLAN_LIMITS.premium).toBe(10_000_000_000); // 10 GB decimal
      expect(MAX_FILE_SIZE_BYTES).toBe(10_000_000); // 10 MB decimal
    });

    it('Defaults new users to Free plan with 1 GB allowance', async () => {
      const db = getDbClient();
      const userId = 'user-plan-default-test';
      const now = new Date().toISOString();
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
        args: [userId, 'fb-default-test', now, now],
      });

      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.plan).toBe('free');
      expect(profile.limitBytes).toBe(1_000_000_000);
      expect(profile.usedBytes).toBe(0);
      expect(profile.reservedBytes).toBe(0);
      expect(profile.remainingBytes).toBe(1_000_000_000);
      expect(profile.isOverQuota).toBe(false);
      expect(profile.maxFileSizeBytes).toBe(10_000_000);
    });

    it('Exposes 10 GB limit for Premium users', async () => {
      const db = getDbClient();
      const userId = 'user-premium-test';
      const now = new Date().toISOString();
      await db.execute({
        sql: "INSERT INTO users (id, firebase_uid, plan, created_at, updated_at) VALUES (?, ?, 'premium', ?, ?)",
        args: [userId, 'fb-premium-test', now, now],
      });

      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.plan).toBe('premium');
      expect(profile.limitBytes).toBe(10_000_000_000);
      expect(profile.remainingBytes).toBe(10_000_000_000);
      expect(profile.maxFileSizeBytes).toBe(10_000_000);
    });
  });

  describe('2. File Size Enforcement', () => {
    it('Accepts file sizes up to exactly 10 MB (10,000,000 bytes)', async () => {
      const attachmentId = '11111111-1111-1111-1111-111111111111';
      const res = await handleApiRequest({
        method: 'POST',
        url: '/api/v1/attachments/upload-auth',
        headers: { authorization: 'Bearer mock:user-size-valid' },
        body: {
          attachmentId,
          mimeType: 'image/png',
          byteSize: 10_000_000,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          variant: 'original',
        },
      });

      expect(res.statusCode).toBe(200);
      expect(res.body.uploadUrl).toBeDefined();
    });

    it('Rejects file sizes greater than 10 MB with FILE_TOO_LARGE for Free users', async () => {
      const attachmentId = '22222222-2222-2222-2222-222222222222';
      const res = await handleApiRequest({
        method: 'POST',
        url: '/api/v1/attachments/upload-auth',
        headers: { authorization: 'Bearer mock:user-size-overflow' },
        body: {
          attachmentId,
          mimeType: 'image/png',
          byteSize: 10_000_001,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          variant: 'original',
        },
      });

      expect(res.statusCode).toBe(400);
      expect(res.body.error.code).toBe('FILE_TOO_LARGE');
      expect(res.body.error.details.maxBytes).toBe(10_000_000);
      expect(res.body.error.details.providedBytes).toBe(10_000_001);
    });

    it('Rejects file sizes greater than 10 MB for Premium users (Premium does NOT bypass 10 MB limit)', async () => {
      const db = getDbClient();
      const userId = 'user-premium-filesize-check';
      const now = new Date().toISOString();
      await db.execute({
        sql: "INSERT INTO users (id, firebase_uid, plan, created_at, updated_at) VALUES (?, ?, 'premium', ?, ?)",
        args: [userId, 'fb-premium-filesize', now, now],
      });

      const documentId = '33333333-3333-3333-3333-333333333333';
      const res = await handleApiRequest({
        method: 'POST',
        url: '/api/v1/documents/upload-auth',
        headers: { authorization: 'Bearer mock:fb-premium-filesize' },
        body: {
          documentId,
          byteSize: 12_000_000,
          pageCount: 5,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          title: 'Large Scanned Document.pdf',
        },
      });

      expect(res.statusCode).toBe(400);
      expect(res.body.error.code).toBe('FILE_TOO_LARGE');
      expect(res.body.error.details.maxBytes).toBe(10_000_000);
      expect(res.body.error.details.providedBytes).toBe(12_000_000);
    });
  });

  describe('3. Quota Enforcement & Upload Reservations Lifecycle', () => {
    it('Creates upload reservation and increments storage_reserved_bytes', async () => {
      const db = getDbClient();
      const userId = 'user-res-lifecycle-1';
      const now = new Date().toISOString();
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
        args: [userId, 'fb-res-1', now, now],
      });

      const reservation = await reserveUploadStorage(
        db,
        userId,
        'attachment',
        'att-1',
        5_000_000
      );

      expect(reservation.reservedBytes).toBe(5_000_000);

      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.reservedBytes).toBe(5_000_000);
      expect(profile.usedBytes).toBe(0);
      expect(profile.remainingBytes).toBe(995_000_000);
    });

    it('Rejects upload reservation when requested size exceeds available quota', async () => {
      const db = getDbClient();
      const userId = 'user-quota-exceeded-test';
      const now = new Date().toISOString();
      // Set used bytes to 995 MB (5 MB remaining on 1 GB free plan)
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, storage_used_bytes, created_at, updated_at) VALUES (?, ?, 995000000, ?, ?)',
        args: [userId, 'fb-quota-exceeded', now, now],
      });

      // Try to reserve 6 MB (which exceeds remaining 5 MB)
      let thrownError: any = null;
      try {
        await reserveUploadStorage(
          db,
          userId,
          'attachment',
          'att-overflow',
          6_000_000
        );
      } catch (err) {
        thrownError = err;
      }

      expect(thrownError).toBeInstanceOf(ApiError);
      expect(thrownError.code).toBe('STORAGE_QUOTA_EXCEEDED');
      expect(thrownError.details.plan).toBe('free');
      expect(thrownError.details.usedBytes).toBe(995_000_000);
      expect(thrownError.details.remainingBytes).toBe(5_000_000);
      expect(thrownError.details.requiredBytes).toBe(6_000_000);
    });

    it('Converts reservation to committed storage on upload confirmation', async () => {
      const db = getDbClient();
      const userId = 'user-confirm-test';
      const now = new Date().toISOString();
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
        args: [userId, 'fb-confirm-test', now, now],
      });

      await reserveUploadStorage(
        db,
        userId,
        'attachment',
        'att-confirm-1',
        4_000_000
      );

      await commitUploadStorage(
        db,
        userId,
        'attachment',
        'att-confirm-1',
        4_000_000
      );

      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes).toBe(4_000_000);
      expect(profile.reservedBytes).toBe(0);
      expect(profile.remainingBytes).toBe(996_000_000);
    });

    it('Duplicate confirmation is idempotent and does not double-count storage', async () => {
      const db = getDbClient();
      const userId = 'user-dup-confirm-test';
      const now = new Date().toISOString();
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
        args: [userId, 'fb-dup-confirm', now, now],
      });

      await reserveUploadStorage(
        db,
        userId,
        'attachment',
        'att-dup-1',
        3_000_000
      );

      // First confirmation
      await commitUploadStorage(
        db,
        userId,
        'attachment',
        'att-dup-1',
        3_000_000
      );

      // Second duplicate confirmation (e.g. network retry)
      await commitUploadStorage(
        db,
        userId,
        'attachment',
        'att-dup-1',
        3_000_000
      );

      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes).toBe(3_000_000);
      expect(profile.reservedBytes).toBe(0);
    });

    it('Cleans up expired reservations and releases reserved bytes', async () => {
      const db = getDbClient();
      const userId = 'user-expired-res-test';
      const now = new Date().toISOString();
      const pastTime = new Date(Date.now() - 3600 * 1000).toISOString(); // 1 hour ago
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, storage_reserved_bytes, created_at, updated_at) VALUES (?, ?, 2000000, ?, ?)',
        args: [userId, 'fb-expired-res', now, now],
      });

      // Insert expired reservation record
      await db.execute({
        sql: "INSERT INTO storage_reservations (id, user_id, resource_type, resource_id, reserved_bytes, status, created_at, expires_at) VALUES ('res-exp-1', ?, 'attachment', 'att-abandoned', 2000000, 'pending', ?, ?)",
        args: [userId, pastTime, pastTime],
      });

      const cleanedCount = await cleanupExpiredReservations(db);
      expect(cleanedCount).toBe(1);

      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.reservedBytes).toBe(0);

      // Verify reservation status transitioned to expired
      const resRow = (await db.execute("SELECT status FROM storage_reservations WHERE id = 'res-exp-1'")).rows[0];
      expect(resRow.status).toBe('expired');
    });
  });

  describe('4. Concurrency Guard & Atomic Quota Protection', () => {
    it('Prevents race condition when concurrent uploads exceed remaining capacity', async () => {
      const db = getDbClient();
      const userId = 'user-concurrent-test';
      const now = new Date().toISOString();
      // 1 GB limit, start with 990 MB used (10 MB remaining)
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, storage_used_bytes, created_at, updated_at) VALUES (?, ?, 990000000, ?, ?)',
        args: [userId, 'fb-concurrent', now, now],
      });

      // Simulate two concurrent upload requests, each requesting 7 MB (total 14 MB > 10 MB remaining)
      const results = await Promise.allSettled([
        reserveUploadStorage(
          db,
          userId,
          'attachment',
          'att-conc-1',
          7_000_000
        ),
        reserveUploadStorage(
          db,
          userId,
          'attachment',
          'att-conc-2',
          7_000_000
        ),
      ]);

      const fulfilled = results.filter(r => r.status === 'fulfilled');
      const rejected = results.filter(r => r.status === 'rejected');

      expect(fulfilled.length).toBe(1);
      expect(rejected.length).toBe(1);

      const rejectedError = (rejected[0] as PromiseRejectedResult).reason;
      expect(rejectedError).toBeInstanceOf(ApiError);
      expect(rejectedError.code).toBe('STORAGE_QUOTA_EXCEEDED');

      // Check total combined usage + reservation does not exceed 1 GB
      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes + profile.reservedBytes).toBeLessThanOrEqual(1_000_000_000);
      expect(profile.reservedBytes).toBe(7_000_000);
    });
  });

  describe('5. Storage Deltas, Replacements & Deletions', () => {
    it('Adjusts quota by delta when replacing file with a larger version', async () => {
      const db = getDbClient();
      const userId = 'user-replace-larger';
      const now = new Date().toISOString();
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
        args: [userId, 'fb-replace-larger', now, now],
      });

      // Initial upload: 4 MB
      await reserveUploadStorage(db, userId, 'attachment', 'att-rep', 4_000_000);
      await commitUploadStorage(db, userId, 'attachment', 'att-rep', 4_000_000);

      let profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes).toBe(4_000_000);

      // Re-upload / update to 7 MB (+3 MB delta)
      await reserveUploadStorage(db, userId, 'attachment', 'att-rep', 7_000_000, 4_000_000);
      
      profile = await getUserQuotaProfile(db, userId);
      expect(profile.reservedBytes).toBe(3_000_000); // Only delta 3 MB reserved

      await commitUploadStorage(db, userId, 'attachment', 'att-rep', 7_000_000, 4_000_000);

      profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes).toBe(7_000_000);
      expect(profile.reservedBytes).toBe(0);
    });

    it('Adjusts quota by delta when replacing file with a smaller version', async () => {
      const db = getDbClient();
      const userId = 'user-replace-smaller';
      const now = new Date().toISOString();
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, created_at, updated_at) VALUES (?, ?, ?, ?)',
        args: [userId, 'fb-replace-smaller', now, now],
      });

      // Initial upload: 8 MB
      await reserveUploadStorage(db, userId, 'attachment', 'att-small-rep', 8_000_000);
      await commitUploadStorage(db, userId, 'attachment', 'att-small-rep', 8_000_000);

      // Update to 3 MB (-5 MB delta)
      await reserveUploadStorage(db, userId, 'attachment', 'att-small-rep', 3_000_000, 8_000_000);
      await commitUploadStorage(db, userId, 'attachment', 'att-small-rep', 3_000_000, 8_000_000);

      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes).toBe(3_000_000);
      expect(profile.reservedBytes).toBe(0);
    });

    it('Reclaims storage on deletion without dropping below zero', async () => {
      const db = getDbClient();
      const userId = 'user-delete-reclaim';
      const now = new Date().toISOString();
      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, storage_used_bytes, created_at, updated_at) VALUES (?, ?, 5000000, ?, ?)',
        args: [userId, 'fb-delete-reclaim', now, now],
      });

      await releaseStorageForResource(
        db,
        userId,
        'attachment',
        'att-del-test',
        5_000_000
      );

      let profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes).toBe(0);

      // Repeated deletion should not make counter negative
      await releaseStorageForResource(
        db,
        userId,
        'attachment',
        'att-del-test',
        5_000_000
      );

      profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes).toBe(0);
    });
  });

  describe('6. Plan Transitions & Over-Quota Retention', () => {
    it('Retains existing data when Premium user with >1 GB is downgraded to Free', async () => {
      const db = getDbClient();
      const userId = 'user-downgrade-test';
      const now = new Date().toISOString();
      // Premium user with 3 GB stored
      await db.execute({
        sql: "INSERT INTO users (id, firebase_uid, plan, storage_used_bytes, created_at, updated_at) VALUES (?, ?, 'premium', 3000000000, ?, ?)",
        args: [userId, 'fb-downgrade', now, now],
      });

      // Downgrade to Free
      const result = await changeUserPlan(
        db,
        userId,
        'free',
        {
          adminIdentifier: 'admin@quietpaper.test',
          reason: 'Subscription ended',
        }
      );

      expect(result.quota.plan).toBe('free');
      expect(result.quota.usedBytes).toBe(3_000_000_000);
      expect(result.quota.limitBytes).toBe(1_000_000_000);
      expect(result.quota.isOverQuota).toBe(true);
      expect(result.quota.overQuotaBytes).toBe(2_000_000_000);
      expect(result.quota.remainingBytes).toBe(0);

      // Verify audit log entry was created
      const auditLog = (await db.execute({
        sql: "SELECT * FROM admin_audit_logs WHERE user_id = ? AND action = 'PLAN_CHANGED'",
        args: [userId],
      })).rows[0];
      expect(auditLog).toBeDefined();
      expect(auditLog.old_value).toBe('premium');
      expect(auditLog.new_value).toBe('free');
      expect(auditLog.admin_identifier).toBe('admin@quietpaper.test');
    });

    it('Blocks new uploads when account is over quota but allows upgrade to restore uploads', async () => {
      const db = getDbClient();
      const userId = 'user-overquota-block';
      const now = new Date().toISOString();
      await db.execute({
        sql: "INSERT INTO users (id, firebase_uid, plan, storage_used_bytes, created_at, updated_at) VALUES (?, ?, 'free', 2000000000, ?, ?)",
        args: [userId, 'fb-overquota-block', now, now],
      });

      // Upload attempt while over quota should fail
      const authRes = await handleApiRequest({
        method: 'POST',
        url: '/api/v1/attachments/upload-auth',
        headers: { authorization: 'Bearer mock:fb-overquota-block' },
        body: {
          attachmentId: '44444444-4444-4444-4444-444444444444',
          mimeType: 'image/png',
          byteSize: 1024,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          variant: 'original',
        },
      });

      expect(authRes.statusCode).toBe(400);
      expect(authRes.body.error.code).toBe('STORAGE_QUOTA_EXCEEDED');

      // Admin upgrades user to Premium (10 GB)
      await changeUserPlan(
        db,
        userId,
        'premium',
        {
          adminIdentifier: 'admin@quietpaper.test',
        }
      );

      // Retry upload after upgrade: should now succeed!
      const authRes2 = await handleApiRequest({
        method: 'POST',
        url: '/api/v1/attachments/upload-auth',
        headers: { authorization: 'Bearer mock:fb-overquota-block' },
        body: {
          attachmentId: '55555555-5555-5555-5555-555555555555',
          mimeType: 'image/png',
          byteSize: 1024,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          variant: 'original',
        },
      });

      expect(authRes2.statusCode).toBe(200);
      expect(authRes2.body.uploadUrl).toBeDefined();
    });
  });

  describe('7. Storage Profile API Endpoint', () => {
    it('GET /api/v1/account/storage returns comprehensive profile for authenticated user', async () => {
      const res = await handleApiRequest({
        method: 'GET',
        url: '/api/v1/account/storage',
        headers: { authorization: 'Bearer mock:user-storage-api' },
      });

      expect(res.statusCode).toBe(200);
      expect(res.body.plan).toBe('free');
      expect(res.body.usedBytes).toBe(0);
      expect(res.body.reservedBytes).toBe(0);
      expect(res.body.limitBytes).toBe(1_000_000_000);
      expect(res.body.remainingBytes).toBe(1_000_000_000);
      expect(res.body.usageFraction).toBe(0);
      expect(res.body.isOverQuota).toBe(false);
      expect(res.body.maxFileSizeBytes).toBe(10_000_000);
    });

    it('GET /api/v1/account/storage rejects unauthenticated request with 401', async () => {
      const res = await handleApiRequest({
        method: 'GET',
        url: '/api/v1/account/storage',
      });

      expect(res.statusCode).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });
  });

  describe('8. Reconciliation & Migration Backfill', () => {
    it('Recalculates and reconciles storage accurately across attachments and documents', async () => {
      const db = getDbClient();
      const userId = 'user-reconcile-test';
      const now = new Date().toISOString();

      await db.execute({
        sql: 'INSERT INTO users (id, firebase_uid, storage_used_bytes, created_at, updated_at) VALUES (?, ?, 0, ?, ?)',
        args: [userId, 'fb-reconcile-test', now, now],
      });

      // Insert 2 attachments (1000 bytes and 2000 bytes)
      await db.execute({
        sql: "INSERT INTO attachments (id, user_id, mime_type, byte_size, sha256, is_deleted, status, created_at, updated_at) VALUES ('att-r1', ?, 'image/png', 1000, 'hash1', 0, 'referenced', ?, ?)",
        args: [userId, now, now],
      });
      await db.execute({
        sql: "INSERT INTO attachments (id, user_id, mime_type, byte_size, sha256, is_deleted, status, created_at, updated_at) VALUES ('att-r2', ?, 'image/jpeg', 2000, 'hash2', 0, 'referenced', ?, ?)",
        args: [userId, now, now],
      });

      // Insert 1 document (5000 bytes)
      await db.execute({
        sql: "INSERT INTO documents (id, user_id, title, mime_type, byte_size, sha256, is_deleted, status, created_at, updated_at) VALUES ('doc-r1', ?, 'Test Doc', 'application/pdf', 5000, 'hash3', 0, 'referenced', ?, ?)",
        args: [userId, now, now],
      });

      // Insert 1 deleted attachment (should NOT be counted)
      await db.execute({
        sql: "INSERT INTO attachments (id, user_id, mime_type, byte_size, sha256, is_deleted, status, created_at, updated_at) VALUES ('att-del', ?, 'image/png', 9000, 'hash4', 1, 'pending_deletion', ?, ?)",
        args: [userId, now, now],
      });

      const recomputed = await recalculateUserStorageUsage(db, userId);
      expect(recomputed.authoritativeUsedBytes).toBe(8000); // 1000 + 2000 + 5000
      expect(recomputed.authoritativeReservedBytes).toBe(0);

      const reconResult = await reconcileUserStorageUsage(db, userId, false);
      expect(reconResult.previousUsedBytes).toBe(0);
      expect(reconResult.newUsedBytes).toBe(8000);
      expect(reconResult.discrepancyFixed).toBe(true);

      const profile = await getUserQuotaProfile(db, userId);
      expect(profile.usedBytes).toBe(8000);
    });
  });
});
