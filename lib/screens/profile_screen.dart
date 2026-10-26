import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../logic/badges.dart';
import '../logic/daily.dart';
import '../logic/session_builder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';
import '../widgets/common.dart';
import '../widgets/level_path.dart';
import 'links.dart';
import 'paywall_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final earned = allBadges.where((b) => app.earnedBadgeIds.contains(b.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), actions: const [StreakChip(), SizedBox(width: 16)]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        // Premium durumu
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [BoxShadow(color: AppColors.tealDeep, offset: Offset(0, 6))],
          ),
          child: app.isPremium
              ? const Row(children: [
                  Icon(Icons.workspace_premium_rounded, color: AppColors.sun, size: 38),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text('Premium üyesin. Teşekkürler!',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white))),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Tag('ÜCRETSİZ PLAN'),
                  const SizedBox(height: 10),
                  Text('Günde ${AppConfig.dailyFreeWords} kelime. Sınırsız çalışma, tüm modlar ve reklamsız deneyim için Premium\'a geç.',
                      style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  ChunkyButton(
                    label: 'Premium\'a geç',
                    style: ChunkyStyle.sun,
                    onPressed: () => PaywallScreen.open(context, reason: PaywallReason.manual),
                  ),
                ]),
        ),
        const SizedBox(height: 12),
        // İstatistik özeti
        SectionCard(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            StatTile(value: '${app.studiedWordCount}', label: 'Çalışılan'),
            StatTile(value: '${app.masteredCount}', label: 'Ustalaşılan', color: AppColors.success),
            StatTile(value: '${app.bestStreak}', label: 'En uzun seri', color: AppColors.sunDeep),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgesScreen())),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Rozetlerim', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              const Icon(Icons.chevron_right_rounded),
            ]),
            Text('${earned.length} / ${allBadges.length} kazanıldı', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (earned.isEmpty)
              Text('İlk çalışmanı tamamlayınca ilk rozetini kazanırsın.', style: TextStyle(color: cs.onSurfaceVariant))
            else
              SizedBox(
                height: 64,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final b in earned.reversed.take(8))
                    Padding(padding: const EdgeInsets.only(right: 10), child: BadgeMedal(badge: b, size: 60)),
                ]),
              ),
          ]),
        ),
        if (!app.isPremium) ...[
          const SizedBox(height: 12),
          SectionCard(
            child: Row(children: [
              const Text('🧊', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Seri dondurma', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('${app.streakFreezes} / ${StreakState.maxFreezes} hak · Bir gün kaçırırsan serin bozulmaz.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
              TextButton(
                onPressed: app.streakFreezes >= StreakState.maxFreezes
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        if (!app.ads.isRewardedReady) {
                          app.ads.preloadRewarded();
                          messenger.showSnackBar(const SnackBar(content: Text('Reklam henüz hazır değil, biraz sonra dene.')));
                          return;
                        }
                        final ok = await app.watchAdForStreakFreeze();
                        messenger.showSnackBar(SnackBar(content: Text(ok ? 'Seri dondurma hakkı kazandın!' : 'Reklam tamamlanmadı.')));
                      },
                child: const Text('Reklam izle'),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        _Label('ÖĞRENME TERCİHLERİ'),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              title: const Text('Hedef seviye'),
              trailing: DropdownButton<String>(
                value: app.targetLevel,
                underline: const SizedBox.shrink(),
                items: [for (final l in levelOrder) DropdownMenuItem(value: l, child: Text('$l · ${levelNames[l]}'))],
                onChanged: (v) => app.setTargetLevel(v ?? app.targetLevel),
              ),
            ),
            ListTile(
              title: const Text('Telaffuz'),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'en-US', label: Text('🇺🇸 US')),
                  ButtonSegment(value: 'en-GB', label: Text('🇬🇧 UK')),
                ],
                selected: {app.accent},
                onSelectionChanged: (s) => app.setAccent(s.first),
              ),
            ),
            SwitchListTile(
              title: const Text('Otomatik seslendirme'),
              subtitle: const Text('Kart açılınca kelimeyi oku'),
              value: app.autoPlayAudio,
              onChanged: app.setAutoPlay,
            ),
            SwitchListTile(
              title: const Text('Titreşim'),
              subtitle: const Text('Doğru/yanlış cevapta hafif titreşim'),
              value: app.vibration,
              onChanged: app.setVibration,
            ),
            ListTile(
              title: const Text('Tema'),
              trailing: DropdownButton<String>(
                value: switch (app.themeMode) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' },
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('Sistem')),
                  DropdownMenuItem(value: 'light', child: Text('Açık')),
                  DropdownMenuItem(value: 'dark', child: Text('Koyu')),
                ],
                onChanged: (v) => app.setThemeMode(v ?? 'system'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        _Label('DİĞER'),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.star_rate_rounded),
              title: const Text('Uygulamayı Puanla'),
              onTap: () => openUrl(context, storeUrl),
            ),
            if (!app.isPremium)
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Reklam gizlilik tercihleri'),
                onTap: app.ads.showPrivacyOptions,
              ),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Satın alımı geri yükle'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await app.purchases.restore();
                messenger.showSnackBar(SnackBar(content: Text(ok ? 'Premium geri yüklendi.' : 'Aktif abonelik bulunamadı.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Gizlilik Politikası'),
              onTap: () => openUrl(context, AppConfig.privacyUrl),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: const Text('Kullanım Koşulları'),
              onTap: () => openUrl(context, AppConfig.termsUrl),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
              title: const Text('İlerlememi sıfırla', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Emin misin?'),
                    content: const Text('Tüm kelime ilerlemen, serin ve rozetlerin silinir. Bu işlem geri alınamaz. '
                        'Premium üyeliğin etkilenmez.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Sıfırla'),
                      ),
                    ],
                  ),
                );
                if (yes == true) await app.resetProgress();
              },
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('İlerlemen bu cihazda saklanır. Hesap ve bulut yedekleme yakında.',
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
      );
}

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Rozetlerim')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
        children: [
          for (final b in allBadges)
            Column(children: [
              BadgeMedal(badge: b, size: 78, locked: !app.earnedBadgeIds.contains(b.id)),
              const SizedBox(height: 8),
              Text(b.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(b.description,
                  textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]),
        ],
      ),
    );
  }
}
