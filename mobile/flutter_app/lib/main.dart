import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'board.dart';
import 'game_background.dart';
import 'game_service.dart';
import 'src/rust/api/game.dart';
import 'src/rust/frb_generated.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class SanqiApp extends StatelessWidget {
  const SanqiApp({super.key, required this.createService, required this.store});

  final Future<GameService> Function() createService;
  final GameStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sanqi',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315948)),
      scaffoldBackgroundColor: const Color(0xFFE9DFC9),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFE9DFC9)),
      useMaterial3: true,
    ),
    home: GameScreen(createService: createService, store: store),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.createService,
    required this.store,
  });

  final Future<GameService> Function() createService;
  final GameStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _recordController = TextEditingController();
  GameService? _service;
  GameView? _view;
  String? _error;
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
        _error = 'Could not restore saved game: $error';
      }
      if (mounted) setState(() => _view = view);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not open Sanqi: $error');
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
        throw StateError('The computer could not choose a move. Please retry.');
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
        setState(() => _error = 'Computer turn failed: $error');
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
          setState(() => _error = 'Game updated, but could not save: $error');
        }
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not update game: $error');
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
            () => _error =
                'Could not update game: $error. '
                'Could not refresh/save the current game: $recoveryError',
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
        title: const Text('Save / restore game'),
        content: SizedBox(
          width: 420,
          child: TextField(
            key: const Key('movetext-input'),
            controller: controller,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Movetext',
              helperText: 'Copy to save elsewhere, or paste a game to restore.',
              helperMaxLines: 3,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: controller.text)),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
                  SnackBar(content: Text(_error ?? 'Restore failed')),
                );
              }
            },
            child: const Text('Restore'),
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

  Widget _controls(
    GameView view,
    double width,
    double height, {
    required bool showHeader,
  }) {
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
            backgroundColor: const Color(0xFFE3E9D9),
            disabledBackgroundColor: const Color(0xFFECE5D7),
            side: const BorderSide(color: Color(0xFF879A7C)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
                    semanticsLabel: 'Sanqi logo',
                  ),
                  const SizedBox(width: 8),
                  Text('Sanqi', style: Theme.of(context).textTheme.titleLarge),
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
                        ? '${view.sideToMove} to move'
                        : '${view.winner} wins',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_thinking) const Text('Thinking…'),
                if (view.computerBoth && _computerPaused) const Text('Paused'),
                if (!_busy &&
                    !_thinking &&
                    view.computerTurn &&
                    !_computerPaused)
                  TextButton(
                    onPressed: _maybeComputer,
                    child: const Text('Retry computer move'),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF2E8D3),
                border: Border.all(color: const Color(0xFFB39D7D)),
                borderRadius: BorderRadius.circular(8),
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
                    items: const [
                      DropdownMenuItem(
                        value: 'Local',
                        child: Text('Human vs Human'),
                      ),
                      DropdownMenuItem(
                        value: 'White',
                        child: Text('Human vs Computer'),
                      ),
                      DropdownMenuItem(
                        value: 'Black',
                        child: Text('Computer vs human'),
                      ),
                      DropdownMenuItem(
                        value: 'Computer',
                        child: Text('Computer vs Computer'),
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
                  'New Game',
                  _busy
                      ? null
                      : () {
                          _computerPaused = false;
                          _act((service) => service.newGame());
                        },
                ),
                button(
                  'Undo',
                  _busy || !view.canUndo
                      ? null
                      : () {
                          _computerPaused = view.computerBoth;
                          _act((service) => service.undo());
                        },
                ),
                button('Save / restore', _busy ? null : _movetext),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                button(
                  'Example move',
                  _busy || view.computerTurn || candidates.isEmpty
                      ? null
                      : () => _example(view),
                ),
                if (view.computerBoth)
                  button(
                    _computerPaused ? 'Resume' : 'Pause',
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
                          ? 'Select a piece, then tap a destination to move.'
                          : supportText,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          view.inspectedMove == null
                              ? (view.selected == null
                                    ? ''
                                    : 'Selected ${squareName(view.selected!)} · ${view.legalMoves.where((move) => move.from == view.selected).length} legal moves')
                              : '${view.inspectedMove!.notation} · $supportText',
                          maxLines: 2,
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
      textDirection: Directionality.of(context),
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
      record.isEmpty ? 'No moves yet' : suffix(low),
      key: const Key('recent-moves'),
      maxLines: 2,
      overflow: TextOverflow.clip,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
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
                      semanticsLabel: 'Sanqi logo',
                    ),
                  ),
                  title: const Text('Sanqi'),
                ),
          body: CustomPaint(
            painter: const GameBackground(),
            child: SafeArea(
              child: Column(
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _error!,
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
                                    child: const Text('Retry'),
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
                                    color: const Color(0xFFF8EFDD),
                                    border: Border.all(
                                      color: const Color(0xFFB39D7D),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
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
