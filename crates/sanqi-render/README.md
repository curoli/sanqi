# sanqi-render

ASCII and SVG rendering helpers for the Sanqi board game.

This crate builds on `sanqi-core` and provides:

- terminal-friendly ASCII board rendering
- optional alternate text piece styles
- SVG export for positions
- SVG annotation for highlighted moves and pivots

Example:

```rust
use sanqi_core::Position;

let position = Position::initial();
let board = sanqi_render::ascii_board(&position);
assert!(board.contains("a b c d e f g h"));
```

Repository: <https://github.com/curoli/sanqi>
