import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import 'about_dialog.dart';
import 'app_language.dart';
import 'app_skin.dart';
import 'board.dart';
import 'game_background.dart';
import 'game_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'language_picker.dart';
import 'settings_backup_dialog.dart';
import 'skin_fonts.dart';
import 'skin_picker.dart';
import 'src/rust/api/game.dart';
import 'src/rust/frb_generated.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerSkinFontLicenses();
  runApp(
    SanqiApp(
      createService: () async {
        await RustLib.init();
        return RustGameService(await createGame());
      },
      store: PreferenceGameStore(),
    ),
  );
}

class SanqiApp extends StatefulWidget {
  const SanqiApp({super.key, required this.createService, required this.store});

  final Future<GameService> Function() createService;
  final GameStore store;

  @override
  State<SanqiApp> createState() => _SanqiAppState();
}

class _SanqiAppState extends State<SanqiApp> {
  AppSkin _skin = AppSkin.linen;
  bool _skinChosen = false;
  Future<void> _skinWrites = Future.value();
  Locale? _locale;
  bool _languageChosen = false;
  Future<void> _languageWrites = Future.value();

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadSkin();
  }

  Future<void> _loadSkin() async {
    try {
      final skin = AppSkin.fromId(await widget.store.loadSkin());
      if (mounted && !_skinChosen && skin != null) setState(() => _skin = skin);
    } catch (error) {
      debugPrint('Could not load skin preference: $error');
    }
  }

  Future<void> _setSkin(AppSkin skin) {
    _skinChosen = true;
    setState(() => _skin = skin);
    final write = _skinWrites.then((_) => widget.store.saveSkin(skin.name));
    _skinWrites = write.catchError((Object _) {});
    return write;
  }

  Future<void> _loadLanguage() async {
    try {
      final language = AppLanguage.fromCode(await widget.store.loadLanguage());
      if (mounted && !_languageChosen && language != null) {
        setState(() => _locale = Locale(language.code));
      }
    } catch (error) {
      // A failed preference read leaves the device locale (or English fallback).
      debugPrint('Could not load language preference: $error');
    }
  }

  Future<void> _setLanguage(String code) {
    _languageChosen = true;
    setState(() => _locale = Locale(code));
    final write = _languageWrites.then((_) => widget.store.saveLanguage(code));
    // Serialize writes without letting a failed write block later choices.
    _languageWrites = write.catchError((Object _) {});
    return write;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sanqi',
    debugShowCheckedModeBanner: false,
    locale: _locale,
    // Use delegates matching our UI packages rather than the SDK's legacy types.
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: [
      for (final language in AppLanguage.values) Locale(language.code),
    ],
    theme: _skin.theme,
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (_skin.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(systemNavigationBarColor: _skin.background),
      child: child!,
    ),
    home: GameScreen(
      createService: widget.createService,
      store: widget.store,
      onLanguageChanged: _setLanguage,
      onSkinChanged: _setSkin,
    ),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.createService,
    required this.store,
    this.onLanguageChanged,
    this.onSkinChanged,
  });

  final Future<GameService> Function() createService;
  final GameStore store;
  final Future<void> Function(String code)? onLanguageChanged;
  final Future<void> Function(AppSkin skin)? onSkinChanged;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _recordController = TextEditingController();
  GameService? _service;
  GameView? _view;
  String Function(AppLocalizations)? _error;
  String Function(AppLocalizations)? _languageError;
  String Function(AppLocalizations)? _skinError;
  int _skinEpoch = 0;
  int _languageEpoch = 0;
  AppLocalizations get _l =>
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('en'));
  bool _busy = true;
  bool _thinking = false;
  int _searchEpoch = 0;
  bool _computerPaused = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchEpoch++;
    _recordController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = _service ?? await widget.createService();
      _service = service;
      var view = await service.view();
      try {
        final humanColor = await widget.store.loadHumanColor();
        if (humanColor != null) view = await service.startGame(humanColor);
        final saved = await widget.store.load();
        if (saved != null) view = await service.restore(saved);
      } catch (error) {
        _error = (l) => l.restoreSavedError('$error');
      }
      if (mounted) setState(() => _view = view);
    } catch (error) {
      if (mounted) setState(() => _error = (l) => l.openError('$error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _maybeComputer();
  }

  Future<void> _maybeComputer() async {
    final service = _service;
    if (!mounted ||
        _busy ||
        _thinking ||
        _computerPaused ||
        service == null ||
        !(_view?.computerTurn ?? false)) {
      return;
    }
    final epoch = ++_searchEpoch;
    var advanced = false;
    setState(() => _thinking = true);
    try {
      final view = await service.computerTurn();
      if (!mounted || epoch != _searchEpoch) return;
      if (view == null) {
        setState(() => _error = (l) => l.computerNoMove);
        return;
      }
      setState(() {
        _view = view;
        _busy = true;
      });
      await widget.store.saveHumanColor(
        view.computerBoth ? 'Computer' : view.humanColor,
      );
      await widget.store.save(view.movetext);
      advanced = true;
    } catch (error) {
      if (mounted && epoch == _searchEpoch) {
        setState(() => _error = (l) => l.computerError('$error'));
      }
    } finally {
      if (mounted && epoch == _searchEpoch) {
        setState(() {
          _thinking = false;
          _busy = false;
        });
        if (advanced) _maybeComputer();
      }
    }
  }

  Future<bool> _act(Future<GameView> Function(GameService) action) async {
    final service = _service;
    if (_busy || service == null) return false;
    _searchEpoch++;
    setState(() {
      _thinking = false;
      _busy = true;
      _error = null;
    });
    try {
      final view = await action(service);
      if (!mounted) return false;
      setState(() => _view = view);
      try {
        await widget.store.saveHumanColor(
          view.computerBoth ? 'Computer' : view.humanColor,
        );
        await widget.store.save(view.movetext);
      } catch (error) {
        if (mounted) {
          setState(() => _error = (l) => l.saveError('$error'));
        }
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = (l) => l.updateError('$error'));
      try {
        final current = await service.view();
        if (!mounted) return false;
        setState(() => _view = current);
        await widget.store.saveHumanColor(
          current.computerBoth ? 'Computer' : current.humanColor,
        );
        await widget.store.save(current.movetext);
      } catch (recoveryError) {
        if (mounted) {
          setState(
            () => _error = (l) => l.recoveryError('$error', '$recoveryError'),
          );
        }
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
      _maybeComputer();
    }
  }

  Future<void> _movetext() async {
    final controller = _recordController;
    controller.text = _view?.movetext ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l.saveTitle),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: const Key('movetext-input'),
            controller: controller,
            textDirection: TextDirection.ltr,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: _l.movetextLabel,
              helperText: _l.movetextHint,
              helperMaxLines: 3,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: controller.text)),
            child: Text(_l.copy),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(_l.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final restored = await _act(
                (service) => service.restore(controller.text),
              );
              if (restored && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              } else if (dialogContext.mounted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_error?.call(_l) ?? _l.restoreFailed)),
                );
              }
            },
            child: Text(_l.restore),
          ),
        ],
      ),
    );
  }

  Future<void> _example(GameView view) async {
    final candidates = view.legalMoves;
    if (candidates.isEmpty) return;
    final current = candidates.indexWhere(
      (move) => move.notation == view.inspectedMove?.notation,
    );
    final next = candidates[(current + 1) % candidates.length];
    await _act((service) => service.inspect(next.notation));
  }

  Future<void> _changeLanguage(String code) async {
    final epoch = ++_languageEpoch;
    setState(() => _languageError = null);
    try {
      await widget.onLanguageChanged?.call(code);
    } catch (error) {
      if (mounted && epoch == _languageEpoch) {
        setState(() => _languageError = (l) => l.languageSaveError('$error'));
      }
    }
  }

  Future<void> _chooseSkin() async {
    final skin = await showDialog<AppSkin>(
      context: context,
      builder: (_) =>
          SkinPicker(selected: AppSkin.of(context), onBackup: _settingsBackup),
    );
    if (skin == null || !mounted) return;
    final epoch = ++_skinEpoch;
    setState(() => _skinError = null);
    try {
      await widget.onSkinChanged?.call(skin);
    } catch (error) {
      if (mounted && epoch == _skinEpoch) {
        setState(() => _skinError = (l) => l.skinSaveError('$error'));
      }
    }
  }

  Widget _skinSelector() => IconButton(
    key: const Key('skin-selector'),
    tooltip: _l.chooseSkin,
    onPressed: widget.onSkinChanged == null ? null : _chooseSkin,
    icon: const Icon(Icons.palette_outlined),
    visualDensity: VisualDensity.compact,
  );

  Future<bool> _settingsBackup() async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => SettingsBackupDialog(
          settings: SettingsBackup(
            AppLanguage.fromCode(_l.localeName) ?? AppLanguage.english,
            AppSkin.of(context),
          ),
          onRestore: (settings) => Future.wait([
            widget.onLanguageChanged!(settings.language.code),
            widget.onSkinChanged!(settings.skin),
          ]).then((_) {}),
        ),
      ) ??
      false;

  Future<void> _chooseLanguage() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => LanguagePicker(
        selected: AppLanguage.fromCode(_l.localeName) ?? AppLanguage.english,
        onBackup: _settingsBackup,
      ),
    );
    if (code != null && mounted) await _changeLanguage(code);
  }

  Widget _languageSelector() {
    final current = AppLanguage.fromCode(_l.localeName) ?? AppLanguage.english;
    return IconButton(
      key: const Key('language-selector'),
      tooltip: _l.language,
      onPressed: widget.onLanguageChanged == null ? null : _chooseLanguage,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 18),
          const SizedBox(width: 4),
          Text(current.flag, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _controls(
    GameView view,
    double width,
    double height, {
    required bool showHeader,
  }) {
    final skin = AppSkin.of(context);
    final candidates = view.legalMoves;
    final supportText = view.supports
        .map(
          (pair) =>
              '${squareName(pair.first)} + ${squareName(pair.second)} → (${pair.fileTwice / 2}, ${pair.rankTwice / 2})',
        )
        .join('; ');
    final record = view.movetext;
    Widget button(String label, VoidCallback? onPressed) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/branding/sanqi-logo.svg',
                    width: 30,
                    height: 30,
                    semanticsLabel: _l.logoLabel,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sanqi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _languageSelector(),
                  _skinSelector(),
                ],
              ),
            ),
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    view.winner == null
                        ? (view.sideToMove == 'White'
                              ? _l.whiteToMove
                              : _l.blackToMove)
                        : (view.winner == 'White'
                              ? _l.whiteWins
                              : _l.blackWins),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_thinking) Text(_l.thinking),
                if (view.computerBoth && _computerPaused) Text(_l.paused),
                if (!_busy &&
                    !_thinking &&
                    view.computerTurn &&
                    !_computerPaused)
                  Flexible(
                    flex: 2,
                    child: TextButton(
                      onPressed: _maybeComputer,
                      child: Text(
                        _l.retryComputer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: skin.button,
                border: Border.all(color: skin.border),
                borderRadius: BorderRadius.circular(skin.radius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('game-mode'),
                    value: view.computerBoth
                        ? 'Computer'
                        : view.humanColor ?? 'Local',
                    isExpanded: true,
                    dropdownColor: skin.surface,
                    items: [
                      DropdownMenuItem(
                        value: 'Local',
                        child: Text(
                          _l.humanHuman,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'White',
                        child: Text(
                          _l.humanComputer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Black',
                        child: Text(
                          _l.computerHuman,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Computer',
                        child: Text(
                          _l.computerComputer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            _computerPaused = false;
                            _act(
                              (service) => service.startGame(
                                value == 'Local' ? null : value,
                              ),
                            );
                          },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                button(
                  _l.newGame,
                  _busy
                      ? null
                      : () {
                          _computerPaused = false;
                          _act((service) => service.newGame());
                        },
                ),
                button(
                  _l.undo,
                  _busy || !view.canUndo
                      ? null
                      : () {
                          _computerPaused = view.computerBoth;
                          _act((service) => service.undo());
                        },
                ),
                button(_l.saveRestore, _busy ? null : _movetext),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                button(
                  _l.exampleMove,
                  _busy || view.computerTurn || candidates.isEmpty
                      ? null
                      : () => _example(view),
                ),
                button(
                  _l.about,
                  () => showDialog<void>(
                    context: context,
                    builder: (_) => const SanqiAboutDialog(),
                  ),
                ),
                if (view.computerBoth)
                  button(
                    _computerPaused ? _l.resume : _l.pause,
                    _busy
                        ? null
                        : () {
                            _computerPaused = !_computerPaused;
                            _act((service) => service.cancelSearch());
                          },
                  ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Tooltip(
                      message: supportText.isEmpty
                          ? _l.selectHint
                          : supportText,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          view.inspectedMove == null
                              ? (view.selected == null
                                    ? ''
                                    : _l.selectedSummary(
                                        squareName(view.selected!),
                                        view.legalMoves
                                            .where(
                                              (move) =>
                                                  move.from == view.selected,
                                            )
                                            .length,
                                      ))
                              : '${view.inspectedMove!.notation} · $supportText',
                          maxLines: 2,
                          textDirection: view.inspectedMove == null
                              ? null
                              : TextDirection.ltr,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            _recentMoves(record, constraints),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentMoves(String record, BoxConstraints constraints) {
    final style = Theme.of(context).textTheme.bodySmall;
    final scaler = MediaQuery.textScalerOf(context);
    // Keep the end of the record visible even when only one line fits.
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 2,
    );
    String suffix(int start) =>
        start == 0 ? record : '…${record.substring(start)}';
    var low = 0;
    var high = record.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      painter.text = TextSpan(text: suffix(middle), style: style);
      painter.layout(maxWidth: constraints.maxWidth);
      if (painter.didExceedMaxLines || painter.height > constraints.maxHeight) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    painter.dispose();
    return Text(
      record.isEmpty ? _l.noMoves : suffix(low),
      textDirection: record.isEmpty ? null : TextDirection.ltr,
      key: const Key('recent-moves'),
      maxLines: 2,
      overflow: TextOverflow.clip,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final error = _error ?? _languageError ?? _skinError;
    final skin = AppSkin.of(context);
    return LayoutBuilder(
      builder: (context, screen) {
        final landscapeScreen = screen.maxWidth > screen.maxHeight;
        return Scaffold(
          appBar: landscapeScreen
              ? null
              : AppBar(
                  toolbarHeight: 48,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SvgPicture.asset(
                      'assets/branding/sanqi-logo.svg',
                      semanticsLabel: _l.logoLabel,
                    ),
                  ),
                  title: const Text('Sanqi'),
                  actions: [_languageSelector(), _skinSelector()],
                ),
          body: CustomPaint(
            painter: GameBackground(skin: skin),
            child: SafeArea(
              child: Column(
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        error(_l),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Expanded(
                    child: view == null
                        ? Center(
                            child: _busy
                                ? const CircularProgressIndicator()
                                : FilledButton(
                                    onPressed: _initialize,
                                    child: Text(_l.retry),
                                  ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = math.max(
                                0.0,
                                constraints.maxWidth - 16,
                              );
                              final height = math.max(
                                0.0,
                                constraints.maxHeight - 16,
                              );
                              final panelHeight = math.min(220.0, height * .45);
                              final panelWidth = math.min(260.0, width * .42);
                              final portraitSide = math.min(
                                width,
                                math.max(0.0, height - panelHeight - 8),
                              );
                              final landscapeSide = math.min(
                                height,
                                math.max(0.0, width - panelWidth - 8),
                              );
                              final landscape = landscapeSide > portraitSide;
                              final side = landscape
                                  ? landscapeSide
                                  : portraitSide;
                              final board = SizedBox(
                                width: side,
                                height: side,
                                child: SanqiBoard(
                                  view: view,
                                  enabled:
                                      !_busy &&
                                      !view.computerTurn &&
                                      view.winner == null,
                                  onTap: (square) =>
                                      _act((service) => service.tap(square)),
                                  onInspect: (move) =>
                                      _act((service) => service.inspect(move)),
                                ),
                              );
                              final controlsWidth = landscape
                                  ? panelWidth
                                  : width;
                              final controlsHeight = landscape
                                  ? height
                                  : panelHeight;
                              final controls = SizedBox(
                                width: controlsWidth,
                                height: controlsHeight,
                                child: DecoratedBox(
                                  key: const Key('controls-panel'),
                                  decoration: BoxDecoration(
                                    color: skin.surface,
                                    border: Border.all(color: skin.border),
                                    borderRadius: BorderRadius.circular(
                                      skin.radius,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.topLeft,
                                      child: _controls(
                                        view,
                                        math.max(0, controlsWidth - 16),
                                        math.max(
                                          212.0 + (landscapeScreen ? 40 : 0),
                                          controlsHeight - 16,
                                        ),
                                        showHeader: landscapeScreen,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              return Padding(
                                padding: const EdgeInsets.all(8),
                                child: landscape
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          board,
                                          const SizedBox(width: 8),
                                          controls,
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          board,
                                          const SizedBox(height: 8),
                                          controls,
                                        ],
                                      ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
