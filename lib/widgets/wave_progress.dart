import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dalgalı dolum göstergesi (günlük hedef).
///
/// best-flutter-ui-templates/fitness_app/ui_view/wave_view.dart'tan uyarlandı
/// (MIT lisansı, © 2019 Mitesh Chodvadiya). Sadeleştirildi, null-safety ve
/// tema renkleriyle yeniden yazıldı.
class WaveProgress extends StatefulWidget {
  const WaveProgress({super.key, required this.percent, this.size = 120, this.label});

  /// 0..100
  final double percent;
  final double size;
  final String? label;

  @override
  State<WaveProgress> createState() => _WaveProgressState();
}

class _WaveProgressState extends State<WaveProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final p = widget.percent.clamp(0, 100).toDouble();
    return SizedBox(
      width: widget.size * 0.62,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => ClipRRect(
          borderRadius: BorderRadius.circular(widget.size),
          child: CustomPaint(
            painter: _WavePainter(phase: _c.value, percent: p, color: color),
            child: Center(
              child: Text(
                widget.label ?? '%${p.round()}',
                style: TextStyle(
                  color: p > 45 ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                  fontSize: widget.size * 0.17,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.phase, required this.percent, required this.color});
  final double phase;
  final double percent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.10));
    final level = size.height * (1 - percent / 100);
    for (final (shift, alpha) in [(0.0, 0.45), (math.pi, 1.0)]) {
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x++) {
        final y = level + math.sin((x / size.width * 2 * math.pi) + phase * 2 * math.pi + shift) * 4;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [color.withValues(alpha: 0.5 * alpha), color.withValues(alpha: alpha)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.phase != phase || old.percent != percent || old.color != color;
}
