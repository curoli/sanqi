# sanqi-engine

Search and evaluation engine for the Sanqi board game.

This crate builds on `sanqi-core` and provides:

- static evaluation
- fixed-depth search
- iterative deepening with time budget
- optional seeded variation in equally prioritized root moves
- principal variation output
- search diagnostics for benchmarking and tuning

Example:

```rust
use sanqi_core::Position;

let position = Position::initial();
let result = sanqi_engine::best_move(&position, 2).expect("legal move");
println!("{}", result.best_move);
```

`analyze_iterative_varied(position, max_depth, time_budget, seed)` varies root
move-ordering ties while retaining the same evaluation and tactical priorities.
Supply fresh seeds for varied play, or a fixed seed for reproducible ordering
(time-limited results can still vary with available CPU time). Existing search
entry points retain their deterministic ordering. A forced or clearly preferred
move may still repeat; variation does not mean selecting arbitrary legal moves.

Repository: <https://github.com/curoli/sanqi>
