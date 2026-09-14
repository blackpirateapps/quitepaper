import { Client } from '@libsql/client';
import { ApiError } from '../errors/apiError.js';
import {
  RegisterDeviceInput,
  registerDeviceSchema,
  RenameDeviceInput,
  renameDeviceSchema,
  RevokeOthersInput,
  revokeOthersSchema,
} from '../validation/schemas.js';

export interface DeviceResponse {
  id: string;
  deviceId: string;
  deviceName: string | null;
  platform: string | null;
  model: string | null;
  osVersion: string | null;
  appVersion: string | null;
  createdAt: string;
  lastActiveAt: string;
  revokedAt: string | null;
}

/**
 * Checks if a device has been revoked for the given user.
 * Throws ApiError('DEVICE_REVOKED', ...) if revoked.
 */
export async function checkDeviceRevoked(
  db: Client,
  userId: string,
  deviceId: string
): Promise<void> {
  if (!deviceId) return;

  const result = await db.execute({
    sql: `SELECT revoked_at FROM sync_devices 
          WHERE user_id = ? AND (device_id = ? OR id = ?) 
          LIMIT 1`,
    args: [userId, deviceId, deviceId],
  });

  if (result.rows.length > 0 && result.rows[0].revoked_at != null) {
    throw new ApiError(
      'DEVICE_REVOKED',
      'This device has been signed out remotely',
      403
    );
  }
}

/**
 * Registers or updates a device record for the authenticated user.
 *
 * If isExplicitRegistration is true (e.g. user actively signed in),
 * any previous revocation is cleared.
 * Otherwise, if the device was previously revoked, DEVICE_REVOKED is thrown.
 */
export async function registerOrUpdateDevice(
  db: Client,
  userId: string,
  rawInput: unknown,
  isExplicitRegistration: boolean = false
): Promise<DeviceResponse> {
  const parsed = registerDeviceSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid device registration: ${parsed.error.message}`,
      400,
      parsed.error.format()
    );
  }

  const { deviceId, deviceName, platform, model, osVersion, appVersion } = parsed.data;
  const now = new Date().toISOString();

  // Check if device already exists for this user
  const existing = await db.execute({
    sql: `SELECT id, device_id, device_name, platform, model, os_version, app_version, 
                 client_version, created_at, last_active_at, last_seen_at, revoked_at 
          FROM sync_devices 
          WHERE user_id = ? AND (device_id = ? OR id = ?) 
          LIMIT 1`,
    args: [userId, deviceId, deviceId],
  });

  if (existing.rows.length > 0) {
    const row = existing.rows[0];
    const isRevoked = row.revoked_at != null;

    if (isRevoked && !isExplicitRegistration) {
      throw new ApiError(
        'DEVICE_REVOKED',
        'This device has been signed out remotely',
        403
      );
    }

    // Update existing record
    const targetId = row.id as string;
    await db.execute({
      sql: `UPDATE sync_devices SET
              device_id = ?,
              device_name = COALESCE(?, device_name),
              platform = COALESCE(?, platform),
              model = COALESCE(?, model),
              os_version = COALESCE(?, os_version),
              app_version = COALESCE(?, app_version),
              client_version = COALESCE(?, client_version),
              last_active_at = ?,
              last_seen_at = ?,
              updated_at = ?,
              revoked_at = ?
            WHERE id = ? AND user_id = ?`,
      args: [
        deviceId,
        deviceName || null,
        platform || null,
        model || null,
        osVersion || null,
        appVersion || null,
        appVersion || null,
        now,
        now,
        now,
        isExplicitRegistration ? null : (row.revoked_at as string | null),
        targetId,
        userId,
      ],
    });
  } else {
    // Insert new device record
    const recordId = `${userId}:${deviceId}`;
    await db.execute({
      sql: `INSERT INTO sync_devices (
              id, user_id, device_id, device_name, platform, model, 
              os_version, app_version, client_version, last_acknowledged_revision, 
              last_active_at, last_seen_at, created_at, updated_at, revoked_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, NULL)
            ON CONFLICT(id) DO UPDATE SET
              device_id = excluded.device_id,
              device_name = COALESCE(excluded.device_name, sync_devices.device_name),
              platform = COALESCE(excluded.platform, sync_devices.platform),
              model = COALESCE(excluded.model, sync_devices.model),
              os_version = COALESCE(excluded.os_version, sync_devices.os_version),
              app_version = COALESCE(excluded.app_version, sync_devices.app_version),
              client_version = COALESCE(excluded.client_version, sync_devices.client_version),
              last_active_at = excluded.last_active_at,
              last_seen_at = excluded.last_seen_at,
              updated_at = excluded.updated_at`,
      args: [
        recordId,
        userId,
        deviceId,
        deviceName || null,
        platform || null,
        model || null,
        osVersion || null,
        appVersion || null,
        appVersion || null,
        now,
        now,
        now,
        now,
      ],
    });
  }

  // Fetch and return the updated record
  const updated = await db.execute({
    sql: `SELECT id, device_id, device_name, platform, model, os_version, app_version, 
                 client_version, created_at, last_active_at, last_seen_at, revoked_at 
          FROM sync_devices 
          WHERE user_id = ? AND (device_id = ? OR id = ?) 
          LIMIT 1`,
    args: [userId, deviceId, deviceId],
  });

  return mapRowToDevice(updated.rows[0]);
}

/**
 * Returns all active (non-revoked) devices for the authenticated user.
 */
export async function getDevicesForUser(
  db: Client,
  userId: string
): Promise<DeviceResponse[]> {
  const res = await db.execute({
    sql: `SELECT id, device_id, device_name, platform, model, os_version, app_version, 
                 client_version, created_at, last_active_at, last_seen_at, revoked_at 
          FROM sync_devices 
          WHERE user_id = ? AND revoked_at IS NULL 
          ORDER BY COALESCE(last_active_at, last_seen_at) DESC`,
    args: [userId],
  });

  return res.rows.map(mapRowToDevice);
}

/**
 * Renames a device belonging to the authenticated user.
 */
export async function renameDevice(
  db: Client,
  userId: string,
  deviceId: string,
  rawInput: unknown
): Promise<DeviceResponse> {
  const parsed = renameDeviceSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid device name: ${parsed.error.message}`,
      400,
      parsed.error.format()
    );
  }

  const { deviceName } = parsed.data;
  const now = new Date().toISOString();

  // Check ownership and existence
  const existing = await db.execute({
    sql: `SELECT id, device_id, revoked_at FROM sync_devices 
          WHERE user_id = ? AND (device_id = ? OR id = ?) 
          LIMIT 1`,
    args: [userId, deviceId, deviceId],
  });

  if (existing.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'Device not found', 404);
  }

  if (existing.rows[0].revoked_at != null) {
    throw new ApiError('DEVICE_REVOKED', 'Cannot rename a revoked device', 403);
  }

  await db.execute({
    sql: `UPDATE sync_devices 
          SET device_name = ?, updated_at = ? 
          WHERE user_id = ? AND (device_id = ? OR id = ?)`,
    args: [deviceName, now, userId, deviceId, deviceId],
  });

  const updated = await db.execute({
    sql: `SELECT id, device_id, device_name, platform, model, os_version, app_version, 
                 client_version, created_at, last_active_at, last_seen_at, revoked_at 
          FROM sync_devices 
          WHERE user_id = ? AND (device_id = ? OR id = ?) 
          LIMIT 1`,
    args: [userId, deviceId, deviceId],
  });

  return mapRowToDevice(updated.rows[0]);
}

