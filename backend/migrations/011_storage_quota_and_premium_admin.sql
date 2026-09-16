-- Quiet Paper Storage Quota, Reservations, Premium Entitlements & Admin Audit Logs Schema (v11)

-- 1. Extend users table with plan, storage counters, and email
ALTER TABLE users ADD COLUMN plan TEXT NOT NULL DEFAULT 'free';
ALTER TABLE users ADD COLUMN storage_used_bytes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN storage_reserved_bytes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN email TEXT;

-- 2. Create Storage Reservations table for atomic upload allocation & concurrency control
CREATE TABLE IF NOT EXISTS storage_reservations (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  resource_type TEXT NOT NULL, -- 'attachment' | 'document'
  resource_id TEXT NOT NULL,
  reserved_bytes INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'finalized' | 'released' | 'expired'
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  finalized_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 3. Create Admin Audit Logs table for tracking privileged account changes
CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id TEXT PRIMARY KEY,
  admin_identifier TEXT,
  user_id TEXT NOT NULL,
  action TEXT NOT NULL, -- 'PLAN_CHANGED'
  old_value TEXT,
  new_value TEXT,
  details_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 4. Create indexes for plan, email, reservations, and admin audit
CREATE INDEX IF NOT EXISTS idx_users_plan ON users (plan);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_storage_res_user ON storage_reservations (user_id, status);
CREATE INDEX IF NOT EXISTS idx_storage_res_resource ON storage_reservations (user_id, resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_storage_res_expires ON storage_reservations (status, expires_at);
CREATE INDEX IF NOT EXISTS idx_admin_audit_user ON admin_audit_logs (user_id, created_at);

-- 5. Backfill authoritative storage usage for existing users from attachments and documents
UPDATE users SET storage_used_bytes = (
  COALESCE((SELECT SUM(byte_size) FROM attachments WHERE attachments.user_id = users.id AND is_deleted = 0 AND (status IS NULL OR status != 'pending_deletion')), 0) +
  COALESCE((SELECT SUM(byte_size) FROM documents WHERE documents.user_id = users.id AND is_deleted = 0 AND (status IS NULL OR status != 'pending_deletion')), 0)
) WHERE storage_used_bytes = 0;
