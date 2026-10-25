import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Tanıtım: 3 sayfa + seviye seçimi.
/// Sayfa geçişi ve "İleri" düğmesi akışı best-flutter-ui-templates'teki
/// introduction_animation ekranından esinlenildi (MIT, © Mitesh Chodvadiya).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;
  String _level = 'A1';

  static const _pages = [
    (Icons.style_rounded, 'Kelime kartlarıyla İngilizce', 'Günde birkaç dakikayla en sık kullanılan İngilizce kelimeleri öğren.'),
    (Icons.psychology_alt_rounded, 'Akıllı tekrar', 'Zorlandığın kelimeleri daha sık, bildiklerini daha seyrek gösteriyoruz. Unutmadan öğrenirsin.'),
    (Icons.local_fire_department_rounded, 'Seri ve rozetler', 'Her gün çalış, serini büyüt, rozetleri topla.'),
  ];

  static const _levels = [
    ('A1', 'Yeni başlıyorum', 'Temel kelimeler, selamlaşma, sayılar'),
    ('A2', 'Biraz biliyorum', 'Günlük hayat, seyahat, alışveriş'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length) {
      _pc.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } else {
      context.read<AppState>().completeOnboarding(_level);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _pages.length + 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _page < _pages.length
                  ? () => _pc.animateToPage(_pages.length, duration: const Duration(milliseconds: 450), curve: Curves.easeOut)
                  : null,
              child: Text(_page < _pages.length ? 'Atla' : ''),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final p in _pages)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 180,
                        height: 180,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                        ),
                        child: Icon(p.$1, size: 90, color: Colors.white),
                      ),
                      const SizedBox(height: 40),
                      Text(p.$2, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      Text(p.$3, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: cs.onSurfaceVariant, height: 1.4)),
                    ]),
                  ),
                ListView(padding: const EdgeInsets.all(24), children: [
                  const SizedBox(height: 24),
                  Text('İngilizcen ne seviyede?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Sonra profilinden değiştirebilirsin.', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  for (final l in _levels) ...[
                    _LevelOption(code: l.$1, title: l.$2, subtitle: l.$3, selected: _level == l.$1, onTap: () => setState(() => _level = l.$1)),
                    const SizedBox(height: 12),
                  ],
                ]),
              ],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.all(4),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: FilledButton(onPressed: _next, child: Text(_page < _pages.length ? 'İleri' : 'Başlayalım')),
          ),
        ]),
      ),
    );
  }
}

class _LevelOption extends StatelessWidget {
  const _LevelOption({required this.code, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String code, title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer : cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
          ),
          child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: cs.primary, child: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: cs.primary),
          ]),
        ),
      ),
    );
  }
}
