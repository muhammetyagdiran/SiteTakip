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

    // 1. Firebase Messaging Permissions (iOS/Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }

    // 2. Initialize Local Notifications for Foreground
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click
        print('Notification clicked: ${details.payload}');
      },
    );

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

    // 3. Set foreground notification presentation options for iOS
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      
      if (notification != null && !kIsWeb) {
        // Android Specific
        AndroidNotification? android = message.notification?.android;
        
        // Build notification details
        NotificationDetails platformChannelSpecifics = NotificationDetails(
          android: android != null ? AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android.smallIcon,
          ) : null,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          platformChannelSpecifics,
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
