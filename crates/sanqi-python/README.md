# sanqi-python

Python bindings for the Sanqi Rust engine.

## Build

From `crates/sanqi-python`:

```bash
maturin develop
```

Or build a wheel:

```bash
maturin build
```

## Example

```python
import sanqi_python as sanqi

position = sanqi.Position.initial()
print(position.legal_moves()[:5])

move = position.best_move(2)
if move is not None:
    svg = position.svg_for_move(move)
    position.apply_move(move)
```

## Exposed API

- `Position.initial()`
- `Position.empty("white" | "black")`
- `Position.legal_moves()`
- `Position.is_legal_move(move)`
- `Position.apply_move(move)`
- `Position.piece_at(square)`
- `Position.set_piece(color, square)`
- `Position.clear_square(square)`
- `Position.piece_count(color)`
- `Position.ascii_board()`
- `Position.svg_board()`
- `Position.svg_for_move(move)`
- `Position.best_move(depth)`
- `Position.evaluate()`
- `Position.outcome()`
- `Position.supporting_pivots(move)`

