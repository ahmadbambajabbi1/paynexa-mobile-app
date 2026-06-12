import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../api/users_api.dart';
import '../app.dart';
import '../firebase_options.dart';
import '../screens/transaction_detail_screen.dart';

const AndroidNotificationChannel _paynexaChannel = AndroidNotificationChannel(
  'paynexa_transactions',
  'PayNexa transactions',
  description: 'Transaction updates from PayNexa',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _showLocalNotification(message);
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final title = message.notification?.title ?? 'PayNexa';
  final body = message.notification?.body ?? '';
  if (body.isEmpty) return;
  await _localNotifications.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _paynexaChannel.id,
        _paynexaChannel.name,
        channelDescription: _paynexaChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: message.data['transactionId'],
  );
}

class PushNotificationsService {
  PushNotificationsService._();
  static final PushNotificationsService instance = PushNotificationsService._();

  bool _initialized = false;
  String? _lastRegisteredToken;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_paynexaChannel);
    }
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final txId = details.payload;
        if (txId == null || txId.isEmpty) return;
        navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => TransactionDetailScreen(transactionId: txId),
          ),
        );
      },
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        debugPrint('FCM: Android notification permission denied');
      }
    }
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleOpenedMessage(initial);
    }
    messaging.onTokenRefresh.listen((_) {
      _lastRegisteredToken = null;
    });
    _initialized = true;
  }

  Future<void> syncToken(String token) async {
    if (!_initialized || kIsWeb) return;
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('FCM: no device token yet');
        return;
      }
      if (_lastRegisteredToken == fcmToken) return;
      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : 'web';
      await registerFcmToken(token, fcmToken: fcmToken, platform: platform);
      _lastRegisteredToken = fcmToken;
      debugPrint('FCM: token registered with PayNexa backend');
    } catch (e, st) {
      debugPrint('FCM token sync failed: $e\n$st');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('FCM foreground: ${message.notification?.title}');
    await _showLocalNotification(message);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final txId = message.data['transactionId'];
    if (txId == null || txId.isEmpty) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionDetailScreen(transactionId: txId),
      ),
    );
  }

  // Marketplace booking push deep links — enable when marketplace notifications ship.
  // void _handleMarketplaceOpenedMessage(RemoteMessage message) {
  //   final bookingId = message.data['bookingId'];
  //   if (bookingId == null || bookingId.isEmpty) return;
  //   navigatorKey.currentState?.push(
  //     MaterialPageRoute<void>(
  //       builder: (_) => MarketplaceBookingDetailScreen(bookingId: bookingId),
  //     ),
  //   );
  // }
}
