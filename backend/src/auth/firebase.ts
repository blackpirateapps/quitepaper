import admin from 'firebase-admin';
import * as dotenv from 'dotenv';
dotenv.config();

let initialized = false;

export function initFirebaseAdmin(): admin.app.App {
  if (!initialized && admin.apps.length === 0) {
    if (process.env.FIREBASE_PRIVATE_KEY && process.env.FIREBASE_CLIENT_EMAIL) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        }),
      });
    } else if (process.env.FIREBASE_CONFIG || process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp();
    } else {
      // Default placeholder app for development/mocking
      admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'quietpaper-demo',
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
