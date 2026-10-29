import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import 'auth_service.dart';

// Background message handler (Bắt buộc phải là hàm top-level độc lập)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('🔔 [Background Message]: ${message.notification?.title} - ${message.notification?.body}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AuthService _authService = AuthService();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'fconnect_high_importance_channel', // id
    'FConnect High Importance Notifications', // title
    description: 'Kênh thông báo ưu tiên cao cho FConnect (Tin nhắn, Đơn hàng, v.v.)',
    importance: Importance.high,
    playSound: true,
  );

  /// Khởi tạo toàn bộ dịch vụ Notification trên thiết bị
  Future<void> initialize() async {
    if (kIsWeb) {
      if (kDebugMode) {
        print('ℹ️ NotificationService: Bỏ qua trên Web vì Firebase Push Notification được cấu hình cho Android Mobile.');
      }
      return;
    }
    try {
      // 1. Khởi tạo Firebase nếu chưa khởi tạo
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final fcm = FirebaseMessaging.instance;

      // 2. Thiết lập Background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Xin quyền thông báo (Bắt buộc trên Android 13+ và iOS)
      NotificationSettings settings = await fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('🔔 User granted permission: ${settings.authorizationStatus}');
      }

      // 4. Cấu hình Local Notification để hiện Banner khi app đang mở (Foreground)
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (kDebugMode) {
            print('🔔 Người dùng nhấn vào thông báo: ${response.payload}');
          }
        },
      );

      // Tạo Notification Channel trên Android
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 5. Lắng nghe thông báo khi đang mở App (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null && !kIsWeb) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: '@mipmap/ic_launcher',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
              ),
            ),
            payload: jsonEncode(message.data),
          );
        }
      });

      // 6. Lấy Device Token và tự động đồng bộ lên Backend nếu đã đăng nhập
      await syncTokenWithBackend();

      // Lắng nghe khi Token thay đổi (ví dụ khi app update hoặc xóa cache)
      fcm.onTokenRefresh.listen((newToken) {
        sendTokenToBackend(newToken);
      });
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Lỗi khởi tạo NotificationService: $e');
      }
    }
  }

  /// Lấy mã định danh FCM Token của thiết bị hiện tại
  Future<String?> getDeviceToken() async {
    if (kIsWeb || Firebase.apps.isEmpty) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Không lấy được FCM token: $e');
      }
      return null;
    }
  }

  /// Đồng bộ token lên server backend
  Future<void> syncTokenWithBackend() async {
    if (kIsWeb) return;
    final token = await getDeviceToken();
    if (token != null) {
      if (kDebugMode) {
        print('📱 FCM Device Token: $token');
      }
      await sendTokenToBackend(token);
    }
  }

  /// Gửi FCM Token lên Backend lưu vào User profile
  Future<bool> sendTokenToBackend(String fcmToken) async {
    try {
      final jwtToken = await _authService.getToken();
      if (jwtToken == null || jwtToken.isEmpty) {
        // Chưa đăng nhập, token sẽ được đồng bộ sau khi đăng nhập thành công
        return false;
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/notifications/fcm-token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'fcmToken': fcmToken}),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Đã cập nhật FCM Token lên server thành công');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ Lỗi cập nhật FCM Token: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Lỗi kết nối khi gửi FCM token: $e');
      }
      return false;
    }
  }
}
