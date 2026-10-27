import { Notification, User, Business } from '../models/index.js';
import { sendPushToUser } from '../services/pushNotificationService.js';

// @desc    Update FCM Token for Push Notifications
// @route   POST /api/notifications/fcm-token
// @access  Private
export const updateFcmToken = async (req, res) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken) {
      return res.status(400).json({ success: false, message: 'fcmToken là bắt buộc' });
    }

    await User.findByIdAndUpdate(req.user._id, { fcmToken });
    res.json({ success: true, message: 'Cập nhật FCM token thành công' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Test Push Notification to current user
// @route   POST /api/notifications/test-push
// @access  Private
export const testPushNotification = async (req, res) => {
  try {
    const result = await sendPushToUser(
      req.user._id,
      'FConnect Test Push 🔔',
      'Chúc mừng! Điện thoại của bạn đã nhận được thông báo đẩy từ Firebase thành công!',
      { type: 'TEST_PUSH', timestamp: new Date().toISOString() }
    );
    res.json({ success: true, message: 'Đã gửi lệnh push notification', result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Get current user's notifications (bao gồm cả thông báo của các cửa hàng mà user sở hữu)
// @route   GET /api/notifications
// @access  Private
export const getMyNotifications = async (req, res) => {
  try {
    const userId = req.user._id;

    // Tìm các cửa hàng mà user là chủ sở hữu
    const myBusinesses = await Business.find({ ownerId: userId }).select('_id');
    const myBusinessIds = myBusinesses.map((b) => b._id);

    const queryFilter = {
      $or: [
        { userId: userId },
        ...(myBusinessIds.length > 0
          ? [
              { userId: { $in: myBusinessIds } },
              { businessId: { $in: myBusinessIds } },
            ]
          : []),
      ],
    };

    const notifications = await Notification.find(queryFilter)
      .sort({ createdAt: -1 })
      .limit(50);

    const unreadCount = await Notification.countDocuments({
      ...queryFilter,
      isRead: false,
    });

    res.json({
      success: true,
      unreadCount,
      count: notifications.length,
      data: notifications,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Mark single notification as read
// @route   PUT /api/notifications/:id/read
// @access  Private
export const markNotificationRead = async (req, res) => {
  try {
    const notification = await Notification.findById(req.params.id);

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy thông báo' });
    }

    notification.isRead = true;
    await notification.save();

    res.json({
      success: true,
      data: notification,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Mark all notifications as read
// @route   PUT /api/notifications/read-all
// @access  Private
export const markAllNotificationsRead = async (req, res) => {
  try {
    const userId = req.user._id;
    const myBusinesses = await Business.find({ ownerId: userId }).select('_id');
    const myBusinessIds = myBusinesses.map((b) => b._id);

    const queryFilter = {
      $or: [
        { userId: userId },
        ...(myBusinessIds.length > 0
          ? [
              { userId: { $in: myBusinessIds } },
              { businessId: { $in: myBusinessIds } },
            ]
          : []),
      ],
    };

    await Notification.updateMany(queryFilter, { isRead: true });

    res.json({ success: true, message: 'Đã đánh dấu tất cả thông báo là đã đọc' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
