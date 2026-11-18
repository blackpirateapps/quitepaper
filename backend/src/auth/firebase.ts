import { cert, getApp, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import * as dotenv from 'dotenv';
dotenv.config();

let initialized = false;

export function initFirebaseAdmin(): App {
  if (!initialized && getApps().length === 0) {
    let privateKey = process.env.FIREBASE_PRIVATE_KEY;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const projectId = process.env.FIREBASE_PROJECT_ID;

    if (privateKey && clientEmail) {
      privateKey = privateKey.trim();
      if ((privateKey.startsWith('"') && privateKey.endsWith('"')) ||
          (privateKey.startsWith("'") && privateKey.endsWith("'"))) {
        privateKey = privateKey.slice(1, -1);
      }
      privateKey = privateKey.replace(/\\n/g, '\n');

      try {
        initializeApp({
          credential: cert({
            projectId: projectId || undefined,
            clientEmail: clientEmail.trim(),
            privateKey,
          }),
        });
      } catch (e: any) {
        console.error('Failed to initialize Firebase Admin cert:', e?.message);
        throw e;
      }
    } else if (process.env.FIREBASE_CONFIG || process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      initializeApp();
    } else {
      // Default placeholder app for development/mocking
      initializeApp({
        projectId: projectId || 'quietpaper-demo',
      });
    }
    initialized = true;
  }
  return getApp();
}

export async function verifyFirebaseIdToken(token: string): Promise<{ uid: string; email?: string }> {
  // Test / Emulator mock hook for offline deterministic tests
  if (process.env.NODE_ENV === 'test' || process.env.MOCK_AUTH === 'true') {
    if (token.startsWith('mock:')) {
      const uid = token.replace('mock:', '');
      if (!uid) throw new Error('Invalid mock token');
      return { uid, email: `${uid}@test.local` };
    }
  }

  initFirebaseAdmin();
  const decoded = await getAuth().verifyIdToken(token, true);
  return {
    uid: decoded.uid,
    email: decoded.email,
  };
}
