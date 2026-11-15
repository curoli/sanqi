import 'package:shared_preferences/shared_preferences.dart';

import 'src/rust/api/game.dart';

abstract class GameService {
  Future<GameView> view();
  Future<GameView> tap(int square);
  Future<GameView> inspect(String move);
  Future<GameView> undo();
  Future<GameView> newGame();
  Future<GameView> restore(String movetext);
  Future<GameView> startGame(String? humanColor) => newGame();
  Future<GameView?> computerTurn() async => null;
  Future<GameView> cancelSearch() => view();
}

class RustGameService extends GameService {
  RustGameService(
    this.game, {
    Future<String?> Function(String movetext)? findMove,
  }) : _findMove = findMove ?? ((record) => findComputerMove(movetext: record));

  final MobileGame game;
  final Future<String?> Function(String movetext) _findMove;
  int _searchGeneration = 0;

  @override
  Future<GameView> view() => game.view();
  @override
  Future<GameView> tap(int square) => game.tap(index: square);
  @override
  Future<GameView> inspect(String move) => game.inspectMove(notation: move);
  @override
  Future<GameView> undo() {
    _searchGeneration++;
    return game.undo();
  }

  @override
  Future<GameView> newGame() {
    _searchGeneration++;
    return game.newGame();
  }

  @override
  Future<GameView> restore(String movetext) {
    _searchGeneration++;
    return game.restore(movetext: movetext);
  }

  @override
  Future<GameView> startGame(String? humanColor) {
    _searchGeneration++;
    return humanColor == 'Computer'
        ? game.startComputerGame()
        : game.startGame(humanColor: humanColor);
  }

  @override
  Future<GameView> cancelSearch() {
    // Invalidate synchronously: a queued bridge view may run after cancellation.
    _searchGeneration++;
    return game.cancelSearch();
  }

  @override
  Future<GameView?> computerTurn() async {
    final generation = _searchGeneration;
    final snapshot = await game.view();
    if (generation != _searchGeneration) return null;
    if (!snapshot.computerTurn) return snapshot;
    final move = await _findMove(snapshot.movetext);
    if (generation != _searchGeneration) return null;
    if (move == null) return null;
    return game.applyComputerMove(
      expectedRevision: snapshot.revision,
      notation: move,
    );
  }
}

abstract class GameStore {
  Future<String?> loadLanguage() async => null;
  Future<void> saveLanguage(String code) async {}
  Future<String?> load();
  Future<void> save(String movetext);
  Future<String?> loadHumanColor() async => null;
  Future<void> saveHumanColor(String? color) async {}
}

class PreferenceGameStore extends GameStore {
  static const languageKey = 'sanqi.language.v1';
  @override
  Future<String?> loadLanguage() =>
      SharedPreferencesAsync().getString(languageKey);
  @override
  Future<void> saveLanguage(String code) =>
      SharedPreferencesAsync().setString(languageKey, code);
  static const storageKey = 'sanqi.movetext.v1';
  @override
  Future<String?> loadHumanColor() =>
      SharedPreferencesAsync().getString('sanqi.humanColor.v1');
  @override
  Future<void> saveHumanColor(String? color) async {
    if (color == null) {
      await SharedPreferencesAsync().remove('sanqi.humanColor.v1');
    } else {
      await SharedPreferencesAsync().setString('sanqi.humanColor.v1', color);
    }
  }

  @override
  Future<String?> load() => SharedPreferencesAsync().getString(storageKey);

  @override
  Future<void> save(String movetext) =>
      SharedPreferencesAsync().setString(storageKey, movetext);
}
