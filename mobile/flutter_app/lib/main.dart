import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'board.dart';
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
        service == null ||
        !(_view?.computerTurn ?? false)) {
      return;
    }
    final epoch = ++_searchEpoch;
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
      await widget.store.saveHumanColor(view.humanColor);
      await widget.store.save(view.movetext);
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
        await widget.store.saveHumanColor(view.humanColor);
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
        await widget.store.saveHumanColor(current.humanColor);
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

  Widget _controls(GameView view) {
    final candidates = view.legalMoves
        .where((move) => move.from == view.selected)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          view.winner == null
              ? '${view.sideToMove} to move'
              : '${view.winner} wins',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        DropdownButton<String>(
          key: const Key('game-mode'),
          value: view.humanColor ?? 'Local',
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: 'Local',
              child: Text('Local two-player game'),
            ),
            DropdownMenuItem(
              value: 'White',
              child: Text('Computer opponent — play White'),
            ),
            DropdownMenuItem(
              value: 'Black',
              child: Text('Computer opponent — play Black'),
            ),
          ],
          onChanged: _busy
              ? null
              : (value) => _act(
                  (service) =>
                      service.startGame(value == 'Local' ? null : value),
                ),
        ),
        const Text('Changing mode starts a new game.'),
        if (_thinking) const Text('Computer is thinking…'),
        if (!_busy && !_thinking && view.computerTurn)
          TextButton(
            onPressed: _maybeComputer,
            child: const Text('Retry computer move'),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _act((service) => service.newGame()),
              child: const Text('New Game'),
            ),
            OutlinedButton(
              onPressed: _busy || !view.canUndo
                  ? null
                  : () => _act((service) => service.undo()),
              child: const Text('Undo'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _movetext,
              child: const Text('Save / restore'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'White is at the bottom. Tap your piece, then a green destination to '
          'move. Hold a destination or choose a preview below to inspect support.',
        ),
        if (view.selected != null) ...[
          const SizedBox(height: 12),
          Text('Selected ${squareName(view.selected!)}'),
          if (candidates.isEmpty) const Text('No legal moves from this piece.'),
          Wrap(
            spacing: 6,
            children: [
              for (final move in candidates)
                ActionChip(
                  label: Text('Preview ${move.notation}'),
                  onPressed: _busy
                      ? null
                      : () => _act((service) => service.inspect(move.notation)),
                ),
            ],
          ),
        ],
        if (view.inspectedMove != null) ...[
          const SizedBox(height: 12),
          Text('Supports for ${view.inspectedMove!.notation}'),
          const Text('Blue rings: supporting pieces. Blue dots: pivots.'),
          for (final pair in view.supports)
            Text(
              '${squareName(pair.first)} + ${squareName(pair.second)} '
              '→ pivot (${pair.fileTwice / 2}, ${pair.rankTwice / 2})',
            ),
          const Text('Pivot coordinates count from a1 = (0, 0).'),
        ],
        const SizedBox(height: 12),
        const Text('Game record (saved on this device)'),
        SelectableText(view.movetext.isEmpty ? 'No moves yet' : view.movetext),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset(
            'assets/branding/sanqi-logo.svg',
            semanticsLabel: 'Sanqi logo',
          ),
        ),
        title: const Text('Sanqi 三棋'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                        final board = SanqiBoard(
                          view: view,
                          enabled:
                              !_busy &&
                              !view.computerTurn &&
                              view.winner == null,
                          onTap: (square) =>
                              _act((service) => service.tap(square)),
                          onInspect: (move) =>
                              _act((service) => service.inspect(move)),
                        );
                        if (constraints.maxWidth > 700 &&
                            constraints.maxHeight > 180) {
                          final side = math.min(
                            constraints.maxHeight - 24,
                            constraints.maxWidth - 344,
                          );
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: side, height: side, child: board),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 300,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: _controls(view),
                                ),
                              ),
                            ],
                          );
                        }
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 560,
                                ),
                                child: board,
                              ),
                              const SizedBox(height: 16),
                              _controls(view),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
