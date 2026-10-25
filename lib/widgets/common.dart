import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';

import '../logic/badges.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Sağ üstteki seri rozeti (🔥 n).
class StreakChip extends StatelessWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.select<AppState, int>((a) => a.streak);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3A2418) : AppColors.streakBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 22),
        const SizedBox(width: 4),
        Text('$s', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800, fontSize: 18)),
      ]),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// Büyük sayı + altında etiket (Kart Sonuçları vb.)
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
    final ring = locked ? Colors.grey.shade400 : badge.tier.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [ring, Color.lerp(ring, Colors.white, 0.55)!, ring, Color.lerp(ring, Colors.black, 0.2)!, ring]),
        boxShadow: locked ? null : [BoxShadow(color: ring.withValues(alpha: 0.35), blurRadius: size / 6, offset: Offset(0, size / 20))],
      ),
      padding: EdgeInsets.all(size * 0.07),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: locked
                ? [Colors.grey.shade200, Colors.grey.shade300]
                : [const Color(0xFFF7F4FF), const Color(0xFFD9CFFA)],
          ),
        ),
        child: Icon(locked ? Icons.lock_rounded : badge.icon,
            size: size * 0.48, color: locked ? Colors.grey.shade500 : AppColors.accent),
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
