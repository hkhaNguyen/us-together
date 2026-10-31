import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../add/photo_pipeline.dart';
import '../data/journal_store.dart';
import '../home/home_page.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/sakura_flower.dart';
import 'login_page.dart';

/// Signed out → login. Signed in → the journal, straight away on every later
/// launch because Firebase keeps the session on the device.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) return const _Splash();
        final user = auth.data;
        if (user == null) return const LoginPage();
        return _JournalGate(key: ValueKey(user.uid), email: user.email ?? '');
      },
    );
  }
}

class _JournalGate extends StatefulWidget {
  const _JournalGate({super.key, required this.email});

  final String email;

  @override
  State<_JournalGate> createState() => _JournalGateState();
}

class _JournalGateState extends State<_JournalGate> {
  final _store = JournalStore(FirebaseFirestore.instance, PhotoUploader(FirebaseStorage.instance));

  /// One subscription for the whole app: pages pushed on top (a moment, the
  /// photo viewer) listen to this too, so they update live.
  final _session = ValueNotifier<Session?>(null);
  late final StreamSubscription<Session> _subscription;
  Object? _error;

  @override
  void initState() {
    super.initState();
    var purged = false;
    _subscription = _store.watch(widget.email).listen(
          (s) {
            _session.value = s;
            // Once per launch: whatever has sat in the trash past its 30 days
            // goes for good. Failing quietly is fine; the next launch retries.
            if (!purged) {
              purged = true;
              _store.purgeExpired(s.journal).catchError((Object _) {});
            }
          },
          onError: (Object e) => setState(() => _error = e),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    // The rules only let accounts listed under members/ read anything.
    if (error is FirebaseException && error.code == 'permission-denied') {
      return _Message(text: 'Tài khoản ${widget.email} chưa có trong sổ.', action: 'Dùng tài khoản khác');
    }
    if (error != null) return _Message(text: 'Không tải được sổ: $error', action: 'Đăng xuất');

    return ValueListenableBuilder(
      valueListenable: _session,
      builder: (context, session, _) => session == null
          ? const _Splash()
          : HomePage(
              journal: session.journal,
              meId: session.me,
              store: _store,
              session: _session,
              onSignOut: FirebaseAuth.instance.signOut,
            ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: SakuraFlower(bloom: AlwaysStoppedAnimation(1), size: 96)),
    );
  }
}

/// A sentence and a sign-out button, for when the journal can't be shown.
class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action});

  final String text;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 15)),
              const SizedBox(height: Space.s5),
              OutlinedButton(onPressed: FirebaseAuth.instance.signOut, child: Text(action)),
            ],
          ),
        ),
      ),
    );
  }
}
