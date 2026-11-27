import 'package:flutter/services.dart';
import 'package:flutter_app/app_language.dart';
import 'package:flutter_app/app_skin.dart';
import 'package:flutter_app/board.dart';
import 'package:flutter_app/game_service.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/src/rust/api/game.dart';
import 'package:flutter_app/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

// Play Console uses regional tags for some of Sanqi's language-only locales.
String _playTag(AppLanguage language) => switch (language) {
  AppLanguage.english => 'en-US',
  AppLanguage.german => 'de-DE',
  AppLanguage.indonesian => 'id',
  AppLanguage.arabic => 'ar',
  AppLanguage.chinese => 'zh-CN',
  AppLanguage.spanish => 'es-ES',
  AppLanguage.turkish => 'tr-TR',
  AppLanguage.hindi => 'hi-IN',
  AppLanguage.french => 'fr-FR',
  AppLanguage.bengali => 'bn-BD',
  AppLanguage.portuguese => 'pt-PT',
  AppLanguage.urdu => 'ur',
  AppLanguage.russian => 'ru-RU',
  AppLanguage.japanese => 'ja-JP',
};

enum _Scene {
  opening('01-opening', AppSkin.linen),
  example(
    '02-example-move',
    AppSkin.lagoon,
    record:
        '1. g1-b3 h8-b6 2. c1-d4 c8-f6 3. d1-b6 d8-b6 '
        '4. e1-e3 e8-e5 5. d2-e5 g8-e5',
  ),
  computer(
    '03-computer-move',
    AppSkin.sakura,
    record:
        '1. c1-a3 f8-e6 2. e2-c3 h8-e5 3. h2-e2 g8-c3 '
        '4. c2-c3 g7-b5 5. b1-b5 h7-b5',
    humanColor: 'White',
  ),
  finished(
    '04-game-over',
    AppSkin.midnight,
    record:
        '1. a1-d3 h8-g6 2. h1-e3 e7-h8 3. e1-a1 d8-e7 '
        '4. e3-e1 c7-e6 5. d1-c3 h7-b6 6. a1-g4 b8-g4 '
        '7. c1-g4 e8-g4 8. b1-g4 g8-e5 9. f1-e6 g7-e6 '
        '10. e1-e5 f8-e5 11. e2-e5 b7-e5 12. f2-e5 h8-e5 '
        '13. g1-c4 c8-g4 14. a2-e5 a8-e5 15. b2-e5 g6-e5 '
        '16. d2-g4 d7-c4 17. g2-c4 e6-c7 18. h2-b6 e7-a5 '
        '19. c3-f7 a7-e3 20. d3-a5 e5-c5 21. b6-h2 c7-e1 '
        '22. a5-e1',
  );

  const _Scene(this.filename, this.skin, {this.record, this.humanColor});

  final String filename;
  final AppSkin skin;
  final String? record;
  final String? humanColor;
}

class _ScreenshotStore extends GameStore {
  _ScreenshotStore(this.language, this.scene);

  final AppLanguage language;
  final _Scene scene;

  @override
  Future<String?> loadLanguage() async => language.code;

  @override
  Future<String?> loadSkin() async => scene.skin.name;

  @override
  Future<String?> loadHumanColor() async => scene.humanColor;

  @override
  Future<String?> load() async => scene.record;

  @override
  Future<void> save(String movetext) async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture the Play Store screenshot set',
    (tester) async {
      await RustLib.init();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await binding.convertFlutterSurfaceToImage();
      try {
        for (final language in AppLanguage.values) {
          for (final scene in _Scene.values) {
            final game = await createGame();
            try {
              await tester.pumpWidget(
                SanqiApp(
                  createService: () async => RustGameService(game),
                  store: _ScreenshotStore(language, scene),
                ),
              );
              final board = find.byType(SanqiBoard);
              // Rust bridge calls complete asynchronously on a physical device.
              for (var attempt = 0; attempt < 120; attempt++) {
                await tester.pump(const Duration(milliseconds: 50));
                if (board.evaluate().isNotEmpty &&
                    find.byType(LinearProgressIndicator).evaluate().isEmpty) {
                  break;
                }
              }
              await tester.pumpAndSettle();
              final context = tester.element(board);
              final strings = AppLocalizations.of(context)!;
              expect(
                Localizations.localeOf(context).languageCode,
                language.code,
              );
              expect(AppSkin.of(context), scene.skin);
              final view = tester.widget<SanqiBoard>(board).view;
              expect(view.movetext, scene.record ?? '');
              expect(view.computerTurn, isFalse);
              if (scene == _Scene.example) {
                await tester.tap(find.text(strings.exampleMove));
                for (var attempt = 0; attempt < 120; attempt++) {
                  await tester.pump(const Duration(milliseconds: 50));
                  if (tester.widget<SanqiBoard>(board).view.inspectedMove !=
                      null) {
                    break;
                  }
                }
                final preview = tester.widget<SanqiBoard>(board).view;
                expect(preview.inspectedMove, isNotNull);
                expect(preview.supports, isNotEmpty);
              }
              if (scene == _Scene.computer) {
                expect(
                  find.byKey(const Key('computer-move-from')),
                  findsOneWidget,
                );
                expect(
                  find.byKey(const Key('computer-move-to')),
                  findsOneWidget,
                );
              }
              if (scene == _Scene.finished) expect(view.winner, 'White');

              await tester.pumpAndSettle();
              await binding.takeScreenshot(
                '${_playTag(language)}/${scene.filename}',
              );
            } finally {
              await tester.pumpWidget(const SizedBox());
              game.dispose();
            }
          }
        }
      } finally {
        await SystemChrome.setPreferredOrientations([]);
        RustLib.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
