import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/api_config.dart';
import '../app_keys.dart';
import '../screens/notifications/notification_screen.dart';
import 'api_service.dart';
import 'device_id_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[PushNotificationService] Background message: ${message.messageId}');
}

class PushNotificationService {
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'admin_broadcast',
    'Pemberitahuan',
    description: 'Notifikasi dari admin',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint('[PushNotificationService] Firebase belum siap: $error');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (!kIsWeb && Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Set up local notifications for foreground display
      await _setupLocalNotifications();

      // Listen to foreground messages
      _foregroundSubscription?.cancel();
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      await syncCurrentToken();
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) {
        unawaited(_registerToken(token));
      });

      _initialized = true;
      debugPrint('[PushNotificationService] Initialized');
    } catch (error) {
      debugPrint('[PushNotificationService] Initialize error: $error');
    }
  }

  static Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(initSettings);

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_androidChannel);
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    _showInAppNotificationSnackBar(
      title: notification.title ?? 'Pemberitahuan',
      body: notification.body ?? '',
      imageUrl: _extractImageUrl(message),
      notificationId: _extractNotificationIdFromPayload(message),
    );
  }

  static String? _extractImageUrl(RemoteMessage message) {
    final possibleKeys = [
      'image',
      'imageUrl',
      'image_url',
      'picture',
      'thumbnail',
      'photo',
    ];

    for (final key in possibleKeys) {
      final value = message.data[key];
      if (value != null && value.trim().startsWith('http')) {
        return value.trim();
      }
    }

    return null;
  }

  static void _showInAppNotificationSnackBar({
    required String title,
    required String body,
    String? imageUrl,
    String? notificationId,
  }) {
    void openNotificationScreen() {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => NotificationScreen(
            initialNotificationId: notificationId,
          ),
        ),
      );
    }

    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: openNotificationScreen,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: Colors.white24,
                      child: const Icon(Icons.image_not_supported, color: Colors.white),
                    ),
                  ),
                )
              else
                const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        action: SnackBarAction(
          label: 'Buka',
          textColor: Colors.white,
          onPressed: openNotificationScreen,
        ),
      ),
    );
  }

  static String? _extractNotificationIdFromPayload(RemoteMessage message) {
    final possibleKeys = [
      'notificationId',
      'notification_id',
      'id',
      'notifId',
      'notif_id',
    ];

    for (final key in possibleKeys) {
      final value = message.data[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static Future<void> syncCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }
      await _registerToken(token);
    } catch (error) {
      debugPrint('[PushNotificationService] Sync token error: $error');
    }
  }

  static Future<void> unregisterCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final deviceId = await DeviceIdService.getOrCreateDeviceId();

      await ApiService().delete(
        ApiConfig.pushToken,
        data: {
          'token': token,
          'deviceId': deviceId,
        },
      );
    } catch (error) {
      debugPrint('[PushNotificationService] Unregister token error: $error');
    }
  }

  static Future<void> _registerToken(String token) async {
    if (token.trim().isEmpty) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceId = await DeviceIdService.getOrCreateDeviceId();
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'other';

      await ApiService().post(
        ApiConfig.pushToken,
        data: {
          'token': token.trim(),
          'platform': platform,
          'deviceId': deviceId,
          'appVersion': packageInfo.version,
        },
        headers: {
          'x-device-id': deviceId,
        },
      );
    } catch (error) {
      debugPrint('[PushNotificationService] Register token error: $error');
    }
  }
}

