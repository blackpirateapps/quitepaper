import { z } from 'zod';

export const kdfParametersSchema = z.object({
  memory: z.number().int().min(1024).max(1024 * 1024).default(19 * 1024),
  iterations: z.number().int().min(1).max(50).default(2),
  parallelism: z.number().int().min(1).max(16).default(1),
  hashLength: z.number().int().min(16).max(64).default(32),
});

export const wrappedKeySchema = z.object({
  keyVersion: z.number().int().min(1),
  wrappedMasterKey: z.string().min(16).max(2048),
  wrappedNonce: z.string().min(12).max(256),
  kdfAlgorithm: z.literal('argon2id'),
  kdfSalt: z.string().min(8).max(256),
  kdfParameters: kdfParametersSchema,
  encryptionFormatVersion: z.number().int().min(1).default(1),
  recoveryWrappedMasterKey: z.string().min(16).max(2048).optional(),
  recoveryNonce: z.string().min(12).max(256).optional(),
  recoverySalt: z.string().min(8).max(256).optional(),
  recoveryParameters: kdfParametersSchema.optional(),
  keyAuthCommitment: z.string().min(16).max(256).optional(),
});

export const noteChangeSchema = z.object({
  id: z.string().uuid(),
  createdAt: z.string().datetime({ offset: true }).or(z.string()),
  updatedAt: z.string().datetime({ offset: true }).or(z.string()),
  archived: z.boolean().default(false),
  trashed: z.boolean().default(false),
  pinned: z.boolean().default(false),
  folderId: z.string().max(128).optional().nullable(),
  sortOrder: z.number().optional().nullable(),
  contentCiphertext: z.string().max(10 * 1024 * 1024).default(''),
  contentNonce: z.string().max(256).default(''),
  contentVersion: z.number().int().min(1).default(1),
  encryptionKeyVersion: z.number().int().min(1).default(1),
  baseRevision: z.number().int().min(0).optional().nullable(),
  isDeleted: z.boolean().optional().default(false),
  deletedAt: z.string().datetime({ offset: true }).or(z.string()).optional().nullable(),
}).superRefine((data, ctx) => {
  if (!data.isDeleted && !data.deletedAt) {
    if (!data.contentCiphertext || data.contentCiphertext.length < 1) {
      ctx.addIssue({
        code: z.ZodIssueCode.too_small,
        minimum: 1,
        type: 'string',
        inclusive: true,
        message: 'String must contain at least 1 character(s)',
        path: ['contentCiphertext'],
      });
    }
    if (!data.contentNonce || data.contentNonce.length < 12) {
      ctx.addIssue({
        code: z.ZodIssueCode.too_small,
        minimum: 12,
        type: 'string',
        inclusive: true,
        message: 'String must contain at least 12 character(s)',
        path: ['contentNonce'],
      });
    }
  }
});

export const pushSyncSchema = z.object({
  idempotencyKey: z.string().min(8).max(128).optional(),
  deviceId: z.string().max(128).optional(),
  changes: z.array(noteChangeSchema).min(1).max(100), // Max 100 changes per batch
});

export const pullSyncSchema = z.object({
  cursor: z.number().int().min(0).default(0),
  limit: z.number().int().min(1).max(200).default(100),
});

export const uploadAuthRequestSchema = z.object({
  attachmentId: z.string().uuid(),
  noteId: z.string().uuid().optional(),
  mimeType: z.string().max(100).default('image/png'),
  byteSize: z.number().int().min(0).max(50 * 1024 * 1024).default(0),
  sha256: z.string().max(128).default(''),
  variant: z.string().max(50).default('original'),
});

export const confirmAttachmentSchema = z.object({
  attachmentId: z.string().uuid(),
  noteId: z.string().uuid().optional(),
  cloudPublicId: z.string().min(1).max(256),
  cloudUrl: z.string().url().max(1024),
  mimeType: z.string().max(100).optional(),
  byteSize: z.number().int().min(0).optional(),
  sha256: z.string().max(128).optional(),
  width: z.number().int().min(1).optional(),
  height: z.number().int().min(1).optional(),
});

export type WrappedKeyInput = z.infer<typeof wrappedKeySchema>;
export type NoteChangeInput = z.infer<typeof noteChangeSchema>;
export type PushSyncInput = z.infer<typeof pushSyncSchema>;
export type PullSyncInput = z.infer<typeof pullSyncSchema>;
export type UploadAuthRequestInput = z.infer<typeof uploadAuthRequestSchema>;
export type ConfirmAttachmentInput = z.infer<typeof confirmAttachmentSchema>;
