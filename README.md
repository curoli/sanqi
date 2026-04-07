# Sanqi (三棋)

Sanqi (三棋, Sānqí) board game engine.

Here are the rules of Sanqi in 
[English 🇬🇧](docs/rules/sanqi-en.md),
[German 🇩🇪](docs/rules/sanqi-de.md),
[Indonesian 🇮🇩](docs/rules/sanqi-id.md),
[Arabic 🇸🇦](docs/rules/sanqi-ar.md),
[Chinese 🇨🇳](docs/rules/sanqi-zh.md),
[Spanish 🇪🇸](docs/rules/sanqi-es.md), and
[Turkish 🇹🇷](docs/rules/sanqi-tr.md).

## Play

You can play Sanqi from the command line with the Rust CLI:

```bash
cargo run --release -p sanqi-cli -- play
```

For repeated use, you can also install the CLI:

```bash
cargo install --path crates/sanqi-cli --locked
sanqi play
```

Examples:

```bash
cargo run --release -p sanqi-cli -- play normal human machine
cargo run --release -p sanqi-cli -- play think machine machine
```

This starts an interactive game. Moves use the format `a1-b3`.

Game scores can also be written in a simple PGN-like movetext:

```text
1. h1-d3 h8-d6 2. a1-d4
```

You can format a move list as movetext with:

```bash
cargo run --release -p sanqi-cli -- record h1-d3 h8-d6 a1-d4
```

Useful commands inside the CLI:

- `moves` lists legal moves
- `hint` asks the engine for a recommendation
- `svg a1-b3` shows an annotated SVG for a move
- `quit` exits the game

You can also access the engine from Python:

```python
import sanqi_python as sanqi

position = sanqi.Position.initial()
print(position.ascii_board())
print(position.legal_moves())

move = position.best_move(2)
if move is not None:
    position.apply_move(move)
    print(position.ascii_board())
```

For more details, see [crates/sanqi-cli/README.md](crates/sanqi-cli/README.md) and
[crates/sanqi-python/README.md](crates/sanqi-python/README.md).
