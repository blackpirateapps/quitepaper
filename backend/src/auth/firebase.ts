import admin from 'firebase-admin';
import * as dotenv from 'dotenv';
dotenv.config();

let initialized = false;

export function initFirebaseAdmin(): admin.app.App {
  if (!initialized && admin.apps.length === 0) {
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
        admin.initializeApp({
          credential: admin.credential.cert({
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
      admin.initializeApp();
    } else {
      // Default placeholder app for development/mocking
      admin.initializeApp({
        projectId: projectId || 'quietpaper-demo',
      });
    }
    initialized = true;
  }
  return admin.app();
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
  const decoded = await admin.auth().verifyIdToken(token, true);
  return {
    uid: decoded.uid,
    email: decoded.email,
  };
}
