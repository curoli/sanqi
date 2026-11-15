import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_skin.dart';

/// Low-contrast geometric patterns, independent of board rendering.
class GameBackground extends CustomPainter {
  const GameBackground({this.skin = AppSkin.linen});
  final AppSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(skin.background, BlendMode.srcOver);
    final paint = Paint()
      ..color = skin.accent.withValues(
        alpha: skin.brightness == Brightness.dark ? .15 : .1,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    const step = 48.0;
    switch (skin.pattern) {
      case SkinPattern.diamonds:
      case SkinPattern.lines:
        for (var offset = -size.height; offset < size.width; offset += step) {
          path.moveTo(offset, 0);
          path.lineTo(offset + size.height, size.height);
        }
        if (skin.pattern == SkinPattern.diamonds) {
          for (
            var offset = 0.0;
            offset < size.width + size.height;
            offset += step
          ) {
            path.moveTo(offset, 0);
            path.lineTo(offset - size.height, size.height);
          }
        }
      case SkinPattern.grid:
        for (var x = 0.0; x < size.width; x += step) {
          path.moveTo(x, 0);
          path.lineTo(x, size.height);
        }
        for (var y = 0.0; y < size.height; y += step) {
          path.moveTo(0, y);
          path.lineTo(size.width, y);
        }
      case SkinPattern.waves:
        for (var y = -step; y < size.height + step; y += step) {
          path.moveTo(0, y);
          for (var x = 0.0; x < size.width; x += step * 2) {
            path.relativeQuadraticBezierTo(step / 2, -step / 2, step, 0);
            path.relativeQuadraticBezierTo(step / 2, step / 2, step, 0);
          }
        }
      case SkinPattern.sunburst:
        final center = Offset(size.width * .7, size.height * .2);
        final reach = size.longestSide * 2;
        for (var i = 0; i < 24; i++) {
          final angle = i * math.pi / 12;
          path.moveTo(center.dx, center.dy);
          path.lineTo(
            center.dx + math.cos(angle) * reach,
            center.dy + math.sin(angle) * reach,
          );
        }
      case SkinPattern.dots:
      case SkinPattern.stars:
      case SkinPattern.tiles:
      case SkinPattern.circles:
      case SkinPattern.confetti:
        for (var row = 0; row * step < size.height; row++) {
          for (var col = 0; col * step < size.width; col++) {
            final x = col * step + (row.isEven ? 12 : 28);
            final y = row * step + 12;
            switch (skin.pattern) {
              case SkinPattern.dots:
                canvas.drawCircle(
                  Offset(x, y),
                  2,
                  paint..style = PaintingStyle.fill,
                );
              case SkinPattern.stars:
                path.moveTo(x - 3, y);
                path.lineTo(x + 3, y);
                path.moveTo(x, y - 3);
                path.lineTo(x, y + 3);
              case SkinPattern.tiles:
                canvas.drawRect(Rect.fromLTWH(x, y, 8, 8), paint);
                if ((row + col) % 3 == 0) {
                  canvas.drawRect(Rect.fromLTWH(x + 8, y + 8, 8, 8), paint);
                }
              case SkinPattern.circles:
                canvas.drawCircle(Offset(x, y), 17, paint);
              case SkinPattern.confetti:
                path.moveTo(x, y);
                path.lineTo(x + (col.isEven ? 8 : -8), y + 8);
                canvas.drawCircle(Offset(x + 17, y + 21), 3, paint);
              default:
                break;
            }
          }
        }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GameBackground oldDelegate) =>
      oldDelegate.skin != skin;
}
