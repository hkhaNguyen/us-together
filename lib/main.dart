import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/mock_journal.dart';
import 'dev/dev_page.dart';
import 'firebase_options.dart';
import 'home/home_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const UsTogetherApp());
}

final _journal = mockJournal();

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => HomePage(journal: _journal, meId: 'hkha')),
    GoRoute(path: '/dev', builder: (_, _) => const DevPage()),
  ],
);

class UsTogetherApp extends StatelessWidget {
  const UsTogetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'us-together',
      theme: buildAppTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
