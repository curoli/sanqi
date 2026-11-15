import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_app/game_service.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/src/rust/api/game.dart';
import 'package:flutter_app/src/rust/frb_generated.dart';

class DeviceTestStore extends GameStore {
  String? record;
  @override
  Future<String?> load() async => record;
  @override
  Future<void> save(String movetext) async => record = movetext;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled native library plays and undoes a move', (tester) async {
    await RustLib.init();
    final game = await createGame();
    final move = (await game.view()).legalMoves.first;
    final store = DeviceTestStore();
    await tester.pumpWidget(
      SanqiApp(createService: () async => RustGameService(game), store: store),
    );
    await tester.pumpAndSettle();
    final strings = AppLocalizations.of(
      tester.element(find.byType(GameScreen)),
    )!;
    for (final square in [move.from, move.to]) {
      await tester.ensureVisible(find.byKey(const Key('board')));
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
    expect(store.record, contains(move.notation));
    await tester.ensureVisible(find.text(strings.undo));
    await tester.tap(find.text(strings.undo));
    await tester.pumpAndSettle();
    expect(store.record, '');
    expect(find.text(strings.whiteToMove), findsOneWidget);
  });
}
