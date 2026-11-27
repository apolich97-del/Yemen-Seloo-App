import { initializeApp, getApps } from 'firebase/app';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signOut,
  onAuthStateChanged,
  User,
} from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

export const firebaseConfig = {
  apiKey: 'AIzaSyA2aX5gDos7IBU3lkFM_i2nIpuAzMIsZgE',
  authDomain: 'yemen-seloo-app.firebaseapp.com',
  projectId: 'yemen-seloo-app',
  storageBucket: 'yemen-seloo-app.firebasestorage.app',
  messagingSenderId: '580529134357',
};

const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const googleProvider = new GoogleAuthProvider();
googleProvider.setCustomParameters({ prompt: 'select_account' });

export async function signInWithGoogleAccount(loginHint?: string): Promise<User> {
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters(
    loginHint
      ? { prompt: 'select_account', login_hint: loginHint }
      : { prompt: 'select_account' }
  );
  const res = await signInWithPopup(auth, provider);
  return res.user;
}

export async function signOutFirebase(): Promise<void> {
  await signOut(auth);
}

export { onAuthStateChanged };

/**
 * Compresses an uploaded image file to a lightweight base64 data URL (Spark free-plan compatible,
 * no Firebase Storage needed) kept well within Firestore document size limits.
 */
export async function compressImageToDataUrl(
  file: File,
  maxWidth = 900,
  quality = 0.72
): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('تعذر قراءة ملف الصورة'));
    reader.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error('صيغة الصورة غير مدعومة'));
      img.onload = () => {
        const scale = img.width > maxWidth ? maxWidth / img.width : 1;
        const w = Math.max(1, Math.round(img.width * scale));
        const h = Math.max(1, Math.round(img.height * scale));
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        if (!ctx) {
          resolve(String(reader.result));
          return;
        }
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, w, h);
        ctx.drawImage(img, 0, 0, w, h);
        let output = canvas.toDataURL('image/jpeg', quality);
        if (output.length > 360_000) {
          output = canvas.toDataURL('image/jpeg', 0.52);
        }
        resolve(output);
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}
