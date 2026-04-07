# sanqi-core

Core rules and data structures for the Sanqi board game.

This crate provides:

- `Position` for board state
- `Move` in `from-to` notation such as `a1-b3`
- `Game` for complete move histories
- legal move generation and move validation
- PGN-like movetext import/export such as `1. h1-d3 h8-d6 2. a1-d4`

Example:

```rust
use sanqi_core::Position;

let position = Position::initial();
let moves = position.legal_moves();
assert!(!moves.is_empty());
```

Repository: <https://github.com/curoli/sanqi>
