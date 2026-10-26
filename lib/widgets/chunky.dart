import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ChunkyStyle { primary, sun, success, danger, ghost, white }

/// Basınca aşağı "çöken", alt kenarı koyu "tok" düğme (Turkuaz Yolculuk imzası).
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = ChunkyStyle.primary,
    this.icon,
    this.height = 56,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ChunkyStyle style;
  final IconData? icon;
  final double height;
  final bool loading;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;
  static const _lip = 5.0;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    var (face, lip, ink, border) = switch (widget.style) {
      ChunkyStyle.primary => (AppColors.teal, AppColors.tealDeep, Colors.white, null),
      ChunkyStyle.sun => (AppColors.sun, AppColors.sunDeep, AppColors.sunInk, null),
      ChunkyStyle.success => (AppColors.emerald, AppColors.emeraldDeep, Colors.white, null),
      ChunkyStyle.danger => (AppColors.rose, AppColors.roseDeep, Colors.white, null),
      ChunkyStyle.ghost => (pal.card, pal.border, pal.dark ? pal.ink : AppColors.tealDeep, pal.border),
      ChunkyStyle.white => (Colors.white, const Color(0xFFBFE6E1), AppColors.tealDeep, null),
    };
    if (!enabled && !widget.loading) {
      face = pal.lockBg;
      lip = pal.lockLip;
      ink = pal.lockInk;
      border = null;
    }
    final pressed = _down && enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: SizedBox(
          height: widget.height + _lip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            margin: EdgeInsets.only(top: pressed ? _lip : 0, bottom: pressed ? 0 : _lip),
            decoration: BoxDecoration(
              color: face,
              borderRadius: BorderRadius.circular(18),
              border: border == null ? null : Border.all(color: border, width: 3),
              boxShadow: [BoxShadow(color: lip, offset: Offset(0, pressed ? 0 : _lip))],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: widget.loading
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: ink))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[Icon(widget.icon, color: ink, size: 22), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 17, height: 1.1)),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Kenarlıklı ve alt "dudağı" olan kart.
class ChunkyCard extends StatelessWidget {
  const ChunkyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.lip = 5,
    this.radius = 24,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double lip;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final bc = borderColor ?? pal.border;
    final r = BorderRadius.circular(radius);
    return Padding(
      padding: EdgeInsets.only(bottom: lip),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [BoxShadow(color: bc, offset: Offset(0, lip))],
        ),
        child: Material(
          color: color ?? pal.card,
          shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: bc, width: 2.5)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

/// Kalın, yuvarlak uçlu ilerleme çubuğu.
class ChunkyProgress extends StatelessWidget {
  const ChunkyProgress({super.key, required this.value, this.height = 16, this.color = AppColors.teal, this.track});
  final double value;
  final double height;
  final Color color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(color: track ?? Pal.of(context).track, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: v == 0
          ? null
          : FractionallySizedBox(
        widthFactor: v,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), offset: Offset(0, -height / 4), spreadRadius: -height / 4)],
          ),
        ),
      ),
    );
  }
}

/// Küçük renkli etiket ("Fiil · B1").
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = AppColors.sun, this.ink = AppColors.sunInk});
  final String text;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 13)),
      );
}

/// Bölüm başlığı.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(children: [
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Pal.of(context).ink)),
          ),
          ?trailing,
        ]),
      );
}
