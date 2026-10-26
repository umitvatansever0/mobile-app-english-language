import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';

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
    (Icons.style_rounded, AppColors.teal, AppColors.tealDeep, 'Kelime kartlarıyla İngilizce',
        'Günde birkaç dakikayla en çok kullanılan İngilizce kelimeleri öğren.'),
    (Icons.psychology_alt_rounded, AppColors.sun, AppColors.sunDeep, 'Akıllı tekrar',
        'Zorlandığın kelimeleri daha sık, bildiklerini daha seyrek gösteriyoruz. Unutmadan öğrenirsin.'),
    (Icons.route_rounded, AppColors.emerald, AppColors.emeraldDeep, 'A1\'den C2\'ye yolculuk',
        'Seviyeni seç, serini büyüt, rozetleri topla.'),
  ];

  static const _levels = [
    ('A1', 'Yeni başlıyorum', 'Temel kelimeler, selamlaşma, sayılar'),
    ('A2', 'Biraz biliyorum', 'Günlük hayat, seyahat, alışveriş'),
    ('B1', 'Orta seviye', 'İş, duygular, fikir belirtme'),
    ('B2', 'İyi seviye', 'Toplum, medya, soyut konular'),
    ('C1', 'İleri seviye', 'Akademik ve profesyonel dil'),
    ('C2', 'Uzman', 'Nadir ve edebi kelimeler'),
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
    final pal = Pal.of(context);
    final total = _pages.length + 1;
    final onLevelPage = _page >= _pages.length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(children: [
              Expanded(child: ChunkyProgress(value: (_page + 1) / total, height: 14)),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onLevelPage
                    ? null
                    : () => _pc.animateToPage(_pages.length, duration: const Duration(milliseconds: 450), curve: Curves.easeOut),
                child: Text(onLevelPage ? '' : 'Atla'),
              ),
            ]),
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
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          color: p.$2,
                          borderRadius: BorderRadius.circular(54),
                          boxShadow: [BoxShadow(color: p.$3, offset: const Offset(0, 10))],
                        ),
                        child: Icon(p.$1, size: 86, color: p.$2 == AppColors.sun ? AppColors.sunInk : Colors.white),
                      ),
                      const SizedBox(height: 44),
                      Text(p.$4,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: pal.ink, height: 1.15)),
                      const SizedBox(height: 14),
                      Text(p.$5,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, color: pal.muted, height: 1.4, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12), children: [
                  Text('İngilizcen ne seviyede?', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: pal.ink)),
                  const SizedBox(height: 6),
                  Text('Sonra istediğin zaman değiştirebilirsin.',
                      style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  for (final l in _levels) ...[
                    _LevelOption(
                        code: l.$1, title: l.$2, subtitle: l.$3, selected: _level == l.$1, onTap: () => setState(() => _level = l.$1)),
                    const SizedBox(height: 6),
                  ],
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: ChunkyButton(label: onLevelPage ? 'Başlayalım' : 'İleri', onPressed: _next),
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
    final pal = Pal.of(context);
    return ChunkyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: selected ? AppColors.teal : null,
      color: selected ? (pal.dark ? const Color(0xFF123533) : AppColors.tealSoft) : null,
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : pal.lockBg,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: selected ? AppColors.tealDeep : pal.lockLip, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: Text(code, style: TextStyle(color: selected ? Colors.white : pal.muted, fontWeight: FontWeight.w900, fontSize: 17)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: pal.ink)),
            Text(subtitle, style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700, fontSize: 13.5)),
          ]),
        ),
        if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.teal),
      ]),
    );
  }
}
