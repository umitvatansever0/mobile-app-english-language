import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/purchase_service.dart';
import '../state/app_state.dart';
import 'links.dart';

enum PaywallReason { quota, feature, manual }

/// Premium ekranı. Kota dolduğunda ücretsiz kullanıcıya ödüllü reklam seçeneği de sunar.
/// `true` dönerse kullanıcı çalışmaya devam edebilir (premium aldı ya da reklamla hak kazandı).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.reason});
  final PaywallReason reason;

  static Future<bool> open(BuildContext context, {required PaywallReason reason}) async {
    final r = await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => PaywallScreen(reason: reason)),
    );
    return r ?? false;
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<PlanOption>? _plans;
  String _selected = 'annual';
  bool _busy = false;

  static const _benefits = [
    'Sınırsız günlük çalışma',
    '50 / 100 kelimelik seanslar',
    'Tüm kategoriler ve konu desteleri',
    'Ters yön ve dinle-yaz modları',
    'Kendi kelimelerini ekle',
    'Reklamsız deneyim',
  ];

  @override
  void initState() {
    super.initState();
    context.read<AppState>().purchases.loadPlans().then((p) {
      if (mounted) setState(() => _plans = p);
    });
  }

  Future<void> _buy() async {
    final plan = _plans?.where((p) => p.id == _selected).firstOrNull;
    if (plan == null) return;
    setState(() => _busy = true);
    final res = await context.read<AppState>().purchases.buy(plan);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (res) {
      case PurchaseOutcome.success:
        Navigator.pop(context, true);
      case PurchaseOutcome.cancelled:
        break;
      case PurchaseOutcome.notConfigured:
        _snack('Abonelik henüz etkin değil (mağaza ayarları yapılmadı).');
      case PurchaseOutcome.failed:
        _snack('Satın alma tamamlanamadı. Lütfen tekrar dene.');
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final ok = await context.read<AppState>().purchases.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      _snack('Geri yüklenecek aktif bir abonelik bulunamadı.');
    }
  }

  Future<void> _watchAd() async {
    final app = context.read<AppState>();
    if (!app.ads.isRewardedReady) {
      app.ads.preloadRewarded();
      _snack('Reklam henüz hazır değil, birkaç saniye sonra tekrar dene.');
      return;
    }
    setState(() => _busy = true);
    final ok = await app.watchAdForBonus();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      _snack('Ödül için reklamın sonuna kadar izlenmesi gerekiyor.');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final title = switch (widget.reason) {
      PaywallReason.quota => 'Bugünkü ücretsiz hakkın doldu',
      PaywallReason.feature => 'Bu özellik Premium\'a özel',
      PaywallReason.manual => 'Premium\'a geç',
    };

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [IconButton(icon: const Icon(Icons.close_rounded, size: 30), onPressed: () => Navigator.pop(context, false))],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('Premium\'a geçerek İngilizce öğrenmenin tüm özelliklerinin kilidini aç.',
              style: TextStyle(fontSize: 17, color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          for (final b in _benefits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(b, style: const TextStyle(fontSize: 16))),
              ]),
            ),
          const SizedBox(height: 24),
          if (_plans == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_plans!.isEmpty)
            Text('Planlar şu an yüklenemedi. İnternet bağlantını kontrol et.', style: TextStyle(color: cs.error))
          else
            for (final p in _plans!) ...[
              _PlanCard(plan: p, selected: _selected == p.id, best: p.id == 'annual', onTap: () => setState(() => _selected = p.id)),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 6),
          FilledButton(
            onPressed: (_plans?.isNotEmpty ?? false) ? _buy : null,
            child: _busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : const Text('Seçimi Onayla'),
          ),
          if (widget.reason == PaywallReason.quota && app.canWatchRewardedAd) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.ondemand_video_rounded),
              onPressed: _watchAd,
              label: Text('Reklam izle, +${AppConfig.rewardedBonusWords} kelime kazan'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Bugün ${AppConfig.maxRewardedAdsPerDay - app.today.adsWatched} reklam hakkın kaldı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Deneme süresi sonunda aboneliğin otomatik olarak ücretli üyeliğe dönüşür. İptal edilmediği sürece otomatik yenilenir. '
            'Aboneliğini Google Play veya App Store hesap ayarlarından istediğin zaman iptal edebilirsin.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          if (app.purchases.isTestMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Test modu: mağaza bağlantısı yapılandırılmadı, gerçek ödeme alınmaz.',
                  style: TextStyle(color: cs.error, fontSize: 13)),
            ),
          const SizedBox(height: 12),
          TextButton(onPressed: _restore, child: const Text('Satın Alımı Geri Yükle')),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => openUrl(context, AppConfig.termsUrl), child: const Text('Kullanım Koşulları')),
            TextButton(onPressed: () => openUrl(context, AppConfig.privacyUrl), child: const Text('Gizlilik Politikası')),
          ]),
        ]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.best, required this.onTap});
  final PlanOption plan;
  final bool selected, best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(plan.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(plan.subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
                  if (selected) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Seçildi', style: TextStyle(color: cs.primary))),
                ]),
              ),
              const SizedBox(width: 12),
              Text(plan.price, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
      if (best)
        Positioned(
          right: 20,
          top: -12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
            child: const Text('EN AVANTAJLI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
    ]);
  }
}
