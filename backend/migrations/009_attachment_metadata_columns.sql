-- Add file_name and kind columns to attachments table for generic file metadata sync
-- These columns store the original filename and attachment classification kind
-- so that pulled attachments on new devices retain their correct identity.

ALTER TABLE attachments ADD COLUMN file_name TEXT NOT NULL DEFAULT 'attachment';
ALTER TABLE attachments ADD COLUMN kind TEXT NOT NULL DEFAULT 'image';
