import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../logic/session_builder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/wave_progress.dart';
import 'session_screen.dart';
import 'shell_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final lp = app.levelProgress(app.targetLevel);
    final pct = lp.total == 0 ? 0 : (lp.mastered * 100 / lp.total).floor();
    final t = app.today;
    final goal = AppConfig.dailyFreeWords;

    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa'), actions: const [StreakChip(), SizedBox(width: 16)]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        // Hedef kartı
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hedef Durumu', style: TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Text('${app.targetLevel} Hedefine İlerleme',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${lp.mastered}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                Text('/ ${lp.total} kelime', style: const TextStyle(color: Colors.white70)),
              ]),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: lp.total == 0 ? 0 : lp.mastered / lp.total,
                minHeight: 10,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pct == 0
                  ? 'Ustalaştığın kelimeler burada birikecek. Hadi başlayalım!'
                  : 'Harika gidiyorsun! ${app.targetLevel} seviyesinin %$pct\'ini tamamladın.',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.18), foregroundColor: Colors.white),
              onPressed: () => ShellScreen.goToTab(context, 1),
              child: const Text('Çalışmaya Başla'),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (app.dueCount > 0) ...[
          _ActionTile(
            icon: Icons.schedule_rounded,
            color: AppColors.primary,
            title: 'Tekrar zamanı',
            subtitle: '${app.dueCount} kelimenin tekrar zamanı geldi',
            onTap: () => ShellScreen.goToTab(context, 1),
          ),
          const SizedBox(height: 12),
        ],
        if (app.mistakesCount > 0) ...[
          _ActionTile(
            icon: Icons.replay_rounded,
            color: AppColors.warning,
            title: 'Hataları Çalış',
            subtitle: '${app.mistakesCount} hatalı kelime seni bekliyor',
            onTap: () => startSession(context,
                SessionRequest(size: 20, level: 'C1', kind: SessionKind.mistakes)),
          ),
          const SizedBox(height: 12),
        ],
        if (!app.isPremium)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text('Bugünkü ücretsiz hakkın: ${app.remainingToday} / ${t.freeAllowance} kelime',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
          ),
        const SizedBox(height: 6),
        // Seri + günlük hedef
        SectionCard(
          child: Row(children: [
            WaveProgress(percent: (t.studied * 100 / goal).clamp(0, 100).toDouble(), size: 96),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.local_fire_department_rounded, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text('${app.streak} günlük seri', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                Text(
                  app.studiedToday ? 'Bugün tamam, yarın devam et.' : 'Serini korumak için bugün çalış!',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text('Günlük hedef: ${t.studied.clamp(0, goal)} / $goal', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                if (app.streakFreezes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('🧊 ${app.streakFreezes} seri dondurma hakkın var', style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Text('BUGÜNKÜ PERFORMANSIN', style: TextStyle(color: cs.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SectionCard(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            StatTile(value: '${t.studied}', label: 'Çalışılan', color: AppColors.primary),
            StatTile(value: '${t.correct}', label: 'Doğru', color: AppColors.success),
            StatTile(value: '${t.wrong + t.dontKnow}', label: 'Yanlış', color: AppColors.danger),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MiniStat(icon: Icons.auto_stories_rounded, value: '${t.newWords}', label: 'Yeni Kelime')),
          const SizedBox(width: 12),
          Expanded(child: _MiniStat(icon: Icons.workspace_premium_rounded, value: '${app.masteredCount}', label: 'Ustalaşılan')),
        ]),
        const SizedBox(height: 20),
        Text('SON 7 GÜN', style: TextStyle(color: cs.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        const SectionCard(child: _WeekChart()),
        const SizedBox(height: 16),
        const Center(child: BannerAdBox()),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ]),
      );
}

class _WeekChart extends StatelessWidget {
  const _WeekChart();
  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final days = context.watch<AppState>().lastDays(7);
    final maxV = days.fold<int>(1, (m, d) => d.studied > m ? d.studied : m);
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 140,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final d in days)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(d.studied == 0 ? '' : '${d.studied}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Container(
                height: 90 * d.studied / maxV + 4,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: d.studied == 0 ? cs.outlineVariant : cs.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(_days[DateTime.parse(d.day).weekday - 1], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
          ),
      ]),
    );
  }
}
