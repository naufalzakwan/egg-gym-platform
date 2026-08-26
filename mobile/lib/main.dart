import 'dart:async';

import 'package:egg_gym/app/app.dart';
import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/device_token_registration_service.dart';
import 'package:egg_gym/data/services/notification_center_service.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

Future<RemoteMessage?> _bootstrapFirebaseMessaging() async {
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('FCM onMessage title=${message.notification?.title}');
    debugPrint('FCM onMessage body=${message.notification?.body}');
    debugPrint('FCM onMessage data=${message.data}');
    NotificationCenterService.instance.handlePushData(message.data);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint('FCM onMessageOpenedApp id=${message.messageId}');
    NotificationCenterService.instance.handlePushData(message.data, open: true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationCenterService.instance.dispatchPendingPush(),
    );
  });

  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  debugPrint('FCM permission status: ${settings.authorizationStatus}');

  final token = await FirebaseMessaging.instance.getToken();
  debugPrint('FCM token tersedia: ${token != null}');

  FirebaseMessaging.instance.onTokenRefresh.listen((token) {
    debugPrint('FCM token diperbarui.');
    final session = AppSessionService.instance.currentSession;
    if (session != null) {
      unawaited(DeviceTokenRegistrationService().register(
        baseUrl: session.baseUrl,
        authToken: session.token,
        fcmToken: token,
      ));
    }
  });
  return FirebaseMessaging.instance.getInitialMessage();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialMessage = await _bootstrapFirebaseMessaging();
  await AppSessionService.instance.hydrate();
  final currentSession = AppSessionService.instance.currentSession;
  final currentFcmToken = await FirebaseMessaging.instance.getToken();
  if (currentSession != null && currentFcmToken != null) {
    unawaited(DeviceTokenRegistrationService().register(
      baseUrl: currentSession.baseUrl,
      authToken: currentSession.token,
      fcmToken: currentFcmToken,
    ));
  }
  if (initialMessage != null) {
    NotificationCenterService.instance.handlePushData(
      initialMessage.data,
      open: true,
    );
  }
  await PublicSettingsService.instance.hydrate();
  runApp(const EggGymApp());
  unawaited(PublicSettingsService.instance.refresh().catchError((_) {}));
}
