-- Quiet Paper Devices & Sessions Schema (v10)

-- Add device metadata and revocation columns to sync_devices
ALTER TABLE sync_devices ADD COLUMN device_id TEXT;
ALTER TABLE sync_devices ADD COLUMN platform TEXT;
ALTER TABLE sync_devices ADD COLUMN model TEXT;
ALTER TABLE sync_devices ADD COLUMN os_version TEXT;
ALTER TABLE sync_devices ADD COLUMN app_version TEXT;
ALTER TABLE sync_devices ADD COLUMN last_active_at TEXT;
ALTER TABLE sync_devices ADD COLUMN revoked_at TEXT;

-- Backfill device_id from id for existing records if null
UPDATE sync_devices SET device_id = id WHERE device_id IS NULL;
UPDATE sync_devices SET app_version = client_version WHERE app_version IS NULL AND client_version IS NOT NULL;
UPDATE sync_devices SET last_active_at = last_seen_at WHERE last_active_at IS NULL AND last_seen_at IS NOT NULL;

-- Create indexes for device management, user lookups, active sessions, and revocation
CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_devices_user_device ON sync_devices (user_id, device_id);
CREATE INDEX IF NOT EXISTS idx_sync_devices_user_revoked ON sync_devices (user_id, revoked_at);
CREATE INDEX IF NOT EXISTS idx_sync_devices_user_active ON sync_devices (user_id, last_active_at);
