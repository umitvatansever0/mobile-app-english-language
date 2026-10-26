import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/purchase_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';
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
    final pal = Pal.of(context);
    final title = switch (widget.reason) {
      PaywallReason.quota => 'Bugünkü ücretsiz hakkın doldu',
      PaywallReason.feature => 'Bu özellik Premium\'a özel',
      PaywallReason.manual => 'Premium ile sınırsız öğren',
    };

    return Scaffold(
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(padding: EdgeInsets.zero, children: [
          // Üst turkuaz panel
          Container(
            padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 8, 12, 26),
            decoration: const BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [BoxShadow(color: AppColors.tealDeep, offset: Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Tag('PREMIUM'),
                const Spacer(),
                IconButton(
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close_rounded, size: 30, color: Colors.white),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ]),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 8),
              const Text('Günlük sınır olmadan, reklamsız ve tüm modlarla çalış.',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              for (final b in _benefits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(color: AppColors.sun, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 17, color: AppColors.sunInk),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800))),
                  ]),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!app.purchases.available)
                ChunkyCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Premium çok yakında!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: pal.ink)),
                    const SizedBox(height: 4),
                    Text('Abonelik henüz açılmadı. Şimdilik reklam izleyerek ek kelime hakkı kazanabilirsin.',
                        style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700)),
                  ]),
                )
              else if (_plans == null)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_plans!.isEmpty)
                Text('Planlar şu an yüklenemedi. İnternet bağlantını kontrol et.',
                    style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w800))
              else
                for (final p in _plans!) ...[
                  _PlanCard(plan: p, selected: _selected == p.id, best: p.id == 'annual', onTap: () => setState(() => _selected = p.id)),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 4),
              if (app.purchases.available)
                ChunkyButton(
                  label: 'Seçimi onayla',
                  loading: _busy,
                  onPressed: (_plans?.isNotEmpty ?? false) ? _buy : null,
                ),
              if (widget.reason == PaywallReason.quota && app.canWatchRewardedAd) ...[
                const SizedBox(height: 12),
                ChunkyButton(
                  label: 'Reklam izle, +${AppConfig.rewardedBonusWords} kelime kazan',
                  icon: Icons.ondemand_video_rounded,
                  style: ChunkyStyle.sun,
                  onPressed: _watchAd,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    AppConfig.maxRewardedAdsPerDay == null
                        ? 'Her reklam +${AppConfig.rewardedBonusWords} kelime hakkı verir.'
                        : 'Bugün ${AppConfig.maxRewardedAdsPerDay! - app.today.adsWatched} reklam hakkın kaldı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: pal.muted, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (app.purchases.available)
                Text(
                'Deneme süresi sonunda aboneliğin otomatik olarak ücretli üyeliğe dönüşür. İptal edilmediği sürece otomatik yenilenir. '
                'Aboneliğini Google Play veya App Store hesap ayarlarından istediğin zaman iptal edebilirsin.',
                style: TextStyle(color: pal.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              if (app.purchases.isTestMode && kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Test modu: mağaza bağlantısı yapılandırılmadı, gerçek ödeme alınmaz.',
                      style: TextStyle(color: AppColors.rose, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              const SizedBox(height: 8),
              if (app.purchases.available)
                TextButton(onPressed: _restore, child: const Text('Satın alımı geri yükle')),
              Wrap(alignment: WrapAlignment.center, children: [
                TextButton(onPressed: () => openUrl(context, AppConfig.termsUrl), child: const Text('Kullanım koşulları')),
                TextButton(onPressed: () => openUrl(context, AppConfig.privacyUrl), child: const Text('Gizlilik politikası')),
              ]),
            ]),
          ),
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
    final pal = Pal.of(context);
    return Stack(clipBehavior: Clip.none, children: [
      ChunkyCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        borderColor: selected ? AppColors.teal : null,
        color: selected ? (pal.dark ? const Color(0xFF123533) : AppColors.tealSoft) : null,
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.teal : pal.lockInk),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: pal.ink)),
              const SizedBox(height: 2),
              Text(plan.subtitle, style: TextStyle(color: pal.muted, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(plan.price, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: pal.ink)),
        ]),
      ),
      if (best) const Positioned(right: 16, top: -12, child: Tag('EN AVANTAJLI')),
    ]);
  }
}
