import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/journal_store.dart';
import '../data/models.dart';
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
  final _store = JournalStore(FirebaseFirestore.instance);
  late final Stream<Journal> _journal = _store.watch();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _journal,
      builder: (context, snapshot) {
        final error = snapshot.error;
        // The rules only let accounts listed under members/ read anything.
        if (error is FirebaseException && error.code == 'permission-denied') {
          return _Message(
            text: 'Tài khoản ${widget.email} chưa có trong sổ.',
            action: 'Dùng tài khoản khác',
          );
        }
        if (error != null) return _Message(text: 'Không tải được sổ: $error', action: 'Đăng xuất');
        final journal = snapshot.data;
        if (journal == null) return const _Splash();
        return HomePage(
          journal: journal,
          meId: widget.email,
          onSetStartDate: _store.setStartDate,
          onSignOut: FirebaseAuth.instance.signOut,
        );
      },
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
