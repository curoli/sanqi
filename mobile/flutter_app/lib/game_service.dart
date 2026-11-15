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
  @override
  Future<GameView> startGame(String? humanColor) => humanColor == 'Computer'
      ? game.startComputerGame()
      : game.startGame(humanColor: humanColor);
  @override
  Future<GameView> cancelSearch() => game.cancelSearch();
  @override
  Future<GameView?> computerTurn() async {
    final snapshot = await game.view();
    if (!snapshot.computerTurn) return snapshot;
    final move = await findComputerMove(movetext: snapshot.movetext);
    if (move == null) return null;
    return game.applyComputerMove(
      expectedRevision: snapshot.revision,
      notation: move,
    );
  }
}

abstract class GameStore {
  Future<String?> load();
  Future<void> save(String movetext);
  Future<String?> loadHumanColor() async => null;
  Future<void> saveHumanColor(String? color) async {}
}

class PreferenceGameStore extends GameStore {
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
