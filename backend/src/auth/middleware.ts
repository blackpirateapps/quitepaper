import { Client } from '@libsql/client';
import { ApiError } from '../errors/apiError.js';
import { verifyFirebaseIdToken } from './firebase.js';
import crypto from 'crypto';

export interface AuthenticatedUser {
  id: string;
  firebaseUid: string;
  email?: string;
}

export interface AuthContext {
  user: AuthenticatedUser;
}

export async function requireFirebaseAuth(
  authHeader: string | undefined | null,
  db: Client
): Promise<AuthContext> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new ApiError('UNAUTHORIZED', 'Missing or malformed Authorization header. Expected Bearer token.', 401);
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    throw new ApiError('UNAUTHORIZED', 'Empty Bearer token provided.', 401);
  }

  let verified: { uid: string; email?: string };
  try {
    verified = await verifyFirebaseIdToken(token);
  } catch (err: any) {
    throw new ApiError('UNAUTHORIZED', `Invalid or expired Firebase ID token: ${err.message}`, 401);
  }

  const firebaseUid = verified.uid;

  // Derive canonical internal user from database scoped exclusively by verified Firebase UID
  const existingUserResult = await db.execute({
    sql: 'SELECT id, firebase_uid, email FROM users WHERE firebase_uid = ? LIMIT 1',
    args: [firebaseUid],
  });

  let userId: string;

  if (existingUserResult.rows.length > 0) {
    const row = existingUserResult.rows[0];
    userId = row.id as string;
    const currentEmail = (row.email as string) || null;
    if (verified.email && verified.email !== currentEmail) {
      await db.execute({
        sql: 'UPDATE users SET email = ?, updated_at = ? WHERE id = ?',
        args: [verified.email, new Date().toISOString(), userId],
      });
    }
  } else {
    // First time login: create canonical internal user record server-side
    userId = crypto.randomUUID();
    const now = new Date().toISOString();
    await db.execute({
      sql: 'INSERT INTO users (id, firebase_uid, email, plan, storage_used_bytes, storage_reserved_bytes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      args: [userId, firebaseUid, verified.email || null, 'free', 0, 0, now, now],
    });
  }

  return {
    user: {
      id: userId,
      firebaseUid,
      email: verified.email,
    },
  };
}
