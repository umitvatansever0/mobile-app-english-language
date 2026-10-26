import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../logic/badges.dart';
import '../logic/session_builder.dart';
import '../logic/srs.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
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
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Puan ver')),
          ],
        ),
      );
      if (yes == true && mounted) openUrl(context, storeUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final lp = app.levelProgress(app.targetLevel);
    final pct = lp.total == 0 ? 0 : (lp.mastered * 100 / lp.total).floor();
    final quotaDone = !app.isPremium && app.remainingToday == 0;
    final msg = s.accuracy >= 0.9
        ? ('Muhteşem!', 'Neredeyse hepsini bildin. Böyle devam!')
        : s.accuracy >= 0.6
            ? ('Güzel ilerliyorsun.', 'Zorlandığın kelimeleri tekrar göstereceğiz. İstikrar en önemli anahtar!')
            : ('Pes etmek yok!', 'Hatalı kelimeler "Hataları Çalış" bölümünde seni bekliyor.');

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(fit: StackFit.expand, children: [
                CircularProgressIndicator(value: s.accuracy, strokeWidth: 12, backgroundColor: cs.outlineVariant),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('%${(s.accuracy * 100).round()}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
                    Text('Doğruluk', style: TextStyle(color: cs.onSurfaceVariant)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Text('Çalışma Tamamlandı', textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Bugün ${app.today.studied} kelime çalıştın.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(color: AppColors.streakBg, borderRadius: BorderRadius.circular(20)),
              child: Text('🔥 ${s.streak} günlük seri',
                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 17)),
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Genel İlerleme', style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Seviye ${app.targetLevel} • %$pct Tamamlandı', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Kart Sonuçları', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                StatTile(value: '${s.correct}', label: 'Doğru', color: AppColors.success),
                StatTile(value: '${s.wrong}', label: 'Yanlış', color: AppColors.danger),
                StatTile(value: '${s.dontKnow}', label: 'Bilmiyorum'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Etiketler', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (final r in [RecallRating.known, RecallRating.learning, RecallRating.forgot])
                  StatTile(value: '${s.ratings[r] ?? 0}', label: r.label),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(msg.$1, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(msg.$2, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('Günlük Hedef', style: TextStyle(color: cs.onSurfaceVariant)),
            const Spacer(),
            Text('${app.today.studied.clamp(0, AppConfig.dailyFreeWords)} / ${AppConfig.dailyFreeWords}',
                style: TextStyle(color: cs.primary)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: (app.today.studied / AppConfig.dailyFreeWords).clamp(0, 1).toDouble(), minHeight: 8),
          ),
          const SizedBox(height: 24),
          if (quotaDone) ...[
            FilledButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final ok = await PaywallScreen.open(context, reason: PaywallReason.quota);
                if (ok && mounted) {
                  final navCtx = nav.context;
                  nav.pop();
                  if (navCtx.mounted) startSession(navCtx, SessionRequest(size: 20, level: app.targetLevel));
                }
              },
              child: Text(app.canWatchRewardedAd ? 'Devam Et (Premium / Reklam)' : 'Premium\'a Geç ve Devam Et'),
            ),
            const SizedBox(height: 12),
          ] else if (app.mistakesCount > 0) ...[
            FilledButton.icon(
              icon: const Icon(Icons.replay_rounded),
              onPressed: () {
                final nav = Navigator.of(context);
                final navCtx = nav.context;
                nav.pop();
                startSession(navCtx, const SessionRequest(size: 20, level: allLevels, kind: SessionKind.mistakes));
              },
              label: Text('Hataları Çalış (${app.mistakesCount})'),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tamamla')),
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
        backgroundColor: const Color(0xFF0E1018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BadgeMedal(badge: badge, size: 150),
            const SizedBox(height: 24),
            Text('YENİ ROZET', style: TextStyle(color: badge.tier.color, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text(badge.title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${badge.tier.label} · ${badge.description}',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Harika')),
          ]),
        ),
      );
}
