import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { User } from '../models/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let isFirebaseInitialized = false;

try {
  let credential = null;

  if (process.env.FIREBASE_PRIVATE_KEY && process.env.FIREBASE_CLIENT_EMAIL) {
    credential = admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    });
  } else {
    const serviceAccountPath = path.resolve(__dirname, '../config/firebase-service-account.json');
    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
      credential = admin.credential.cert(serviceAccount);
    }
  }

  if (credential) {
    admin.initializeApp({ credential });
    isFirebaseInitialized = true;
    console.log('✅ Firebase Admin SDK initialized successfully');
  } else {
    console.warn('⚠️ Firebase credentials not found in env or config. Push notifications will be skipped.');
  }
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
}

/**
 * Gửi Push Notification trực tiếp đến điện thoại người dùng qua FCM Token
 * @param {string} userId - ID của user nhận thông báo
 * @param {string} title - Tiêu đề thông báo
 * @param {string} body - Nội dung thông báo
 * @param {object} data - Dữ liệu kèm theo (payload)
 */
export const sendPushToUser = async (userId, title, body, data = {}) => {
  if (!isFirebaseInitialized) {
    return { success: false, message: 'Firebase Admin chưa được khởi tạo' };
  }

  try {
    const user = await User.findById(userId).select('fcmToken fullName');
    if (!user || !user.fcmToken) {
      console.log(`ℹ️ User ${userId} chưa đăng ký FCM token trên điện thoại, bỏ qua push.`);
      return { success: false, message: 'User does not have an FCM token' };
    }

    // Chuyển toàn bộ value trong data thành String vì FCM chỉ nhận String key-value
    const stringData = {};
    for (const [key, val] of Object.entries(data)) {
      stringData[key] = typeof val === 'string' ? val : JSON.stringify(val);
    }

    const message = {
      token: user.fcmToken,
      notification: {
        title: title || 'FConnect',
        body: body || '',
      },
      data: stringData,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'fconnect_high_importance_channel',
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`🚀 Đã gửi push notification thành công tới user ${user.fullName || userId}:`, response);
    return { success: true, response };
  } catch (error) {
    console.error('❌ Lỗi khi gửi push notification qua Firebase:', error.message);
    return { success: false, error: error.message };
  }
};

export default { sendPushToUser };
