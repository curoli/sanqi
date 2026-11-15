# sanqi-mobile

Private Flutter Rust Bridge v2 adapter for the Sanqi mobile prototype.

Computer play delegates to `sanqi-engine` on a detached movetext snapshot, with a
600 ms iterative-search budget and depth cap 6. `find_computer_move` holds no
live session lock. `apply_computer_move` requires the matching monotonic session
revision and a computer turn before validating/playing the reply through core.
Reset, restore, mode changes, and undo invalidate outstanding results, including
results for a position that later happens to recur. New Game preserves the mode;
`start_game` changes mode and resets. Computer-mode undo returns to the previous
human decision point; local-mode undo remains one ply.

`api::game::MobileGame` owns one `sanqi_core::Game`. The generated Dart object is
an opaque handle, not a serialized game or a global singleton. Its asynchronous
methods return immutable snapshots with the existing renderer's SVG, current
player/winner, core-generated legal moves, selected square, inspected support
pairs/pivots, canonical movetext, and undo availability.

- `tap` selects a current-player piece or applies a core-generated legal move
  through `Game::play`.
- `inspect_move` queries `Position::supporting_pivots` without playing anything.
  Every supporting pair is returned; the move remains one from/to pair.
- `undo` reconstructs a `Game` by replaying all but the last move. This is O(n)
  and adequate for the first prototype; it requires no change to the core API.
- `restore` parses into a replacement `Game` before committing it, preserving
  the current game when parsing or move validation fails.
- `new_game` resets to `Game::new()`.

Square indices are core indices: `a1 = 0`, `h1 = 7`, `a8 = 56`, `h8 = 63`.
Pivot coordinates are doubled, preserving half-square positions exactly.
Only display selection is managed here; rules and move identity remain in core.

Run `cargo test -p sanqi-mobile` from the workspace. Generated glue lives in
`src/frb_generated.rs` and `mobile/flutter_app/lib/src/rust`; regenerate both
with the pinned code generator as described in the [mobile guide](../../mobile/flutter_app/README.md).
The generated module alone allows Clippy's `unwrap_used` lint; handwritten
mobile code inherits the workspace's stricter lints.
