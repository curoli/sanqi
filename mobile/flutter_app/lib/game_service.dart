import 'package:shared_preferences/shared_preferences.dart';

import 'src/rust/api/game.dart';

abstract class GameService {
  Future<GameView> view();
  Future<GameView> tap(int square);
  Future<GameView> inspect(String move);
  Future<GameView> undo();
  Future<GameView> newGame();
  Future<GameView> restore(String movetext);
}

class RustGameService implements GameService {
  RustGameService(this.game);

  final MobileGame game;

  @override
  Future<GameView> view() => game.view();
  @override
  Future<GameView> tap(int square) => game.tap(index: square);
  @override
  Future<GameView> inspect(String move) => game.inspectMove(notation: move);
  @override
  Future<GameView> undo() => game.undo();
  @override
  Future<GameView> newGame() => game.newGame();
  @override
  Future<GameView> restore(String movetext) => game.restore(movetext: movetext);
}

abstract class GameStore {
  Future<String?> load();
  Future<void> save(String movetext);
}

class PreferenceGameStore implements GameStore {
  static const storageKey = 'sanqi.movetext.v1';

  @override
  Future<String?> load() => SharedPreferencesAsync().getString(storageKey);

  @override
  Future<void> save(String movetext) =>
      SharedPreferencesAsync().setString(storageKey, movetext);
}