/**
 * Revokes a device session belonging to the authenticated user.
 * Safe and idempotent.
 */
export async function revokeDevice(
  db: Client,
  userId: string,
  deviceId: string
): Promise<{ success: boolean; deviceId: string }> {
  // Check ownership and existence
  const existing = await db.execute({
    sql: `SELECT id, device_id, revoked_at FROM sync_devices 
          WHERE user_id = ? AND (device_id = ? OR id = ?) 
          LIMIT 1`,
    args: [userId, deviceId, deviceId],
  });

  if (existing.rows.length === 0) {
    throw new ApiError('NOT_FOUND', 'Device not found', 404);
  }

  if (existing.rows[0].revoked_at != null) {
    // Already revoked; idempotent
    return { success: true, deviceId };
  }

  const now = new Date().toISOString();
  await db.execute({
    sql: `UPDATE sync_devices 
          SET revoked_at = ?, updated_at = ? 
          WHERE user_id = ? AND (device_id = ? OR id = ?)`,
    args: [now, now, userId, deviceId, deviceId],
  });

  return { success: true, deviceId };
}

/**
 * Revokes all other active device sessions for the authenticated user,
 * excluding currentDeviceId.
 */
export async function revokeOtherDevices(
  db: Client,
  userId: string,
  rawInput: unknown
): Promise<{ success: boolean; revokedCount: number }> {
  const parsed = revokeOthersSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new ApiError(
      'BAD_REQUEST',
      `Invalid revoke-others request: ${parsed.error.message}`,
      400,
      parsed.error.format()
    );
  }

  const { currentDeviceId } = parsed.data;
  const now = new Date().toISOString();

  const result = await db.execute({
    sql: `UPDATE sync_devices 
          SET revoked_at = ?, updated_at = ? 
          WHERE user_id = ? 
            AND device_id != ? 
            AND id != ? 
            AND revoked_at IS NULL`,
    args: [now, now, userId, currentDeviceId, currentDeviceId],
  });

  return {
    success: true,
    revokedCount: result.rowsAffected ?? 0,
  };
}

function mapRowToDevice(row: any): DeviceResponse {
  const rawDeviceId = (row.device_id as string) || (row.id as string);
  return {
    id: rawDeviceId,
    deviceId: rawDeviceId,
    deviceName: (row.device_name as string) || null,
    platform: (row.platform as string) || null,
    model: (row.model as string) || null,
    osVersion: (row.os_version as string) || null,
    appVersion: (row.app_version as string) || (row.client_version as string) || null,
    createdAt: (row.created_at as string) || new Date().toISOString(),
    lastActiveAt: (row.last_active_at as string) || (row.last_seen_at as string) || new Date().toISOString(),
    revokedAt: (row.revoked_at as string) || null,
  };
}
