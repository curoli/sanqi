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
  bool computerBoth = false,
  List<MobileMove>? moves,
  MobileMove? inspected,
  String? record,
}) => GameView(
  revision: BigInt.zero,
  computerBoth: computerBoth,
  computerTurn: computerTurn,
  humanColor: humanColor,
  svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="#f5e6c8"/></svg>',
  sideToMove: played ? 'Black' : 'White',
  selected: selected,
  legalMoves: moves ?? (played ? [] : [move]),
  inspectedMove: inspected ?? (preview ? move : null),
  supports: preview
      ? [const SupportView(first: 1, second: 8, fileTwice: 1, rankTwice: 1)]
      : [],
  movetext: record ?? (played ? '1. a1-b3' : ''),
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
  String? mode;
  @override
  Future<String?> loadHumanColor() async => mode;
  @override
  Future<void> saveHumanColor(String? color) async => mode = color;
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

class CyclingService extends FakeService {
  static const moves = [
    move,
    MobileMove(from: 0, to: 18, notation: 'a1-c3'),
    MobileMove(from: 0, to: 19, notation: 'a1-d3'),
  ];
  @override
  Future<GameView> tap(int square) async =>
      current = snapshot(selected: 0, moves: moves);
  @override
  Future<GameView> inspect(String notation) async {
    calls.add('inspect:$notation');
    return current = snapshot(
      selected: 0,
      moves: moves,
      preview: true,
      inspected: moves.firstWhere((move) => move.notation == notation),
    );
  }
}

class WatchingService extends FakeService {
  final replies = <Completer<GameView?>>[];
  @override
  Future<GameView> undo() async {
    calls.add('undo');
    return current = snapshot(computerBoth: true, computerTurn: true);
  }

  @override
  Future<GameView> startGame(String? mode) async => current = snapshot(
    computerBoth: mode == 'Computer',
    computerTurn: mode == 'Computer',
  );
  @override
  Future<GameView?> computerTurn() {
    final reply = Completer<GameView?>();
    replies.add(reply);
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
    'Example move cycles every destination and wraps without playing',
    (tester) async {
      final service = CyclingService();
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: MemoryStore()),
      );
      await tester.pumpAndSettle();
      await tapSquare(tester, 0);
      for (final move in [
        ...CyclingService.moves,
        CyclingService.moves.first,
      ]) {
        await tester.tap(find.text('Example move'));
        await tester.pumpAndSettle();
        final view = tester.widget<SanqiBoard>(find.byType(SanqiBoard)).view;
        expect(view.inspectedMove, move);
        expect(view.supports, isNotEmpty);
        expect(view.movetext, isEmpty);
      }
      expect(service.calls, [
        'inspect:a1-b3',
        'inspect:a1-c3',
        'inspect:a1-d3',
        'inspect:a1-b3',
      ]);
    },
  );

  testWidgets(
    'computer spectators advance both sides and can pause stale search',
    (tester) async {
      final service = WatchingService();
      final store = MemoryStore();
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: store),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer vs Computer').last);
      await tester.pumpAndSettle();
      expect(service.replies, hasLength(1));
      expect(store.mode, 'Computer');
      service.current = snapshot(
        played: true,
        computerBoth: true,
        computerTurn: true,
      );
      service.replies.first.complete(service.current);
      await tester.pumpAndSettle();
      expect(service.replies, hasLength(2));
      expect(store.text, '1. a1-b3');
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      service.replies[1].complete(
        snapshot(computerBoth: true, computerTurn: true),
      );
      await tester.pumpAndSettle();
      expect(service.replies, hasLength(2));
      expect(store.text, '1. a1-b3');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(service.calls, contains('undo'));
      expect(service.replies, hasLength(2));
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(service.replies, hasLength(3));
      await tester.pumpWidget(const SizedBox());
    },
  );

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
      await tester.tap(find.text('Computer vs human').last);
      await tester.pumpAndSettle();
      expect(find.text('Thinking…'), findsOneWidget);
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
      expect(find.text('Thinking…'), findsNothing);
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
      await tester.tap(find.text('Computer vs human').last);
      await tester.pumpAndSettle();
      expect(find.text('Thinking…'), findsOneWidget);
      expect(service.searches, 1);
      expect(
        tester.widget<SanqiBoard>(find.byType(SanqiBoard)).enabled,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('game-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Human vs Human').last);
      await tester.pumpAndSettle();
      service.reply.complete(snapshot(played: true, humanColor: 'Black'));
      await tester.pumpAndSettle();
      expect(find.text('White to move'), findsOneWidget);
      expect(find.text('Thinking…'), findsNothing);
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
      await tester.tap(find.text('Example move'));
      await tester.pumpAndSettle();
      expect(find.textContaining('a1-b3 ·'), findsOneWidget);
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
    for (final size in [
      const Size(900, 400),
      const Size(320, 568),
      const Size(430, 932),
      const Size(568, 320),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        SanqiApp(
          createService: () async => FakeService()
            ..current = snapshot(record: '${'1. a1-b3 h8-d6 ' * 80}81. h1-d3'),
          store: MemoryStore(),
        ),
      );
      await tester.pumpAndSettle();
      final board = tester.getSize(find.byKey(const Key('board')));
      expect(board.width, closeTo(board.height, .01));
      if (size.width > size.height) {
        expect(board.height, greaterThan(size.height - 80));
      } else {
        expect(board.width, greaterThan(size.width - 70));
      }
      final rect = tester.getRect(find.byKey(const Key('board')));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      expect(find.byType(SingleChildScrollView), findsNothing);
      final recent = tester
          .widget<Text>(find.byKey(const Key('recent-moves')))
          .data!;
      expect(recent, endsWith('81. h1-d3'));
      expect(recent.length, lessThan(120));
      await tapSquare(tester, 0);
      expect(
        tester.widget<SanqiBoard>(find.byType(SanqiBoard)).view.selected,
        0,
      );
      await tester.tap(find.text('Example move'));
      await tester.pumpAndSettle();
      await tapSquare(tester, 17);
      expect(find.text('Black to move'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    await tester.binding.setSurfaceSize(null);
  });
}
