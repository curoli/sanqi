import 'dart:async';

import 'package:flutter_app/game_service.dart';
import 'package:flutter_app/src/rust/api/game.dart';
import 'package:flutter_test/flutter_test.dart';

// Models a bridge queue that may execute view() after a later cancellation.
class QueuedGame implements MobileGame {
  final releaseView = Completer<void>();
  int revision = 0;
  int appliedMoves = 0;
  int submittedMoves = 0;

  GameView get current => GameView(
    computerBoth: true,
    revision: BigInt.from(revision),
    computerTurn: true,
    svg: '',
    sideToMove: appliedMoves.isEven ? 'White' : 'Black',
    legalMoves: const [],
    supports: const [],
    movetext: appliedMoves == 0 ? '' : '1. a1-b3',
    canUndo: appliedMoves > 0,
  );

  @override
  Future<GameView> view() async {
    await releaseView.future;
    return current;
  }

  @override
  Future<GameView> cancelSearch() async {
    revision++;
    return current;
  }

  @override
  Future<GameView> applyComputerMove({
    required BigInt expectedRevision,
    required String notation,
  }) async {
    submittedMoves++;
    if (expectedRevision == BigInt.from(revision)) {
      appliedMoves++;
      revision++;
    }
    return current;
  }

  @override
  Future<GameView> newGame() => cancelSearch();
  @override
  Future<GameView> undo() => cancelSearch();
  @override
  Future<GameView> restore({required String movetext}) => cancelSearch();
  @override
  Future<GameView> startGame({String? humanColor}) => cancelSearch();
  @override
  Future<GameView> startComputerGame() => cancelSearch();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final actions = <String, Future<GameView> Function(RustGameService)>{
    'pause': (service) => service.cancelSearch(),
    'new game': (service) => service.newGame(),
    'undo': (service) => service.undo(),
    'restore': (service) => service.restore(''),
    'human mode': (service) => service.startGame('Black'),
    'spectator mode': (service) => service.startGame('Computer'),
  };
  for (final action in actions.entries) {
    test(
      '${action.key} cancels a turn before its queued snapshot runs',
      () async {
        final game = QueuedGame();
        var searches = 0;
        final service = RustGameService(
          game,
          findMove: (_) async {
            searches++;
            return 'a1-b3';
          },
        );
        final turn = service.computerTurn();
        final cancelled = await action.value(service);
        game.releaseView.complete();
        expect(await turn, isNull);
        expect(searches, 0);
        expect(game.appliedMoves, 0);
        expect(game.submittedMoves, 0);
        expect(game.current.revision, cancelled.revision);
        expect(game.current.movetext, cancelled.movetext);

        // Cancellation only affects old turns: resuming can still play a move.
        final resumed = await service.computerTurn();
        expect(resumed?.movetext, '1. a1-b3');
        expect(searches, 1);
        expect(game.appliedMoves, 1);
      },
    );
  }

  test('pause during search prevents submitting its result', () async {
    final game = QueuedGame()..releaseView.complete();
    final started = Completer<void>();
    final result = Completer<String?>();
    final service = RustGameService(
      game,
      findMove: (_) {
        started.complete();
        return result.future;
      },
    );
    final turn = service.computerTurn();
    await started.future;
    final cancelled = await service.cancelSearch();
    result.complete('a1-b3');
    expect(await turn, isNull);
    expect(game.appliedMoves, 0);
    expect(game.submittedMoves, 0);
    expect(game.current.movetext, cancelled.movetext);
  });
}
