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

Future<void> select(WidgetTester tester, AppLanguage language) async {
  final option = find.text('${language.flag} ${language.name}');
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  test('suggestion follows preferred system languages, matching regions and falling back to English', () {
    expect(AppLanguage.suggested([]), AppLanguage.english);
    expect(
      AppLanguage.suggested([
        const Locale('it'),
        const Locale('fr', 'CA'),
        const Locale('de'),
      ]),
      AppLanguage.french,
    );
    expect(
      AppLanguage.suggested([const Locale('xx'), const Locale('it')]),
      AppLanguage.english,
    );
    for (final language in AppLanguage.values) {
      expect(AppLanguage.suggested([Locale(language.code, 'XX')]), language);
    }
  });

  testWidgets(
    'first launch asks without auto-saving or starting a game; choice persists',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [
        const Locale('it'),
        const Locale('fr', 'CA'),
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
      expect(picker.selected, AppLanguage.french);
      expect(picker.firstLaunch, isTrue);
      expect(store.code, isNull);
      expect(created, 0);
      expect(find.byTooltip('Fermer'), findsNothing);
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

  testWidgets(
    'all suggested languages fit first-launch landscape with larger text',
    (tester) async {
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
        expect(find.byKey(const Key('first-language-choice')), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(LanguagePicker))),
          language.isRtl ? TextDirection.rtl : TextDirection.ltr,
        );
        await select(tester, language);
        expect(store.code, language.code);
        expect(find.byType(GameScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: language.code);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

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
