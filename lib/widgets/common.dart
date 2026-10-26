import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import '../logic/badges.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'chunky.dart';

/// Sağ üstteki seri rozeti (güneş sarısı, tok).
class StreakChip extends StatelessWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.select<AppState, int>((a) => a.streak);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sun,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.sunDeep, offset: Offset(0, 4))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department_rounded, color: AppColors.sunInk, size: 22),
        const SizedBox(width: 3),
        Text('$s', style: const TextStyle(color: AppColors.sunInk, fontWeight: FontWeight.w900, fontSize: 18)),
      ]),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ChunkyCard(padding: padding, onTap: onTap, child: child);
}

/// Büyük sayı + altında etiket (Kart Sonuçları vb.)
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color ?? Pal.of(context).ink)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Pal.of(context).muted, fontWeight: FontWeight.w700)),
      ]);
}

/// Rozet madalyası (kod ile çizilir, harici görsel gerekmez).
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.badge, this.size = 64, this.locked = false});
  final BadgeDef badge;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final ring = locked ? pal.lockBg : badge.tier.color;
    final lip = locked ? pal.lockLip : Color.lerp(badge.tier.color, Colors.black, 0.25)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring,
        boxShadow: [BoxShadow(color: lip, offset: Offset(0, size / 14))],
      ),
      padding: EdgeInsets.all(size * 0.09),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: locked ? pal.card : Colors.white),
        child: Icon(locked ? Icons.lock_rounded : badge.icon,
            size: size * 0.46, color: locked ? pal.lockInk : AppColors.tealDeep),
      ),
    );
  }
}

/// Ücretsiz kullanıcılar için alt banner reklam (premium'da gösterilmez).
class BannerAdBox extends StatefulWidget {
  const BannerAdBox({super.key});
  @override
  State<BannerAdBox> createState() => _BannerAdBoxState();
}

class _BannerAdBoxState extends State<BannerAdBox> {
  BannerAd? _ad;
  bool _loaded = false;

  late final AppState _app = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _app.ads.ready.addListener(_maybeLoad);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
  }

  void _maybeLoad() {
    if (!mounted || _ad != null || _app.isPremium || !_app.ads.ready.value) return;
    _ad = _app.ads.createBanner(onLoaded: () {
      if (mounted) setState(() => _loaded = true);
    })
      ..load();
  }

  @override
  void dispose() {
    _app.ads.ready.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.select<AppState, bool>((a) => a.isPremium);
    if (premium || !_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
