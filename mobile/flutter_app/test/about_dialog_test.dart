import 'package:flutter_app/about_dialog.dart';
import 'package:flutter_app/app_language.dart';
import 'package:flutter_app/board.dart';
import 'package:flutter_app/build_info.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'game_screen_test.dart'
    show FakeService, MemoryStore, PendingComputerService, snapshot;
import 'localization_test.dart' show LanguageStore;

const recordedBuild = AppBuildInfo(
  date: '2026-11-15T16:30:00Z',
  commit: '0123456789abcdef0123456789abcdef01234567',
);

Future<void> openTestDialog(
  WidgetTester tester, {
  AppBuildInfo buildInfo = recordedBuild,
  required Future<bool> Function(Uri) openLink,
}) async {
  showDialog<void>(
    context: tester.element(find.byType(GameScreen)),
    builder: (_) => SanqiAboutDialog(buildInfo: buildInfo, openLink: openLink),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'About opens in both orientations and all languages without changing the game',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        await tester.binding.setSurfaceSize(size);
        for (final language in AppLanguage.values) {
          final store = LanguageStore()..code = language.code;
          final service = FakeService()
            ..current = snapshot(selected: 0, preview: true);
          final l = lookupAppLocalizations(Locale(language.code));
          await tester.pumpWidget(
            SanqiApp(createService: () async => service, store: store),
          );
          await tester.pumpAndSettle();
          final view = tester.widget<SanqiBoard>(find.byType(SanqiBoard)).view;
          await tester.tap(find.text(l.about));
          await tester.pumpAndSettle();
          expect(find.byType(SanqiAboutDialog), findsOneWidget);
          expect(find.text(l.aboutTitle), findsOneWidget);
          expect(find.text(l.pronunciation), findsOneWidget);
          expect(find.text(l.slogan), findsOneWidget);
          expect(find.text(l.author), findsOneWidget);
          expect(l.author, contains('Oliver A Rübenacker'));
          if (language == AppLanguage.english) {
            expect(l.pronunciation, contains('sun chee'));
          }
          expect(
            find.byKey(const Key('about-rules')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('about-repository')).hitTestable(),
            findsOneWidget,
          );
          expect(find.text(l.rulesLink), findsOneWidget);
          expect(find.text(l.repositoryLink), findsOneWidget);
          await tester.tap(find.byTooltip(l.close));
          await tester.pumpAndSettle();
          expect(service.calls, isEmpty);
          expect(
            tester.widget<SanqiBoard>(find.byType(SanqiBoard)).view,
            same(view),
          );
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
    'overflow is indicated, the cue scrolls, and links stay visible with large text',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final scale in [1.0, 1.6]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final language in AppLanguage.values) {
          await tester.binding.setSurfaceSize(const Size(800, 1200));
          final l = lookupAppLocalizations(Locale(language.code));
          await tester.pumpWidget(
            SanqiApp(
              createService: () async => FakeService(),
              store: LanguageStore()..code = language.code,
            ),
          );
          await tester.pumpAndSettle();
          await openTestDialog(tester, openLink: (_) async => true);
          final content = find.byKey(const Key('about-scroll-content'));
          final controller = tester
              .widget<SingleChildScrollView>(content)
              .controller!;
          expect(controller.position.maxScrollExtent, 0);
          expect(find.byKey(const Key('about-more-below')), findsNothing);

          await tester.binding.setSurfaceSize(const Size(568, 320));
          await tester.pumpAndSettle();
          expect(controller.position.maxScrollExtent, greaterThan(0));
          expect(find.text(l.moreBelow).hitTestable(), findsOneWidget);
          final scrollbar = tester.widget<Scrollbar>(
            find.byKey(const Key('about-scrollbar')),
          );
          expect(scrollbar.thumbVisibility, isTrue);
          expect(scrollbar.trackVisibility, isTrue);
          for (final key in ['about-rules', 'about-repository']) {
            expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
          }
          final before = controller.offset;
          await tester.tap(find.byKey(const Key('about-more-below')));
          await tester.pumpAndSettle();
          expect(controller.offset, greaterThan(before));
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('about-more-below')), findsNothing);
          expect(
            find.byKey(const Key('build-commit')).hitTestable(),
            findsOneWidget,
          );
          controller.jumpTo(0);
          await tester.pumpAndSettle();
          expect(find.text(l.moreBelow).hitTestable(), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '${language.code} at scale $scale',
          );
          await tester.tap(find.byTooltip(l.close));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );

  testWidgets(
    'About shows recorded metadata and opens the selected language rules and repository',
    (tester) async {
      for (final language in AppLanguage.values) {
        final opened = <Uri>[];
        final l = lookupAppLocalizations(Locale(language.code));
        await tester.pumpWidget(
          SanqiApp(
            createService: () async => FakeService(),
            store: LanguageStore()..code = language.code,
          ),
        );
        await tester.pumpAndSettle();
        await openTestDialog(
          tester,
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        );
        expect(find.text('Debug build'), findsOneWidget);
        final date = tester.widget<SelectableText>(
          find.byKey(const Key('build-date')),
        );
        final commit = tester.widget<SelectableText>(
          find.byKey(const Key('build-commit')),
        );
        expect(date.data, recordedBuild.date);
        expect(commit.data, recordedBuild.commit);
        expect(date.textDirection, TextDirection.ltr);
        expect(commit.textDirection, TextDirection.ltr);
        for (final key in ['about-rules', 'about-repository']) {
          await tester.ensureVisible(find.byKey(Key(key)));
          await tester.tap(find.byKey(Key(key)));
          await tester.pumpAndSettle();
        }
        expect(opened.map((uri) => uri.toString()), [
          'https://github.com/curoli/sanqi/blob/main/docs/rules/sanqi-${language.code}.md',
          'https://github.com/curoli/sanqi',
        ]);
        await tester.tap(find.byTooltip(l.close));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'missing build metadata is explicit and browser failures leave a copyable URL',
    (tester) async {
      for (final throws in [false, true]) {
        await tester.pumpWidget(
          SanqiApp(
            createService: () async => FakeService(),
            store: MemoryStore(),
          ),
        );
        await tester.pumpAndSettle();
        await openTestDialog(
          tester,
          buildInfo: const AppBuildInfo(date: '', commit: ''),
          openLink: (_) async {
            if (throws) throw StateError('No browser');
            return false;
          },
        );
        expect(
          tester
              .widget<SelectableText>(find.byKey(const Key('build-date')))
              .data,
          'Not recorded for this build',
        );
        expect(
          tester
              .widget<SelectableText>(find.byKey(const Key('build-commit')))
              .data,
          'Not recorded for this build',
        );
        await tester.ensureVisible(find.byKey(const Key('about-rules')));
        await tester.tap(find.byKey(const Key('about-rules')));
        await tester.pumpAndSettle();
        expect(
          find.text('Could not open the link. You can copy the address below.'),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == 'https://github.com/curoli/sanqi/blob/main/docs/rules/sanqi-en.md',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('computer reply continues while About is open', (tester) async {
    final service = PendingComputerService();
    final store = LanguageStore()..mode = 'Black';
    await tester.pumpWidget(
      SanqiApp(createService: () async => service, store: store),
    );
    await tester.pumpAndSettle();
    expect(service.searches, 1);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    service.reply.complete(snapshot(played: true, humanColor: 'Black'));
    await tester.pumpAndSettle();
    expect(find.byType(SanqiAboutDialog), findsOneWidget);
    expect(store.text, '1. a1-b3');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Black to move'), findsOneWidget);
    expect(tester.widget<SanqiBoard>(find.byType(SanqiBoard)).enabled, isTrue);
    expect(service.searches, 1);
  });
}
