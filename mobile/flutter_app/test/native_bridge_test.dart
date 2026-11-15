import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/game_service.dart';
import 'package:flutter_app/src/rust/api/game.dart';
import 'package:flutter_app/src/rust/frb_generated.dart';

void main() {
  test(
    'real Rust session survives preview, play, save, restore and undo',
    () async {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(
          '../../target/debug/libsanqi_mobile.so',
        ),
      );
      final game = await createGame();
      final initial = await game.view();
      expect(initial.sideToMove, 'White');
      expect(initial.svg, contains('<svg'));
      final move = initial.legalMoves.first;
      final preview = await game.inspectMove(notation: move.notation);
      expect(preview.supports, isNotEmpty);
      expect(preview.movetext, isEmpty);
      final played = await game.tap(index: move.to);
      expect(played.sideToMove, 'Black');
      expect(played.movetext, contains(move.notation));
      await game.newGame();
      expect((await game.restore(movetext: played.movetext)).svg, played.svg);
      await expectLater(game.restore(movetext: 'invalid'), throwsA(anything));
      expect((await game.view()).movetext, played.movetext);
      expect((await game.undo()).svg, initial.svg);
      final opening = await game.startGame(humanColor: 'Black');
      expect(opening.computerTurn, isTrue);
      final reply = await findComputerMove(movetext: opening.movetext);
      expect(reply, isNotNull);
      final playedOpening = await game.applyComputerMove(
        expectedRevision: opening.revision,
        notation: reply!,
      );
      expect(playedOpening.sideToMove, 'Black');
      expect(playedOpening.computerTurn, isFalse);
      final humanTurn = await RustGameService(game).computerTurn();
      expect(humanTurn?.movetext, playedOpening.movetext);
      expect(humanTurn?.computerTurn, isFalse);
      final spectators = await RustGameService(game).startGame('Computer');
      expect(spectators.computerBoth, isTrue);
      final cancelled = await game.cancelSearch();
      expect(cancelled.revision, greaterThan(spectators.revision));
      final stale = await game.applyComputerMove(
        expectedRevision: spectators.revision,
        notation: spectators.legalMoves.first.notation,
      );
      expect(stale.movetext, isEmpty);
      final computerWhite = await RustGameService(game).computerTurn();
      expect(computerWhite?.sideToMove, 'Black');
      expect(computerWhite?.computerTurn, isTrue);
      expect((await game.newGame()).computerBoth, isTrue);
      game.dispose();
      RustLib.dispose();
    },
    skip: !Platform.isLinux,
  );
}
