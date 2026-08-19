import { getDbClient, ensureDbInitialized } from '../db/client.js';
import { requireFirebaseAuth } from '../auth/middleware.js';
import { getEncryptionKey, putEncryptionKey } from '../keys/keyService.js';
import { pushSyncChanges, pullSyncChanges, getLatestCursor } from '../sync/syncService.js';
import {
  authorizeAttachmentUpload,
  confirmAttachmentUpload,
  getAttachmentMetadata,
} from '../attachments/attachmentService.js';
import { ApiError } from '../errors/apiError.js';

export interface RequestLike {
  method?: string;
  url?: string;
  headers: Record<string, string | string[] | undefined>;
  body?: any;
}

export interface ResponseLike {
  statusCode: number;
  headers: Record<string, string>;
  body: any;
}

export async function handleApiRequest(req: RequestLike): Promise<ResponseLike> {
  const method = (req.method || 'GET').toUpperCase();
  const rawUrl = req.url || '/';
  const pathname = rawUrl.split('?')[0];

  const db = getDbClient();

  const authHeader = Array.isArray(req.headers['authorization'])
    ? req.headers['authorization'][0]
    : req.headers['authorization'] || req.headers['Authorization'] as string | undefined;

  try {
    // Health check
    if (pathname === '/api/v1/health' || pathname === '/health') {
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: { status: 'ok', service: 'quietpaper-sync' },
      };
    }

    // Public client configuration for Firebase Auth
    if ((pathname === '/api/v1/config' || pathname === '/config') && method === 'GET') {
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: {
          firebaseApiKey: process.env.FIREBASE_API_KEY || process.env.FIREBASE_WEB_API_KEY || '',
          firebaseProjectId: process.env.FIREBASE_PROJECT_ID || '',
        },
      };
    }

    // Auto-run schema migrations on database if not already initialized
    await ensureDbInitialized(db);

    // Protected endpoints require Firebase Auth token
    const authContext = await requireFirebaseAuth(authHeader, db);
    const userId = authContext.user.id;

    // GET /api/v1/account
    if (pathname === '/api/v1/account' && method === 'GET') {
      const cursor = await getLatestCursor(db, userId);
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: {
          user: {
            id: authContext.user.id,
            firebaseUid: authContext.user.firebaseUid,
            email: authContext.user.email,
          },
          syncCursor: cursor,
        },
      };
    }

    // GET /api/v1/keys
    if (pathname === '/api/v1/keys' && method === 'GET') {
      const keyData = await getEncryptionKey(db, userId);
      if (!keyData) {
        throw new ApiError('NOT_FOUND', 'No encryption key configured for user', 404);
      }
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: keyData,
      };
    }

    // PUT /api/v1/keys
    if (pathname === '/api/v1/keys' && (method === 'PUT' || method === 'POST')) {
      const savedKey = await putEncryptionKey(db, userId, req.body);
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: savedKey,
      };
    }

    // POST /api/v1/sync/push
    if (pathname === '/api/v1/sync/push' && method === 'POST') {
      const pushResult = await pushSyncChanges(db, userId, req.body);
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: pushResult,
      };
    }

    // POST /api/v1/sync/pull
    if (pathname === '/api/v1/sync/pull' && method === 'POST') {
      const pullResult = await pullSyncChanges(db, userId, req.body);
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: pullResult,
      };
    }

    // GET /api/v1/sync/cursor
    if (pathname === '/api/v1/sync/cursor' && method === 'GET') {
      const cursor = await getLatestCursor(db, userId);
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: { cursor },
      };
    }

    // POST /api/v1/attachments/upload-auth
    if (pathname === '/api/v1/attachments/upload-auth' && method === 'POST') {
      const uploadAuth = await authorizeAttachmentUpload(db, userId, req.body);
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: uploadAuth,
      };
    }

    // POST /api/v1/attachments/confirm
    if (pathname === '/api/v1/attachments/confirm' && method === 'POST') {
      const confirmResult = await confirmAttachmentUpload(db, userId, req.body);
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: confirmResult,
      };
    }

    // GET /api/v1/attachments/:id
    if (pathname.startsWith('/api/v1/attachments/') && method === 'GET') {
      const attachmentId = pathname.substring('/api/v1/attachments/'.length);
      if (attachmentId) {
        const meta = await getAttachmentMetadata(db, userId, attachmentId);
        return {
          statusCode: 200,
          headers: { 'Content-Type': 'application/json' },
          body: meta,
        };
      }
    }

    throw new ApiError('NOT_FOUND', `Endpoint not found: ${method} ${pathname}`, 404);
  } catch (err: any) {
    if (err instanceof ApiError) {
      return {
        statusCode: err.statusCode,
        headers: { 'Content-Type': 'application/json' },
        body: err.toJSON(),
      };
    }

    console.error('[API 500 UNHANDLED ERROR]', method, pathname, err);

    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: {
        error: {
          code: 'INTERNAL_ERROR',
          message: err?.message || 'An internal server error occurred.',
          details: err?.stack || err?.toString(),
        },
      },
    };
  }
}
