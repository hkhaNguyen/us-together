import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'journal_store.dart';

// Still on FCM registration tokens: their replacement (register() and
// installation IDs) needs a matching send path in functions/, and the token
// one is what firebase-admin's sendEachForMulticast takes today.
// ignore_for_file: deprecated_member_use

/// Notifications for when the other one adds something. Each device's push
/// token is filed under whoever uses it; functions/index.js does the sending.
class Push {
  Push(this._store);

  final JournalStore _store;
  StreamSubscription<String>? _refresh;

  /// Public half of the web push certificate (Firebase console → Cloud
  /// Messaging → Web Push certificates). Not a secret.
  static const _webPushKey = '';

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// False where push can't work, e.g. Safari outside a home-screen app.
  Future<bool> get supported async => (!kIsWeb || _webPushKey.isNotEmpty) && await _fcm.isSupported();

  Future<bool> get allowed async =>
      (await _fcm.getNotificationSettings()).authorizationStatus == AuthorizationStatus.authorized;

  /// Files this device under [person] if notifications are on. With [ask]
  /// it first asks for them, which the web only allows from a tap.
  /// Returns whether they're on.
  Future<bool> start(String person, {bool ask = false}) async {
    try {
      if (!await supported) return false;
      if (ask) await _fcm.requestPermission();
      if (!await allowed) return false;
      final token = await _fcm.getToken(vapidKey: kIsWeb ? _webPushKey : null);
      if (token == null) return false;
      await _store.saveToken(token, person: person, platform: _platform);
      _refresh ??= _fcm.onTokenRefresh.listen((t) => _store.saveToken(t, person: person, platform: _platform));
      return true;
    } catch (_) {
      // Push is a nicety: the journal works the same without it.
      return false;
    }
  }

  /// On sign-out, so this device stops getting the other one's news.
  Future<void> forget() async {
    await _refresh?.cancel();
    _refresh = null;
    try {
      if (!await supported) return;
      final token = await _fcm.getToken(vapidKey: kIsWeb ? _webPushKey : null);
      if (token != null) await _store.forgetToken(token);
      await _fcm.deleteToken();
    } catch (_) {}
  }

  void dispose() => _refresh?.cancel();
}
