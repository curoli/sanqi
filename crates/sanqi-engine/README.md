# sanqi-engine

Search and evaluation engine for the Sanqi board game.

This crate builds on `sanqi-core` and provides:

- static evaluation
- fixed-depth search
- iterative deepening with time budget
- principal variation output
- search diagnostics for benchmarking and tuning

Example:

```rust
use sanqi_core::Position;

let position = Position::initial();
let result = sanqi_engine::best_move(&position, 2).expect("legal move");
println!("{}", result.best_move);
```

Repository: <https://github.com/curoli/sanqi>
