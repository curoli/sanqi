import 'package:flutter/services.dart';
import 'package:flutter_app/app_language.dart';
import 'package:flutter_app/app_skin.dart';
import 'package:flutter_app/choice_scroll_frame.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/settings_backup_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'game_screen_test.dart' show FakeService;
import 'skin_test.dart' show SkinStore, currentSkin;

Future<void> openBackup(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byKey(const Key('skin-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

void main() {
  test('settings backups round-trip every language and skin and reject invalid formats', () {
    for (final language in AppLanguage.values) {
      for (final skin in AppSkin.values) {
        final backup = SettingsBackup.decode(
          SettingsBackup(language, skin).encode(),
        );
        expect(backup.language, language);
        expect(backup.skin, skin);
      }
    }
    for (final bad in [
      'bad',
      '{}',
      '[]',
      '{"sanqiSettings":2,"language":"en","skin":"linen"}',
      '{"sanqiSettings":1,"language":"xx","skin":"linen"}',
      '{"sanqiSettings":1,"language":"en","skin":3}',
    ]) {
      expect(() => SettingsBackup.decode(bad), throwsFormatException);
    }
  });

  testWidgets('both choosers indicate and scroll choices above and below', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final scale in [1.0, 1.6]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      for (final language in AppLanguage.values) {
        for (final selector in ['language-selector', 'skin-selector']) {
          final store = SkinStore()
            ..code = language.code
            ..skin = 'blueprint';
          await tester.pumpWidget(
            SanqiApp(createService: () async => FakeService(), store: store),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(Key(selector)));
          await tester.pumpAndSettle();
          final controller = tester
              .widget<ChoiceScrollFrame>(find.byType(ChoiceScrollFrame))
              .controller;
          controller.jumpTo(0);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('choices-above')), findsNothing);
          expect(
            find.byKey(const Key('choices-below')).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('choices-below')));
          await tester.pumpAndSettle();
          expect(controller.offset, greaterThan(0));
          expect(
            find.byKey(const Key('choices-above')).hitTestable(),
            findsOneWidget,
          );
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('choices-below')), findsNothing);
          await tester.tap(find.byKey(const Key('choices-above')));
          await tester.pumpAndSettle();
          expect(controller.position.extentAfter, greaterThan(0));
          expect(
            tester.takeException(),
            isNull,
            reason: '$selector ${language.code} scale=$scale',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });

  testWidgets(
    'copied settings restore into a fresh store without changing the game',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final original = SkinStore()
        ..code = 'ur'
        ..skin = 'aurora';
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: original),
      );
      await tester.pumpAndSettle();
      final urdu = lookupAppLocalizations(const Locale('ur'));
      await openBackup(tester, urdu.settingsBackup);
      await tester.tap(find.text(urdu.copy));
      await tester.pumpAndSettle();
      expect(SettingsBackup.decode(copied!).language, AppLanguage.urdu);
      await tester.pumpWidget(const SizedBox());

      final fresh = SkinStore()..text = '1. a1-b3';
      final service = FakeService();
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: fresh),
      );
      await tester.pumpAndSettle();
      final calls = service.calls.toList();
      await openBackup(tester, 'Back up settings');
      await tester.enterText(
        find.byKey(const Key('settings-backup-input')),
        copied!,
      );
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(fresh.code, 'ur');
      expect(fresh.skin, 'aurora');
      expect(currentSkin(tester), AppSkin.aurora);
      expect(fresh.text, '1. a1-b3');
      expect(service.calls, calls);
      expect(find.byType(SettingsBackupDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: fresh),
      );
      await tester.pumpAndSettle();
      expect(currentSkin(tester), AppSkin.aurora);
      expect(find.text(urdu.newGame), findsOneWidget);
    },
  );

  testWidgets('invalid settings leave existing preferences untouched', (
    tester,
  ) async {
    final store = SkinStore();
    await tester.pumpWidget(
      SanqiApp(createService: () async => FakeService(), store: store),
    );
    await tester.pumpAndSettle();
    await openBackup(tester, 'Back up settings');
    await tester.enterText(
      find.byKey(const Key('settings-backup-input')),
      '{}',
    );
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not restore settings. Check the backup text and try again.',
      ),
      findsOneWidget,
    );
    expect(store.code, isNull);
    expect(store.savedSkins, isEmpty);
    expect(currentSkin(tester), AppSkin.linen);
  });
}
