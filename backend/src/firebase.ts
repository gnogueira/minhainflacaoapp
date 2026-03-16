import * as admin from 'firebase-admin';

// Guard against double-initialization in hot-reload environments
if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const storage = admin.storage();
export { admin };
