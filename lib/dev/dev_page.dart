import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/sakura_flower.dart';

/// Scratch page to eyeball tokens and the bloom; replaced by the home
/// timeline once it exists.
class DevPage extends StatefulWidget {
  const DevPage({super.key});

  @override
  State<DevPage> createState() => _DevPageState();
}

class _DevPageState extends State<DevPage> with SingleTickerProviderStateMixin {
  late final _bloom = AnimationController(vsync: this, duration: SakuraFlower.openDuration)..forward();

  void _replay(Duration duration) {
    _bloom
      ..duration = duration
      ..forward(from: 0);
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
        child: ListView(
          padding: const EdgeInsets.all(Space.s5),
          children: [
            Center(child: SakuraFlower(bloom: _bloom, size: 240)),
            const SizedBox(height: Space.s4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.s3,
              children: [
                FilledButton(onPressed: () => _replay(SakuraFlower.openDuration), child: const Text('Nở (mở app)')),
                OutlinedButton(onPressed: () => _replay(Motion.dur4), child: const Text('Nở chậm (xem từ đầu)')),
              ],
            ),
            const SizedBox(height: Space.s6),
            Text('bên nhau từ 30 · 10 · 2022', style: AppText.script),
            Text('1.462', style: AppText.display),
            Text('Những ngày của tụi mình', style: AppText.h1),
            Text('Tên dịp trên thẻ', style: AppText.title),
            Text('Hôm đó trời mưa, hai đứa đứng dưới mái hiên chờ tạnh rồi quên luôn là đang chờ gì.', style: AppText.body),
            Text('Bài viết “chuyện gì đã xảy ra”', style: AppText.quote),
            Text('NGÀY BÊN NHAU', style: AppText.label),
          ],
        ),
      ),
    );
  }
}
