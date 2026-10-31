import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'journal_store.dart';

// Still on FCM registration tokens: their replacement (register() and
// installation IDs) needs a matching send path in functions/, and the token
// one is what firebase-admin's sendEachForMulticast takes today.
// ignore_for_file: deprecated_member_use

/// Notifications for when the other one adds something, on the Android app
/// only. Each device's push token is filed under whoever uses it;
/// functions/index.js does the sending.
class Push {
  Push(this._store);

  final JournalStore _store;
  StreamSubscription<String>? _refresh;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Asks once for permission, then files this device under [person].
  /// Returns whether notifications are on.
  Future<bool> start(String person) async {
    if (!_supported) return false;
    try {
      final settings = await _fcm.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) return false;
      final token = await _fcm.getToken();
      if (token == null) return false;
      await _store.saveToken(token, person: person, platform: 'android');
      _refresh ??= _fcm.onTokenRefresh.listen((t) => _store.saveToken(t, person: person, platform: 'android'));
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
    if (!_supported) return;
    try {
      final token = await _fcm.getToken();
      if (token != null) await _store.forgetToken(token);
      await _fcm.deleteToken();
    } catch (_) {}
  }

  void dispose() => _refresh?.cancel();
}
