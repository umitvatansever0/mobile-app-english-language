import 'package:flutter/material.dart';

import '../logic/session_builder.dart';
import '../theme/app_theme.dart';

enum NodeState { passed, current, upcoming }

class LevelNodeInfo {
  const LevelNodeInfo({required this.level, required this.state, required this.studied, required this.total});
  final String level;
  final NodeState state;
  final int studied;
  final int total;

  int get percent => total == 0 ? 0 : (studied * 100 / total).floor();
}

const levelNames = {
  'A1': 'Başlangıç',
  'A2': 'Temel',
  'B1': 'Orta',
  'B2': 'İyi',
  'C1': 'İleri',
  'C2': 'Uzman',
};

/// A1'den C2'ye zikzak "seviye yolculuğu" (Turkuaz Yolculuk imza öğesi).
class LevelPath extends StatelessWidget {
  const LevelPath({super.key, required this.nodes, required this.onTap});
  final List<LevelNodeInfo> nodes;
  final ValueChanged<String> onTap;

  static const _step = 92.0;
  static const _node = 66.0;
  static const _cur = 86.0;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      Offset center(int i) => Offset(i.isEven ? w * 0.18 : w * 0.62, 50 + i * _step);
      final centers = [for (var i = 0; i < nodes.length; i++) center(i)];
      return SizedBox(
        height: 50 + (nodes.length - 1) * _step + 60,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: _DashPainter(centers, pal.dark ? const Color(0xFF2A4846) : const Color(0xFFCFE4E0)))),
          for (var i = 0; i < nodes.length; i++) ..._buildNode(nodes[i], centers[i], pal),
        ]),
      );
    });
  }

  List<Widget> _buildNode(LevelNodeInfo n, Offset c, Pal pal) {
    final size = n.state == NodeState.current ? _cur : _node;
    final (bg, lip, ink, border) = switch (n.state) {
      NodeState.passed => (AppColors.emerald, AppColors.emeraldDeep, Colors.white, null),
      NodeState.current => (pal.card, AppColors.tealDeep, pal.dark ? pal.ink : AppColors.tealDeep, AppColors.teal),
      NodeState.upcoming => (pal.lockBg, pal.lockLip, pal.lockInk, null),
    };
    final label = switch (n.state) {
      NodeState.current => '${n.level} · %${n.percent}',
      NodeState.passed => n.level,
      NodeState.upcoming => n.level,
    };
    final sub = switch (n.state) {
      NodeState.current => 'Şu anki hedefin',
      NodeState.passed => '${levelNames[n.level]} · %${n.percent}',
      NodeState.upcoming => levelNames[n.level] ?? '',
    };
    return [
      Positioned(
        left: c.dx - size / 2,
        top: c.dy - size / 2,
        child: Semantics(
          button: true,
          label: '${n.level} seviyesi',
          child: GestureDetector(
            onTap: () => onTap(n.level),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                border: border == null ? null : Border.all(color: border, width: 7),
                boxShadow: [BoxShadow(color: lip, offset: const Offset(0, 6))],
              ),
              alignment: Alignment.center,
              child: n.state == NodeState.upcoming
                  ? Icon(Icons.lock_rounded, color: ink, size: 24)
                  : Text(n.level,
                      style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: n.state == NodeState.current ? 23 : 19)),
            ),
          ),
        ),
      ),
      Positioned(
        left: c.dx + size / 2 + 12,
        top: c.dy - 20,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: n.state == NodeState.current ? 17 : 15,
                  color: n.state == NodeState.upcoming ? pal.lockInk : pal.ink)),
          Text(sub, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: pal.muted)),
        ]),
      ),
    ];
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.points, this.color);
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 18) {
        final seg = m.extractPath(d, d + 2);
        canvas.drawPath(seg, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.points != points || old.color != color;
}

/// Seviye yolundaki düğüm bilgilerini üretir.
List<LevelNodeInfo> buildLevelNodes(String target, ({int studied, int total}) Function(String level) stats) {
  final t = levelOrder.indexOf(target);
  return [
    for (var i = 0; i < levelOrder.length; i++)
      () {
        final s = stats(levelOrder[i]);
        return LevelNodeInfo(
          level: levelOrder[i],
          state: i < t ? NodeState.passed : (i == t ? NodeState.current : NodeState.upcoming),
          studied: s.studied,
          total: s.total,
        );
      }(),
  ];
}
