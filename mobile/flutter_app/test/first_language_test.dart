import 'dart:async';

import 'package:flutter_app/app_language.dart';
import 'package:flutter_app/app_skin.dart';
import 'package:flutter_app/language_picker.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/settings_backup_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'game_screen_test.dart' show FakeService;
import 'localization_test.dart' show LanguageStore;
import 'skin_test.dart' show SkinStore, currentSkin;

class NewInstallStore extends LanguageStore {
  NewInstallStore() {
    code = null;
  }
}

class WaitingLanguageStore extends NewInstallStore {
  final write = Completer<void>();
  @override
  Future<void> saveLanguage(String value) async {
    await write.future;
    code = value;
  }
}

class ControlledRestoreStore extends SkinStore {
  ControlledRestoreStore() {
    code = null;
  }
  final writes = <(String, Completer<void>)>[];
  @override
  Future<void> saveLanguage(String value) async {
    final completion = Completer<void>();
    writes.add((value, completion));
    await completion.future;
    code = value;
  }
}

Future<void> select(WidgetTester tester, AppLanguage language) async {
  final option = find.text('${language.flag} ${language.name}');
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Exercise onboarding only when no system language is supported.
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = [
      const Locale('it'),
    ];
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearLocalesTestValue();
  });
  for (final failRestore in [false, true]) {
    testWidgets(
      'dismissed restore keeps onboarding locked until writes settle (failure=$failRestore)',
      (tester) async {
        final store = ControlledRestoreStore();
        var games = 0;
        await tester.pumpWidget(
          SanqiApp(
            createService: () async {
              games++;
              return FakeService();
            },
            store: store,
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(LanguagePicker)),
        )!;
        await tester.tap(find.byTooltip(l.settingsBackup));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('settings-backup-input')),
          const SettingsBackup(AppLanguage.german, AppSkin.aurora).encode(),
        );
        await tester.tap(find.text(l.restore));
        await tester.pumpAndSettle();
        expect(store.writes, hasLength(1));
        expect(store.writes.first.$1, 'de');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsBackupDialog), findsNothing);
        expect(
          tester.widget<LanguagePicker>(find.byType(LanguagePicker)).enabled,
          isFalse,
        );
        await select(tester, AppLanguage.english);
        expect(store.writes, hasLength(1));
        expect(games, 0);
        if (!failRestore) {
          store.writes.first.$2.complete();
          await tester.pumpAndSettle();
          expect(games, 1);
          expect(store.code, 'de');
          expect(find.text('Neues Spiel'), findsOneWidget);
        } else {
          store.writes.first.$2.completeError(StateError('restore disk error'));
          await tester.pumpAndSettle();
          expect(games, 0);
          expect(
            tester.widget<LanguagePicker>(find.byType(LanguagePicker)).enabled,
            isTrue,
          );
          expect(
            find.text(
              lookupAppLocalizations(const Locale('de')).settingsRestoreError,
            ),
            findsOneWidget,
          );
          await select(tester, AppLanguage.english);
          expect(store.writes, hasLength(2));
          expect(games, 0);
          store.writes[1].$2.completeError(StateError('English save error'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Could not save language preference'),
            findsOneWidget,
          );
          expect(games, 0);
          expect(store.code, isNull);
          await select(tester, AppLanguage.english);
          store.writes[2].$2.complete();
          await tester.pumpAndSettle();
          expect(games, 1);
          expect(store.code, 'en');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('system language matching follows preference order and regions', () {
    expect(AppLanguage.supportedSystemLanguage([]), isNull);
    expect(
      AppLanguage.supportedSystemLanguage([
        const Locale('it'),
        const Locale('fr', 'CA'),
        const Locale('de'),
      ]),
      AppLanguage.french,
    );
    expect(
      AppLanguage.supportedSystemLanguage([
        const Locale('xx'),
        const Locale('it'),
      ]),
      isNull,
    );
    for (final language in AppLanguage.values) {
      expect(
        AppLanguage.supportedSystemLanguage([Locale(language.code, 'XX')]),
        language,
      );
    }
  });

  testWidgets(
    'unsupported system language asks without auto-saving; choice persists',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [
        const Locale('it'),
        const Locale('xx'),
      ];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final store = NewInstallStore();
      var created = 0;
      Future<FakeService> create() async {
        created++;
        return FakeService();
      }

      await tester.pumpWidget(SanqiApp(createService: create, store: store));
      await tester.pumpAndSettle();
      final picker = tester.widget<LanguagePicker>(
        find.byKey(const Key('first-language-choice')),
      );
      expect(picker.selected, AppLanguage.english);
      expect(picker.firstLaunch, isTrue);
      expect(store.code, isNull);
      expect(created, 0);
      expect(find.byTooltip('Close'), findsNothing);
      await select(tester, AppLanguage.english);
      expect(store.code, 'en');
      expect(created, 1);
      expect(find.text('New Game'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      tester.platformDispatcher.localesTestValue = [const Locale('ja')];
      await tester.pumpWidget(SanqiApp(createService: create, store: store));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('first-language-choice')), findsNothing);
      expect(find.text('New Game'), findsOneWidget);
    },
  );

  testWidgets(
    'ordered regional system match opens game without saving an explicit choice',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [
        const Locale('it'),
        const Locale('fr', 'CA'),
        const Locale('de'),
      ];
      final store = NewInstallStore();
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePicker), findsNothing);
      expect(find.text('Nouvelle partie'), findsOneWidget);
      expect(store.code, isNull);
      await tester.pumpWidget(const SizedBox());
      tester.platformDispatcher.localesTestValue = [const Locale('ja')];
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(find.byType(GameScreen)))
            .languageCode,
        'ja',
      );
    },
  );

  testWidgets(
    'confirmation waits for persistence and allows retry after failure',
    (tester) async {
      final waiting = WaitingLanguageStore();
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: waiting),
      );
      await tester.pumpAndSettle();
      await select(tester, AppLanguage.english);
      expect(find.byType(GameScreen), findsNothing);
      expect(
        tester.widget<LanguagePicker>(find.byType(LanguagePicker)).enabled,
        isFalse,
      );
      waiting.write.complete();
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final failing = NewInstallStore()..failNextWrite = true;
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: failing),
      );
      await tester.pumpAndSettle();
      await select(tester, AppLanguage.english);
      expect(find.byType(GameScreen), findsNothing);
      expect(
        find.textContaining('Could not save language preference'),
        findsOneWidget,
      );
      await select(tester, AppLanguage.english);
      expect(find.byType(GameScreen), findsOneWidget);
      expect(failing.code, 'en');
    },
  );

  testWidgets('all supported system languages open the game with larger text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    for (final language in AppLanguage.values) {
      tester.platformDispatcher.localesTestValue = [Locale(language.code)];
      final store = NewInstallStore();
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('first-language-choice')), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(GameScreen))),
        language.isRtl ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(store.code, isNull);
      expect(find.byType(GameScreen), findsOneWidget);
      expect(tester.takeException(), isNull, reason: language.code);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'settings backup can restore both preferences before choosing a language',
    (tester) async {
      final store = SkinStore()..code = null;
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(LanguagePicker)),
      )!;
      await tester.tap(find.byTooltip(l.settingsBackup));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('settings-backup-input')),
        const SettingsBackup(AppLanguage.urdu, AppSkin.aurora).encode(),
      );
      await tester.tap(find.text(l.restore));
      await tester.pumpAndSettle();
      expect(store.code, 'ur');
      expect(currentSkin(tester), AppSkin.aurora);
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(SettingsBackupDialog), findsNothing);
      expect(find.byKey(const Key('first-language-choice')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
