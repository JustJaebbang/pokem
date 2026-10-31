import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushMessagingService {
  static bool get available =>
      const bool.fromEnvironment('PUSH_ENABLED') &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;
  Future<void>? _initialization;
  bool _initialRead = false;
  Future<void> initialize() async {
    try {
      await (_initialization ??= _initialize());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
  }

  Stream<Map<String, dynamic>> get foreground =>
      FirebaseMessaging.onMessage.map((m) => m.data);
  Stream<Map<String, dynamic>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);
  Stream<String> get refreshed => FirebaseMessaging.instance.onRegistered;
  Future<Map<String, dynamic>?> initial() async {
    if (_initialRead) return null;
    _initialRead = true;
    return (await FirebaseMessaging.instance.getInitialMessage())?.data;
  }

  Future<bool> permission({bool ask = false}) async {
    final settings = ask
        ? await FirebaseMessaging.instance.requestPermission()
        : await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> token() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    final ready = Completer<String>();
    final subscription = FirebaseMessaging.instance.onRegistered.listen((fid) {
      if (!ready.isCompleted) ready.complete(fid);
    });
    try {
      await FirebaseMessaging.instance.register().timeout(
        const Duration(seconds: 10),
      );
      return await ready.future.timeout(const Duration(seconds: 10));
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> revoke() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.unregister().timeout(
      const Duration(seconds: 5),
    );
  }
}
