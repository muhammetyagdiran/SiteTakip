import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    if (kIsWeb) return;
    final FirebaseMessaging _fcm = FirebaseMessaging.instance;

    // 1. Android 13+ Notification Permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialize Local Notifications for Foreground
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(initializationSettings);

    // 3. Create Android Notification Channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Get the token and save it to Supabase
    String? token = await _fcm.getToken();
    if (token != null) {
      await updateToken(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      updateToken(newToken);
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
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
              icon: android.smallIcon,
            ),
          ),
        );
      }
    });
  }

  static Future<void> updateToken(String token) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await SupabaseService.client
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
        print('FCM Token updated for user: $userId');
      } catch (e) {
        print('Error updating FCM token: $e');
      }
    }
  }
}

// Global background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}
