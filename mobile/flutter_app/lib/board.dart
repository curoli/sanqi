import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'src/rust/api/game.dart';

String squareName(int square) =>
    '${String.fromCharCode(97 + square % 8)}${square ~/ 8 + 1}';

int? squareAt(Offset point, double side) {
  if (side <= 0 ||
      point.dx < 0 ||
      point.dy < 0 ||
      point.dx >= side ||
      point.dy >= side) {
    return null;
  }
  final file = (point.dx * 8 / side).floor();
  final row = (point.dy * 8 / side).floor();
  return (7 - row) * 8 + file;
}

class SanqiBoard extends StatelessWidget {
  const SanqiBoard({
    super.key,
    required this.view,
    required this.onTap,
    required this.onInspect,
    required this.enabled,
  });

  final GameView view;
  final ValueChanged<int> onTap;
  final ValueChanged<String> onInspect;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final moves = view.legalMoves
        .where((move) => move.from == view.selected)
        .toList();
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          key: const Key('board'),
          behavior: HitTestBehavior.opaque,
          onTapUp: enabled
              ? (details) {
                  final square = squareAt(
                    details.localPosition,
                    constraints.maxWidth,
                  );
                  if (square != null) onTap(square);
                }
              : null,
          onLongPressStart: enabled
              ? (details) {
                  final square = squareAt(
                    details.localPosition,
                    constraints.maxWidth,
                  );
                  for (final move in moves) {
                    if (move.to == square) {
                      onInspect(move.notation);
                      break;
                    }
                  }
                }
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.string(view.svg, fit: BoxFit.fill),
              IgnorePointer(
                child: CustomPaint(painter: _BoardMarkers(view, moves)),
              ),
              for (var square = 0; square < 64; square++)
                Positioned(
                  left: square % 8 * constraints.maxWidth / 8,
                  top: (7 - square ~/ 8) * constraints.maxWidth / 8,
                  width: constraints.maxWidth / 8,
                  height: constraints.maxWidth / 8,
                  child: Semantics(
                    label: squareName(square),
                    button: true,
                    selected: view.selected == square,
                    onTap: enabled ? () => onTap(square) : null,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardMarkers extends CustomPainter {
  _BoardMarkers(this.view, this.moves);

  final GameView view;
  final List<MobileMove> moves;

  @override
  void paint(Canvas canvas, Size size) {
    final tile = size.width / 8;
    Offset center(int square) =>
        Offset((square % 8 + .5) * tile, (7 - square ~/ 8 + .5) * tile);
    final selected = view.selected;
    if (selected != null) {
      canvas.drawCircle(
        center(selected),
        tile * .43,
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
    for (final move in moves) {
      canvas.drawCircle(
        center(move.to),
        tile * .15,
        Paint()..color = const Color(0xDD107347),
      );
    }
    final supports = <int>{};
    for (final pair in view.supports) {
      supports.addAll([pair.first, pair.second]);
    }
    for (final square in supports) {
      canvas.drawCircle(
        center(square),
        tile * .36,
        Paint()
          ..color = Colors.lightBlueAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    for (final pair in view.supports) {
      canvas.drawCircle(
        Offset(
          (pair.fileTwice + 1) * tile / 2,
          (15 - pair.rankTwice) * tile / 2,
        ),
        tile * .10,
        Paint()..color = Colors.lightBlueAccent,
      );
    }
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var file = 0; file < 8; file++) {
      textPainter.text = TextSpan(
        text: String.fromCharCode(97 + file),
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((file + 1) * tile - 10, size.height - 13),
      );
    }
    for (var row = 0; row < 8; row++) {
      textPainter.text = TextSpan(
        text: '${8 - row}',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, row * tile + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _BoardMarkers oldDelegate) =>
      oldDelegate.view != view;
}
