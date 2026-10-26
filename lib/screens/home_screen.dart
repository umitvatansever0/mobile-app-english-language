import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../logic/session_builder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';
import '../widgets/common.dart';
import '../widgets/level_path.dart';
import 'session_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Günaydın!';
    if (h < 18) return 'Merhaba!';
    return 'İyi akşamlar!';
  }

  Future<void> _onLevelTap(BuildContext context, AppState app, String level) async {
    if (level == app.targetLevel) {
      startSession(context, SessionRequest(size: AppConfig.dailyFreeWords, level: level));
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hedefin $level olsun mu?'),
        content: Text('Yeni kelimeler $level (${levelNames[level]}) seviyesinden gelir. Tekrarların etkilenmez.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hedefi değiştir')),
        ],
      ),
    );
    if (yes == true) app.setTargetLevel(level);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pal = Pal.of(context);
    final t = app.today;
    final goal = AppConfig.dailyFreeWords;
    final done = t.studied.clamp(0, goal);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
          Row(children: [
            Expanded(
              child: Text(_greeting(),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: pal.dark ? AppColors.sun : AppColors.tealDeep)),
            ),
            const StreakChip(),
          ]),
          const SizedBox(height: 14),

          // Günlük hedef kartı
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: AppColors.tealDeep, offset: Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('Bugünkü hedef',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 14.5)),
                ),
                if (!app.isPremium)
                  Text('Kalan hak: ${app.remainingToday}',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
              const SizedBox(height: 2),
              Text('$done / $goal kelime',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
              const SizedBox(height: 10),
              ChunkyProgress(value: done / goal, color: AppColors.sun, track: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(height: 10),
              Text(
                done >= goal
                    ? 'Hedefini tamamladın! İstersen devam edebilirsin.'
                    : app.studiedToday
                        ? 'Harika gidiyorsun, ${goal - done} kelime kaldı.'
                        : 'Serini korumak için bugün çalış.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ChunkyButton(
                label: done == 0 ? 'Çalışmaya başla' : 'Devam et',
                style: ChunkyStyle.white,
                onPressed: () => startSession(context, SessionRequest(size: goal, level: app.targetLevel)),
              ),
            ]),
          ),

          // Tekrar / hata kısayolları
          if (app.dueCount > 0 || app.mistakesCount > 0) const SizedBox(height: 14),
          if (app.dueCount > 0 || app.mistakesCount > 0)
            Row(children: [
              if (app.dueCount > 0)
                Expanded(
                  child: _Shortcut(
                    icon: Icons.schedule_rounded,
                    color: AppColors.teal,
                    value: '${app.dueCount}',
                    label: 'Tekrar zamanı',
                    onTap: () => startSession(context, SessionRequest(size: goal, level: app.targetLevel)),
                  ),
                ),
              if (app.dueCount > 0 && app.mistakesCount > 0) const SizedBox(width: 12),
              if (app.mistakesCount > 0)
                Expanded(
                  child: _Shortcut(
                    icon: Icons.replay_rounded,
                    color: AppColors.rose,
                    value: '${app.mistakesCount}',
                    label: 'Hataları çalış',
                    onTap: () => startSession(context, const SessionRequest(size: 20, level: allLevels, kind: SessionKind.mistakes)),
                  ),
                ),
            ]),

          const SectionTitle('Seviye yolculuğun'),
          LevelPath(
            nodes: buildLevelNodes(app.targetLevel, app.levelStudied),
            onTap: (l) => _onLevelTap(context, app, l),
          ),

          const SectionTitle('Bugün'),
          SectionCard(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              StatTile(value: '${t.studied}', label: 'Çalışılan', color: AppColors.teal),
              StatTile(value: '${t.correct}', label: 'Doğru', color: AppColors.emerald),
              StatTile(value: '${t.wrong + t.dontKnow}', label: 'Yanlış', color: AppColors.rose),
            ]),
          ),
          const SectionTitle('Son 7 gün'),
          const SectionCard(child: _WeekChart()),
          const SizedBox(height: 12),
          const Center(child: BannerAdBox()),
        ]),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.color, required this.value, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return ChunkyCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: pal.ink)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: pal.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart();
  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final days = context.watch<AppState>().lastDays(7);
    final maxV = days.fold<int>(1, (m, d) => d.studied > m ? d.studied : m);
    final pal = Pal.of(context);
    return SizedBox(
      height: 130,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(days[i].studied == 0 ? '' : '${days[i].studied}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: pal.muted)),
              const SizedBox(height: 4),
              Container(
                height: 80 * days[i].studied / maxV + 8,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: days[i].studied == 0 ? pal.track : (i == days.length - 1 ? AppColors.sun : AppColors.teal),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(_days[DateTime.parse(days[i].day).weekday - 1],
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: pal.muted)),
            ]),
          ),
      ]),
    );
  }
}
