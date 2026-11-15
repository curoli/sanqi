import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_app/app_language.dart';
import 'package:flutter_app/app_skin.dart';
import 'package:flutter_app/board.dart';
import 'package:flutter_app/game_background.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/skin_picker.dart';
import 'package:flutter_app/skin_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'game_screen_test.dart'
    show FakeService, PendingComputerService, snapshot, tapSquare;
import 'localization_test.dart' show LanguageStore;

class SkinStore extends LanguageStore {
  String? skin;
  bool failSkinWrite = false;
  final savedSkins = <String>[];
  @override
  Future<String?> loadSkin() async => skin;
  @override
  Future<void> saveSkin(String id) async {
    if (failSkinWrite) {
      failSkinWrite = false;
      throw StateError('disk full');
    }
    savedSkins.add(id);
    skin = id;
  }
}

class DelayedSkinStore extends SkinStore {
  final loaded = Completer<String?>();
  @override
  Future<String?> loadSkin() => loaded.future;
}

AppSkin currentSkin(WidgetTester tester) =>
    AppSkin.of(tester.element(find.byType(SanqiBoard)));

Future<void> chooseSkin(WidgetTester tester, AppSkin skin) async {
  final current = currentSkin(tester);
  await tester.tap(find.byKey(const Key('skin-selector')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(Key('skin-${skin.name}')),
    skin.index < current.index ? -160 : 160,
    scrollable: find.descendant(
      of: find.byKey(const Key('skin-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(find.byKey(Key('skin-${skin.name}')));
  await tester.pumpAndSettle();
}

double contrast(Color a, Color b) {
  final first = a.computeLuminance(), second = b.computeLuminance();
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

void main() {
  testWidgets('font licenses can be opened offline without changing the skin', (
    tester,
  ) async {
    registerSkinFontLicenses();
    await tester.pumpWidget(
      SanqiApp(createService: () async => FakeService(), store: SkinStore()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skin-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Font licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SkinPicker), findsOneWidget);
    expect(currentSkin(tester), AppSkin.linen);
  });

  test(
    'fourteen distinct skins have readable text, borders and offline fonts',
    () {
      expect(AppSkin.values, hasLength(14));
      expect(
        AppSkin.values.where((skin) => skin.brightness == Brightness.light),
        hasLength(7),
      );
      expect(
        AppSkin.values.map((skin) => skin.background).toSet(),
        hasLength(14),
      );
      expect(
        AppSkin.values.map((skin) => skin.fontFamily).toSet(),
        hasLength(4),
      );
      for (final skin in AppSkin.values) {
        for (final surface in [skin.surface, skin.background, skin.button]) {
          expect(
            contrast(skin.text, surface),
            greaterThanOrEqualTo(4.5),
            reason: skin.name,
          );
        }
        expect(
          contrast(skin.buttonText, skin.button),
          greaterThanOrEqualTo(4.5),
          reason: skin.name,
        );
        expect(
          contrast(skin.accent, skin.surface),
          greaterThanOrEqualTo(4.5),
          reason: skin.name,
        );
        expect(
          contrast(skin.border, skin.surface),
          greaterThanOrEqualTo(3),
          reason: skin.name,
        );
        for (final family in [skin.fontFamily, ...skin.fallbackFonts]) {
          expect(
            File('assets/fonts/$family.ttf').lengthSync(),
            greaterThan(10000),
          );
          expect(
            File('assets/fonts/licenses/$family.txt').readAsStringSync(),
            contains('SIL OPEN FONT LICENSE'),
          );
        }
        for (final language in AppLanguage.values) {
          final label = skin.label(
            lookupAppLocalizations(Locale(language.code)),
          );
          expect(label.trim(), isNotEmpty);
          expect(label.split(' ').length, lessThanOrEqualTo(2));
        }
      }
    },
  );

  testWidgets(
    'every skin can be chosen without changing the board, record or selection',
    (tester) async {
      final store = SkinStore();
      final service = FakeService()
        ..current = snapshot(selected: 0, preview: true);
      await tester.pumpWidget(
        SanqiApp(createService: () async => service, store: store),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<SanqiBoard>(find.byType(SanqiBoard)).view;
      for (final skin in AppSkin.values) {
        await chooseSkin(tester, skin);
        expect(currentSkin(tester), skin);
        expect(store.skin, skin.name);
        expect(service.calls, isEmpty);
        expect(
          tester.widget<SanqiBoard>(find.byType(SanqiBoard)).view,
          same(view),
        );
        final theme = Theme.of(tester.element(find.byType(SanqiBoard)));
        expect(theme.scaffoldBackgroundColor, skin.background);
        expect(theme.textTheme.bodyMedium!.fontFamily, skin.fontFamily);
        expect(
          theme.outlinedButtonTheme.style!.backgroundColor!.resolve({}),
          skin.button,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter is GameBackground &&
                (widget.painter! as GameBackground).skin == skin,
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const Key('skin-selector')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('skin-aurora')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(store.savedSkins, hasLength(14));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      expect(currentSkin(tester), AppSkin.aurora);
    },
  );

  testWidgets('all skins fit both orientations and preserve tap mapping', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      await tester.binding.setSurfaceSize(size);
      for (final skin in AppSkin.values) {
        final store = SkinStore()..skin = skin.name;
        final service = FakeService();
        await tester.pumpWidget(
          SanqiApp(createService: () async => service, store: store),
        );
        await tester.pumpAndSettle();
        expect(currentSkin(tester), skin);
        await tapSquare(tester, 0);
        expect(service.calls.last, 'tap:0');
        await tapSquare(tester, 17);
        expect(store.text, '1. a1-b3');
        expect(tester.takeException(), isNull, reason: '${skin.name} at $size');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('localized picker and dialogs fit RTL and enlarged text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    await tester.binding.setSurfaceSize(const Size(568, 320));
    for (final language in AppLanguage.values) {
      final l = lookupAppLocalizations(Locale(language.code));
      final store = SkinStore()
        ..skin = 'blueprint'
        ..code = language.code;
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skin-selector')));
      await tester.pumpAndSettle();
      expect(find.byType(SkinPicker), findsOneWidget);
      expect(find.text(l.chooseSkin), findsOneWidget);
      expect(
        find.byKey(const Key('skin-blueprint')).hitTestable(),
        findsOneWidget,
        reason:
            '${language.code}: list=${tester.getRect(find.byKey(const Key('skin-list')))} card=${tester.getRect(find.byKey(const Key('skin-blueprint')))}',
      );
      await tester.tap(find.byTooltip(l.close));
      await tester.pumpAndSettle();
      expect(currentSkin(tester), AppSkin.blueprint);
      expect(tester.takeException(), isNull, reason: language.code);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('changing skin during search preserves the computer reply', (
    tester,
  ) async {
    final service = PendingComputerService();
    final store = SkinStore()..mode = 'Black';
    await tester.pumpWidget(
      SanqiApp(createService: () async => service, store: store),
    );
    await tester.pumpAndSettle();
    await chooseSkin(tester, AppSkin.arcade);
    expect(service.searches, 1);
    service.reply.complete(snapshot(played: true, humanColor: 'Black'));
    await tester.pumpAndSettle();
    expect(currentSkin(tester), AppSkin.arcade);
    expect(find.text('Black to move'), findsOneWidget);
    expect(store.text, '1. a1-b3');
    expect(service.searches, 1);
  });

  testWidgets(
    'late preference cannot replace a choice and unknown IDs fall back to Linen',
    (tester) async {
      final store = DelayedSkinStore();
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      await chooseSkin(tester, AppSkin.mint);
      store.loaded.complete('graphite');
      await tester.pumpAndSettle();
      expect(currentSkin(tester), AppSkin.mint);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        SanqiApp(
          createService: () async => FakeService(),
          store: SkinStore()..skin = 'removed-skin',
        ),
      );
      await tester.pumpAndSettle();
      expect(currentSkin(tester), AppSkin.linen);
    },
  );

  testWidgets(
    'failed persistence keeps the selected skin and later saves recover',
    (tester) async {
      final store = SkinStore()..failSkinWrite = true;
      await tester.pumpWidget(
        SanqiApp(createService: () async => FakeService(), store: store),
      );
      await tester.pumpAndSettle();
      await chooseSkin(tester, AppSkin.sakura);
      expect(currentSkin(tester), AppSkin.sakura);
      expect(
        find.textContaining('Could not save skin preference'),
        findsOneWidget,
      );
      await chooseSkin(tester, AppSkin.graphite);
      expect(currentSkin(tester), AppSkin.graphite);
      expect(store.skin, 'graphite');
      expect(
        find.textContaining('Could not save skin preference'),
        findsNothing,
      );
    },
  );
}
