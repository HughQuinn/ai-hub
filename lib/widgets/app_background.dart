import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 全屏背景层：多层径向渐变 + 缓慢漂浮的柔光圆
class AppBackground extends StatefulWidget {
  final bool isDark;

  const AppBackground({super.key, required this.isDark});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return CustomPaint(
          painter: _BackgroundPainter(
            isDark: widget.isDark,
            animValue: _animController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// 柔光圆定义
class _Orb {
  final double x; // 基准 x 位置 (0~1)
  final double y; // 基准 y 位置 (0~1)
  final double radius; // 半径 (像素)
  final Color color;
  final double speedX; // 水平漂移速度
  final double speedY; // 垂直漂移速度
  final double phaseX; // 相位偏移
  final double phaseY;

  const _Orb({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.speedX,
    required this.speedY,
    required this.phaseX,
    required this.phaseY,
  });
}

class _BackgroundPainter extends CustomPainter {
  final bool isDark;
  final double animValue;

  _BackgroundPainter({required this.isDark, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBaseGradient(canvas, size);
    _drawOrbs(canvas, size);
  }

  /// 绘制多层径向渐变底色
  void _drawBaseGradient(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 底色
    canvas.drawRect(
      rect,
      Paint()
        ..color =
            isDark ? const Color(0xFF0A0D12) : const Color(0xFFF5F2EE),
    );

    // 左上角青色
    _drawRadialLayer(
      canvas,
      center: Offset(size.width * 0.15, size.height * -0.05),
      radius: size.width * 0.65,
      color: isDark
          ? const Color(0x2D0D9488) // 18% — teal
          : const Color(0x2114B8A6), // 13% — light teal
    );

    // 右下角紫
    _drawRadialLayer(
      canvas,
      center: Offset(size.width * 0.85, size.height * 1.05),
      radius: size.width * 0.55,
      color: isDark
          ? const Color(0x267C3AED) // 15%
          : const Color(0x1F8B5CF6), // 12%
    );

    // 中上青色（深色模式更明显）
    if (isDark) {
      _drawRadialLayer(
        canvas,
        center: Offset(size.width * 0.5, size.height * 0.15),
        radius: size.width * 0.45,
        color: const Color(0x1A0D9488), // 10% — teal
      );
    }
  }

  void _drawRadialLayer(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
      paint,
    );
  }

  /// 绘制漂浮柔光圆
  void _drawOrbs(Canvas canvas, Size size) {
    final orbs = _getOrbs();
    final t = animValue * 2 * math.pi; // 一圈 20 秒

    for (final orb in orbs) {
      // 正弦漂移：每个圆独立的水平/垂直运动
      final dx = math.sin(t * orb.speedX + orb.phaseX) * size.width * 0.06;
      final dy = math.cos(t * orb.speedY + orb.phaseY) * size.height * 0.05;

      final center = Offset(
        orb.x * size.width + dx,
        orb.y * size.height + dy,
      );

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [orb.color, Colors.transparent],
          stops: const [0.0, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: orb.radius),
        );

      canvas.drawCircle(center, orb.radius, paint);
    }
  }

  List<_Orb> _getOrbs() {
    if (isDark) {
      return const [
        // 大号青 — 左上
        _Orb(
          x: 0.18, y: 0.12, radius: 130,
          color: Color(0x400D9488), // 25%
          speedX: 0.3, speedY: 0.2, phaseX: 0, phaseY: 1.5,
        ),
        // 中号紫 — 右上
        _Orb(
          x: 0.78, y: 0.25, radius: 100,
          color: Color(0x3A8B5CF6), // 23%
          speedX: 0.25, speedY: 0.35, phaseX: 2.0, phaseY: 0.5,
        ),
        // 小号青 — 中上
        _Orb(
          x: 0.5, y: 0.05, radius: 70,
          color: Color(0x3314B8A6), // 20%
          speedX: 0.4, speedY: 0.15, phaseX: 1.0, phaseY: 3.0,
        ),
        // 中号靛 — 右中
        _Orb(
          x: 0.82, y: 0.65, radius: 95,
          color: Color(0x2D6366F1), // 18%
          speedX: 0.2, speedY: 0.3, phaseX: 3.5, phaseY: 1.0,
        ),
        // 小号粉紫 — 左下
        _Orb(
          x: 0.28, y: 0.78, radius: 65,
          color: Color(0x2CD946EF), // 17%
          speedX: 0.35, speedY: 0.25, phaseX: 0.8, phaseY: 2.5,
        ),
        // 大号深青 — 底部
        _Orb(
          x: 0.15, y: 0.92, radius: 110,
          color: Color(0x330F766E), // 20%
          speedX: 0.15, speedY: 0.4, phaseX: 4.0, phaseY: 0,
        ),
        // 小号青绿 — 中右
        _Orb(
          x: 0.65, y: 0.52, radius: 55,
          color: Color(0x2614B8A6), // 15%
          speedX: 0.3, speedY: 0.2, phaseX: 2.5, phaseY: 1.8,
        ),
        // 中号靛蓝 — 正中
        _Orb(
          x: 0.42, y: 0.42, radius: 80,
          color: Color(0x226366F1), // 13%
          speedX: 0.22, speedY: 0.28, phaseX: 1.2, phaseY: 3.8,
        ),
      ];
    } else {
      return const [
        // 暖粉 — 左上
        _Orb(
          x: 0.2, y: 0.08, radius: 120,
          color: Color(0x24F9A8D4), // 14%
          speedX: 0.3, speedY: 0.2, phaseX: 0, phaseY: 1.5,
        ),
        // 薰衣草 — 右上
        _Orb(
          x: 0.8, y: 0.3, radius: 95,
          color: Color(0x21C4B5FD), // 13%
          speedX: 0.25, speedY: 0.3, phaseX: 2.0, phaseY: 0.5,
        ),
        // 淡紫 — 下中
        _Orb(
          x: 0.5, y: 0.82, radius: 105,
          color: Color(0x218B5CF6), // 13%
          speedX: 0.2, speedY: 0.35, phaseX: 3.5, phaseY: 1.0,
        ),
        // 青绿 — 左中
        _Orb(
          x: 0.1, y: 0.58, radius: 80,
          color: Color(0x1A14B8A6), // 10%
          speedX: 0.35, speedY: 0.15, phaseX: 1.0, phaseY: 3.0,
        ),
        // 琥珀 — 右上
        _Orb(
          x: 0.72, y: 0.12, radius: 70,
          color: Color(0x1AFBBF24), // 10%
          speedX: 0.28, speedY: 0.22, phaseX: 0.8, phaseY: 2.5,
        ),
      ];
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        (oldDelegate.animValue - animValue).abs() > 0.001;
  }
}
