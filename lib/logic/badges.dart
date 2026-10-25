import 'package:flutter/material.dart';

enum BadgeTier {
  bronze('Bronz', Color(0xFFCD7F32)),
  silver('Gümüş', Color(0xFF9EA7B3)),
  gold('Altın', Color(0xFFE0A100)),
  diamond('Elmas', Color(0xFF3FB8D9));

  const BadgeTier(this.label, this.color);
  final String label;
  final Color color;
}

enum BadgeMetric { wordsStudied, wordsMastered, streak, sessions, perfectSessions, totalCorrect }

class BadgeDef {
  const BadgeDef(this.id, this.title, this.description, this.icon, this.tier, this.metric, this.target);
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final BadgeTier tier;
  final BadgeMetric metric;
  final int target;
}

/// Rozet hesaplamasında kullanılan sayılar.
class BadgeStats {
  const BadgeStats({
    required this.wordsStudied,
    required this.wordsMastered,
    required this.bestStreak,
    required this.sessions,
    required this.perfectSessions,
    required this.totalCorrect,
  });
  final int wordsStudied;
  final int wordsMastered;
  final int bestStreak;
  final int sessions;
  final int perfectSessions;
  final int totalCorrect;

  int value(BadgeMetric m) => switch (m) {
        BadgeMetric.wordsStudied => wordsStudied,
        BadgeMetric.wordsMastered => wordsMastered,
        BadgeMetric.streak => bestStreak,
        BadgeMetric.sessions => sessions,
        BadgeMetric.perfectSessions => perfectSessions,
        BadgeMetric.totalCorrect => totalCorrect,
      };
}

List<BadgeDef> _ladder(String prefix, String name, String Function(int) desc, IconData icon, BadgeMetric m,
    List<int> targets) {
  const tiers = BadgeTier.values;
  return [
    for (var i = 0; i < targets.length; i++)
      BadgeDef('${prefix}_${targets[i]}', '$name ${targets[i]}', desc(targets[i]), icon,
          tiers[(i * tiers.length ~/ targets.length).clamp(0, tiers.length - 1)], m, targets[i]),
  ];
}

final List<BadgeDef> allBadges = [
  const BadgeDef('first_session', 'İlk Adım', 'İlk çalışmanı tamamladın', Icons.eco_rounded, BadgeTier.bronze,
      BadgeMetric.sessions, 1),
  ..._ladder('explore', 'Keşif', (n) => '$n farklı kelime çalıştın', Icons.explore_rounded,
      BadgeMetric.wordsStudied, [25, 50, 100, 250, 500, 1000, 2000]),
  ..._ladder('master', 'Usta', (n) => '$n kelimede ustalaştın', Icons.workspace_premium_rounded,
      BadgeMetric.wordsMastered, [10, 50, 100, 250, 500, 1000]),
  ..._ladder('streak', 'Seri', (n) => '$n günlük seriye ulaştın', Icons.local_fire_department_rounded,
      BadgeMetric.streak, [3, 7, 14, 30, 60, 100, 365]),
  ..._ladder('sessions', 'İstikrar', (n) => '$n çalışma tamamladın', Icons.event_available_rounded,
      BadgeMetric.sessions, [10, 25, 50, 100, 250]),
  ..._ladder('perfect', 'Kusursuz', (n) => '$n kez hepsini doğru bildin', Icons.gps_fixed_rounded,
      BadgeMetric.perfectSessions, [1, 5, 20, 50]),
  ..._ladder('correct', 'Doğru Cevap', (n) => 'Toplam $n doğru cevap', Icons.check_circle_rounded,
      BadgeMetric.totalCorrect, [100, 500, 1000, 5000, 10000]),
];

/// Henüz kazanılmamış ama koşulu sağlanan rozetler.
List<BadgeDef> newlyEarned(BadgeStats stats, Set<String> alreadyEarned) => [
      for (final b in allBadges)
        if (!alreadyEarned.contains(b.id) && stats.value(b.metric) >= b.target) b,
    ];
