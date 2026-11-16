import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_app/app_language.dart';
import 'package:flutter_app/board.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'game_screen_test.dart'
    show FakeService, MemoryStore, PendingComputerService, snapshot, tapSquare;

class LanguageStore extends MemoryStore {
  String? code;
  bool failNextWrite = false;
  @override
  Future<String?> loadLanguage() async => code;
  @override
  Future<void> saveLanguage(String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('disk full');
    }
    code = value;
  }
}

class DelayedLanguageStore extends LanguageStore {
  final loaded = Completer<String?>();
  @override
  Future<String?> loadLanguage() => loaded.future;
}

Future<void> chooseLanguage(WidgetTester tester, AppLanguage language) async {
  await tester.tap(find.byKey(const Key('language-selector')));
  await tester.pumpAndSettle();
  for (final option in AppLanguage.values) {
    expect(find.text('${option.flag} ${option.name}'), findsOneWidget);
  }
  await tester.ensureVisible(find.text('${language.flag} ${language.name}'));
  await tester.tap(find.text('${language.flag} ${language.name}'));
  await tester.pumpAndSettle();
}

void main() {
  test('all fourteen rule languages have complete translation catalogs', () {
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
    expect(AppLanguage.values, hasLength(14));
    expect(
      AppLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .toSet(),
      AppLanguage.values.map((language) => language.code).toSet(),
    );
    for (final language in AppLanguage.values) {
      expect(
        File('../../docs/rules/sanqi-${language.code}.md').existsSync(),
        isTrue,
      );
      final catalog = jsonDecode(
        File('lib/l10n/app_${language.code}.arb').readAsStringSync(),
      ) as Map;
      expect(catalog.keys.where((key) => !key.startsWith('@')).toSet(), keys);
      expect(catalog['@@locale'], language.code);
    }
  });

  testWidgets(
    'flag selector translates immediately, preserves play and survives restart',
    (tester) async {
      final store = LanguageStore()..text = '1. a1-b3';
      final service = FakeService();
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: store),
      );
      await tester.pumpAndSettle();
      final initial = tester.widget<SanqiBoard>(find.byType(SanqiBoard)).view;
      final calls = service.calls.toList();
      for (final language in AppLanguage.values) {
        await chooseLanguage(tester, language);
        final l = lookupAppLocalizations(Locale(language.code));
        expect(find.text(l.newGame), findsOneWidget);
        expect(find.text(l.blackToMove), findsOneWidget);
        expect(find.byTooltip(l.language), findsOneWidget);
        expect(store.code, language.code);
        expect(store.text, '1. a1-b3');
        expect(service.calls, calls);
        expect(
          tester.widget<SanqiBoard>(find.byType(SanqiBoard)).view,
          same(initial),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      final restored = lookupAppLocalizations(
        Locale(AppLanguage.values.last.code),
      );
      expect(find.text(restored.newGame), findsOneWidget);
      expect(find.text(restored.blackToMove), findsOneWidget);
    },
  );

  testWidgets(
    'all languages fit small portrait and landscape and keep board mapping',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        await tester.binding.setSurfaceSize(size);
        for (final language in AppLanguage.values) {
          final store = LanguageStore()..code = language.code;
          final service = FakeService();
          final l = lookupAppLocalizations(Locale(language.code));
          await tester.pumpWidget(
            SanqiApp(createService: () async => service, store: store),
          );
          await tester.pumpAndSettle();
          final board = find.byType(SanqiBoard);
          expect(
            AppLocalizations.of(tester.element(board))!.localeName,
            language.code,
          );
          expect(
            Directionality.of(tester.element(board)),
            language.isRtl ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(find.text(l.whiteToMove), findsOneWidget);
          expect(find.text(l.newGame), findsOneWidget);
          expect(find.byType(SingleChildScrollView), findsNothing);
          if (size.width > size.height) {
            expect(
              tester.getSize(board).height,
              closeTo(size.height - 16, .01),
            );
          }
          await tapSquare(tester, 0);
          expect(service.calls.last, 'tap:0');
          await tester.tap(find.text(l.exampleMove));
          await tester.pumpAndSettle();
          expect(service.calls.last, 'inspect:a1-b3');
          await tapSquare(tester, 17);
          expect(service.calls.last, 'tap:17');
          expect(store.text, '1. a1-b3');
          expect(find.text(l.blackToMove), findsOneWidget);
          expect(
            tester
                .widget<Text>(find.byKey(const Key('recent-moves')))
                .textDirection,
            TextDirection.ltr,
          );
          await tester.tap(find.text(l.saveRestore));
          await tester.pumpAndSettle();
          expect(find.text(l.saveTitle), findsOneWidget);
          final input = tester.widget<TextField>(
            find.byKey(const Key('movetext-input')),
          );
          expect(input.controller!.text, '1. a1-b3');
          expect(input.textDirection, TextDirection.ltr);
          await tester.tap(find.text(l.cancel));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${language.code} at $size',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );

  testWidgets(
    'changing language during computer search does not cancel its reply',
    (tester) async {
      final service = PendingComputerService();
      final store = LanguageStore();
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: store),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('game-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer vs human').last);
      await tester.pumpAndSettle();
      expect(service.searches, 1);
      await chooseLanguage(tester, AppLanguage.german);
      expect(find.text('Denkt nach…'), findsOneWidget);
      expect(service.searches, 1);
      service.reply.complete(snapshot(played: true, humanColor: 'Black'));
      await tester.pumpAndSettle();
      expect(find.text('Schwarz am Zug'), findsOneWidget);
      expect(
        tester.widget<SanqiBoard>(find.byType(SanqiBoard)).enabled,
        isTrue,
      );
      expect(store.text, '1. a1-b3');
      expect(service.searches, 1);
    },
  );

  testWidgets(
    'device language is used with English fallback for unsupported languages',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      for (final code in [
        'tr',
        'fr',
        'hi',
        'bn',
        'pt',
        'ur',
        'ru',
        'ja',
        'it',
      ]) {
        tester.platformDispatcher.localesTestValue = [Locale(code)];
        await tester.pumpWidget(
          SanqiApp(
            createService: () async => FakeService(),
            store: LanguageStore()..code = 'unsupported',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            lookupAppLocalizations(
              Locale(AppLanguage.fromCode(code)?.code ?? 'en'),
            ).newGame,
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'computer failure and retry fit the narrow panel in every language',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(568, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final language in AppLanguage.values) {
        final service = PendingComputerService();
        final store = LanguageStore()
          ..code = language.code
          ..mode = 'Black';
        final l = lookupAppLocalizations(Locale(language.code));
        await tester.pumpWidget(
          SanqiApp(createService: () async => service, store: store),
        );
        await tester.pumpAndSettle();
        service.reply.complete(null);
        await tester.pumpAndSettle();
        expect(find.text(l.computerNoMove), findsOneWidget);
        await tester.tap(find.text(l.retryComputer));
        await tester.pumpAndSettle();
        expect(service.searches, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'late preference read cannot override an explicit language choice',
    (tester) async {
      final store = DelayedLanguageStore();
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      await chooseLanguage(tester, AppLanguage.spanish);
      store.loaded.complete('de');
      await tester.pumpAndSettle();
      expect(find.text('Nueva partida'), findsOneWidget);
      expect(store.code, 'es');
    },
  );

  testWidgets(
    'failed language save leaves translation active and later writes work',
    (tester) async {
      final store = LanguageStore()..failNextWrite = true;
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      await chooseLanguage(tester, AppLanguage.german);
      expect(find.text('Neues Spiel'), findsOneWidget);
      expect(
        find.textContaining(
          'Spracheinstellung konnte nicht gespeichert werden',
        ),
        findsOneWidget,
      );
      await chooseLanguage(tester, AppLanguage.english);
      expect(store.code, 'en');
      expect(
        find.textContaining('Could not save language preference'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
