import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/board.dart';
import 'package:flutter_app/game_service.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/src/rust/api/game.dart';

const move = MobileMove(from: 0, to: 17, notation: 'a1-b3');

GameView snapshot({
  int? selected,
  bool played = false,
  bool preview = false,
  String? humanColor,
  bool computerTurn = false,
}) => GameView(
  revision: BigInt.zero,
  computerTurn: computerTurn,
  humanColor: humanColor,
  svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="#f5e6c8"/></svg>',
  sideToMove: played ? 'Black' : 'White',
  selected: selected,
  legalMoves: played ? [] : [move],
  inspectedMove: preview ? move : null,
  supports: preview
      ? [const SupportView(first: 1, second: 8, fileTwice: 1, rankTwice: 1)]
      : [],
  movetext: played ? '1. a1-b3' : '',
  canUndo: played,
);

class FakeService extends GameService {
  GameView current = snapshot();
  final calls = <String>[];

  @override
  Future<GameView> view() async => current;
  @override
  Future<GameView> tap(int square) async {
    calls.add('tap:$square');
    return current = square == 0
        ? snapshot(selected: 0)
        : snapshot(played: true);
  }

  @override
  Future<GameView> inspect(String move) async {
    calls.add('inspect:$move');
    return current = snapshot(selected: 0, preview: true);
  }

  @override
  Future<GameView> newGame() async {
    calls.add('new');
    return current = snapshot();
  }

  @override
  Future<GameView> undo() async {
    calls.add('undo');
    return current = snapshot();
  }

  @override
  Future<GameView> restore(String movetext) async {
    calls.add('restore:$movetext');
    if (movetext == 'invalid') throw StateError('invalid movetext');
    return current = snapshot(played: movetext.isNotEmpty);
  }
}

class MemoryStore extends GameStore {
  String? text;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String movetext) async => text = movetext;
}

class PendingComputerService extends FakeService {
  final reply = Completer<GameView?>();
  int searches = 0;
  @override
  Future<GameView> startGame(String? humanColor) async => current = snapshot(
    humanColor: humanColor,
    computerTurn: humanColor == 'Black',
  );
  @override
  Future<GameView?> computerTurn() {
    searches++;
    return reply.future;
  }
}

Future<void> tapSquare(WidgetTester tester, int square) async {
  final board = tester.getRect(find.byKey(const Key('board')));
  await tester.tapAt(
    board.topLeft +
        Offset(
          (square % 8 + .5) * board.width / 8,
          (7 - square ~/ 8 + .5) * board.height / 8,
        ),
  );
  await tester.pumpAndSettle();
}

class FailedImportDuringSearchService extends PendingComputerService {
  @override
  Future<GameView?> computerTurn() {
    if (!current.computerTurn) {
      searches++;
      return Future.value(null);
    }
    return super.computerTurn();
  }

  @override
  Future<GameView> restore(String movetext) async {
    current = snapshot(played: true, humanColor: 'Black');
    reply.complete(current);
    throw StateError('invalid movetext');
  }
}

void main() {
  testWidgets(
    'failed import reconciles a committed reply whose UI epoch was invalidated',
    (tester) async {
      final service = FailedImportDuringSearchService();
      final store = MemoryStore();
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: store),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer opponent — play Black').last);
      await tester.pumpAndSettle();
      expect(find.text('Computer is thinking…'), findsOneWidget);
      await tester.tap(find.text('Save / restore'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('movetext-input')),
        'invalid',
      );
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('invalid movetext'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Black to move'), findsOneWidget);
      expect(
        tester.widget<SanqiBoard>(find.byType(SanqiBoard)).enabled,
        isTrue,
      );
      expect(find.text('Retry computer move'), findsNothing);
      expect(find.text('Computer is thinking…'), findsNothing);
      expect(store.text, '1. a1-b3');
      expect(service.searches, 1);
    },
  );
  testWidgets(
    'computer opening shows thinking and stale replies cannot replace a new local game',
    (tester) async {
      final service = PendingComputerService();
      final store = MemoryStore();
      await tester.binding.setSurfaceSize(const Size(430, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: store),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer opponent — play Black').last);
      await tester.pumpAndSettle();
      expect(find.text('Computer is thinking…'), findsOneWidget);
      expect(service.searches, 1);
      expect(
        tester.widget<SanqiBoard>(find.byType(SanqiBoard)).enabled,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('game-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local two-player game').last);
      await tester.pumpAndSettle();
      service.reply.complete(snapshot(played: true, humanColor: 'Black'));
      await tester.pumpAndSettle();
      expect(find.text('White to move'), findsOneWidget);
      expect(find.text('Computer is thinking…'), findsNothing);
      expect(store.text, '');
    },
  );
  test('coordinate mapping matches the SVG orientation at every square', () {
    for (final side in [240.0, 560.0]) {
      for (var square = 0; square < 64; square++) {
        expect(
          squareAt(
            Offset(
              (square % 8 + .5) * side / 8,
              (7 - square ~/ 8 + .5) * side / 8,
            ),
            side,
          ),
          square,
        );
      }
      expect(squareAt(Offset.zero, side), 56);
      expect(squareAt(Offset(side - .01, side - .01), side), 7);
      expect(squareAt(Offset(side, 0), side), isNull);
      expect(squareAt(const Offset(-1, 0), side), isNull);
      expect(squareAt(Offset(0, side), side), isNull);
    }
  });

  testWidgets(
    'select, preview, move, undo and new game delegate to Rust service',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = FakeService();
      final store = MemoryStore();
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: store),
      );
      await tester.pumpAndSettle();
      expect(find.text('White to move'), findsOneWidget);
      await tapSquare(tester, 0);
      expect(service.calls, contains('tap:0'));
      await tester.ensureVisible(find.text('Preview a1-b3'));
      await tester.tap(find.text('Preview a1-b3'));
      await tester.pumpAndSettle();
      expect(find.text('Supports for a1-b3'), findsOneWidget);
      expect(service.calls, contains('inspect:a1-b3'));
      await tester.ensureVisible(find.byKey(const Key('board')));
      await tapSquare(tester, 17);
      expect(find.text('Black to move'), findsOneWidget);
      expect(store.text, '1. a1-b3');
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(store.text, '');
      await tester.tap(find.text('New Game'));
      await tester.pumpAndSettle();
      expect(service.calls, containsAll(['undo', 'new']));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved record restores and a bad import preserves the game', (
    tester,
  ) async {
    final service = FakeService();
    final store = MemoryStore()..text = '1. a1-b3';
    await tester.pumpWidget(
      SanqiApp(createService: () async => service, store: store),
    );
    await tester.pumpAndSettle();
    expect(service.calls, contains('restore:1. a1-b3'));
    await tester.ensureVisible(find.text('Save / restore'));
    await tester.tap(find.text('Save / restore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('movetext-input')), 'invalid');
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(store.text, '1. a1-b3');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Black to move'), findsOneWidget);
  });

  testWidgets('landscape and small portrait layouts stay within constraints', (
    tester,
  ) async {
    for (final size in [const Size(900, 400), const Size(320, 568)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        SanqiApp(
          createService: () async => FakeService(),
          store: MemoryStore(),
        ),
      );
      await tester.pumpAndSettle();
      final board = tester.getSize(find.byKey(const Key('board')));
      expect(board.width, closeTo(board.height, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    await tester.binding.setSurfaceSize(null);
  });
}
