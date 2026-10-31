import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/sakura_flower.dart';

/// 01 · Đăng nhập — Google, once per device; the session is kept after that.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late final _bloom = AnimationController(vsync: this, duration: SakuraFlower.openDuration)..forward();
  var _busy = false;
  String? _error;

  /// Closing the Google window isn't an error worth showing.
  static const _cancelled = {'popup-closed-by-user', 'cancelled-popup-request', 'web-context-canceled', 'canceled'};

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      if (!_cancelled.contains(e.code)) _error = 'chưa đăng nhập được, thử lại nha (${e.code})';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _bloom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SakuraFlower(bloom: _bloom, size: 130),
                  const SizedBox(height: Space.s3),
                  Text('Kỷ niệm của chúng ta', style: AppText.script.copyWith(fontSize: 22)),
                  Text('us-together', style: AppText.display),
                  const SizedBox(height: Space.s7),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _signIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: Paper.c8,
                        foregroundColor: Paper.c1,
                        textStyle: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      child: Text(_busy ? 'đang mở Google…' : 'Đăng nhập với Google'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.s3),
                    Text(_error!, textAlign: TextAlign.center, style: AppText.body.copyWith(color: Sakura.c7, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
