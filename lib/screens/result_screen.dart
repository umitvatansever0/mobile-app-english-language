import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../logic/badges.dart';
import '../logic/session_builder.dart';
import '../logic/srs.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';
import '../widgets/common.dart';
import '../widgets/wave_progress.dart';
import 'links.dart';
import 'paywall_screen.dart';
import 'session_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.summary});
  final SessionSummary summary;
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showBadges());
  }

  Future<void> _showBadges() async {
    for (final b in widget.summary.newBadges) {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => _BadgeDialog(badge: b));
    }
    if (!mounted) return;
    final app = context.read<AppState>();
    if (widget.summary.newBadges.isEmpty && app.shouldAskForRating && widget.summary.accuracy >= 0.7) {
      app.markRatePrompted();
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Uygulamayı beğendin mi?'),
          content: const Text('Birkaç saniyeni ayırıp puan verirsen daha çok kişiye ulaşmamıza yardım etmiş olursun.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Sonra')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Puan ver')),
          ],
        ),
      );
      if (yes == true && mounted) openUrl(context, storeUrl);
    }
  }

  void _restart(SessionRequest req) {
    final nav = Navigator.of(context);
    final navCtx = nav.context;
    nav.pop();
    startSession(navCtx, req);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final app = context.watch<AppState>();
    final pal = Pal.of(context);
    final goal = AppConfig.dailyFreeWords;
    final studied = app.today.studied;
    final quotaDone = !app.isPremium && app.remainingToday == 0;
    final pct = (s.accuracy * 100).round();
    final msg = s.accuracy >= 0.9
        ? ('Muhteşem!', 'Neredeyse hepsini bildin. Böyle devam!')
        : s.accuracy >= 0.6
            ? ('Güzel ilerliyorsun.', 'Zorlandığın kelimeleri tekrar göstereceğiz. İstikrar en önemli anahtar!')
            : ('Pes etmek yok!', 'Yanlış yaptığın kelimeler "Hataları çalış" bölümünde seni bekliyor.');

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 24), children: [
          // Doğruluk paneli
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: AppColors.tealDeep, offset: Offset(0, 6))],
            ),
            child: Row(children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(fit: StackFit.expand, children: [
                  CircularProgressIndicator(
                    value: s.accuracy,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    color: AppColors.sun,
                    backgroundColor: Colors.white24,
                  ),
                  Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('%$pct', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      const Text('doğruluk', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Çalışma tamamlandı', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Bugün $studied kelime çalıştın.',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department_rounded, color: AppColors.sunInk, size: 18),
                      const SizedBox(width: 3),
                      Text('${s.streak} günlük seri',
                          style: const TextStyle(color: AppColors.sunInk, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              StatTile(value: '${s.correct}', label: 'Doğru', color: AppColors.emerald),
              StatTile(value: '${s.wrong}', label: 'Yanlış', color: AppColors.rose),
              StatTile(value: '${s.dontKnow}', label: 'Bilmiyorum'),
            ]),
          ),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Etiketlerin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: pal.ink)),
              const SizedBox(height: 10),
              Row(children: [
                for (final (r, c) in [
                  (RecallRating.known, AppColors.emerald),
                  (RecallRating.learning, AppColors.sunDeep),
                  (RecallRating.forgot, AppColors.rose),
                ]) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        Text('${s.ratings[r] ?? 0}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c)),
                        Text(r.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: pal.ink)),
                      ]),
                    ),
                  ),
                  if (r != RecallRating.forgot) const SizedBox(width: 8),
                ],
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          SectionCard(
            child: Row(children: [
              WaveProgress(percent: (studied * 100 / goal).clamp(0, 100).toDouble(), size: 92),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(msg.$1, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: pal.ink)),
                  const SizedBox(height: 4),
                  Text(msg.$2, style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Günlük hedef: ${studied.clamp(0, goal)} / $goal',
                      style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w900)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          if (quotaDone) ...[
            ChunkyButton(
              label: app.canWatchRewardedAd ? 'Devam et (Premium / reklam)' : 'Premium\'a geç ve devam et',
              style: ChunkyStyle.sun,
              onPressed: () async {
                final ok = await PaywallScreen.open(context, reason: PaywallReason.quota);
                if (ok && mounted) _restart(SessionRequest(size: goal, level: app.targetLevel));
              },
            ),
            const SizedBox(height: 10),
          ] else if (app.mistakesCount > 0) ...[
            ChunkyButton(
              label: 'Hataları çalış (${app.mistakesCount})',
              icon: Icons.replay_rounded,
              style: ChunkyStyle.danger,
              onPressed: () => _restart(const SessionRequest(size: 20, level: allLevels, kind: SessionKind.mistakes)),
            ),
            const SizedBox(height: 10),
          ],
          ChunkyButton(label: 'Tamamla', style: ChunkyStyle.ghost, onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
    );
  }
}

class _BadgeDialog extends StatelessWidget {
  const _BadgeDialog({required this.badge});
  final BadgeDef badge;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.tealDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BadgeMedal(badge: badge, size: 116),
            const SizedBox(height: 24),
            const Tag('YENİ ROZET'),
            const SizedBox(height: 10),
            Text(badge.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${badge.tier.label} · ${badge.description}',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 22),
            ChunkyButton(label: 'Harika', style: ChunkyStyle.sun, onPressed: () => Navigator.pop(context)),
          ]),
        ),
      );
}
