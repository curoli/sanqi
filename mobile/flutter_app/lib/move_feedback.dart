import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const _audio = MethodChannel('com.curoli.sanqi/move_feedback');

enum MoveFeedback {
  off(sound: false, vibration: false),
  soundOnly(sound: true, vibration: false),
  vibrationOnly(sound: false, vibration: true),
  both(sound: true, vibration: true);

  const MoveFeedback({required this.sound, required this.vibration});

  final bool sound;
  final bool vibration;

  MoveFeedback get next => values[(index + 1) % values.length];

  void play({required bool gameOver}) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (vibration) unawaited(_tryFeedback(HapticFeedback.vibrate));
    if (sound) {
      final event = gameOver ? 'gameOver' : 'move';
      unawaited(_tryFeedback(() => _audio.invokeMethod<void>(event)));
    }
  }
}

Future<void> _tryFeedback(Future<void> Function() play) async {
  try {
    await play();
  } on PlatformException {
    // Device feedback is best effort and must not interrupt the game.
  } on MissingPluginException {
    // The host may not implement sound playback, for example in Flutter tests.
  }
}

class MoveFeedbackIcon extends StatelessWidget {
  const MoveFeedbackIcon(this.mode, {super.key});

  final MoveFeedback mode;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(28, 24),
    painter: _FeedbackGlyph(
      mode,
      IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _FeedbackGlyph extends CustomPainter {
  _FeedbackGlyph(this.mode, this.color);

  final MoveFeedback mode;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final speaker = Path()
      ..moveTo(8, 9)
      ..lineTo(12, 9)
      ..lineTo(17, 5)
      ..lineTo(17, 19)
      ..lineTo(12, 15)
      ..lineTo(8, 15)
      ..close();
    canvas.drawPath(speaker, Paint()..color = color);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    if (!mode.sound) {
      canvas.drawLine(const Offset(8, 3), const Offset(21, 20), stroke);
    }
    if (mode.vibration) {
      for (final x in [5.0, 23.0]) {
        final wave = Path()
          ..moveTo(x, 6)
          ..relativeQuadraticBezierTo(-3, 3, 0, 6)
          ..relativeQuadraticBezierTo(3, 3, 0, 6);
        canvas.drawPath(wave, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_FeedbackGlyph oldDelegate) =>
      oldDelegate.mode != mode || oldDelegate.color != color;
}
