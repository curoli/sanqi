import 'package:material_ui/material_ui.dart';

/// A quiet diamond lattice in the board's warm palette.
class GameBackground extends CustomPainter {
  const GameBackground();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFE9DFC9), BlendMode.srcOver);
    final paint = Paint()
      ..color = const Color(0x246F775E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 48.0;
    final path = Path();
    for (var offset = -size.height; offset < size.width; offset += step) {
      path.moveTo(offset, 0);
      path.lineTo(offset + size.height, size.height);
    }
    for (var offset = 0.0; offset < size.width + size.height; offset += step) {
      path.moveTo(offset, 0);
      path.lineTo(offset - size.height, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GameBackground oldDelegate) => false;
}
