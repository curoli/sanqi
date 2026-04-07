# sanqi-cli

Small command-line demo for the Sanqi Rust engine.

## Run

For quick experiments, debug builds are fine:

From the repository root:

```bash
cargo run -p sanqi-cli -- board
```

For actual play and engine benchmarks, use a release build:

```bash
cargo run --release -p sanqi-cli -- play
```

Or install the CLI once and run it directly:

```bash
cargo install --path crates/sanqi-cli --locked
sanqi play
```

## Commands

```bash
cargo run --release -p sanqi-cli -- board
cargo run --release -p sanqi-cli -- moves a1-b3
cargo run --release -p sanqi-cli -- best 2 a1-b3
cargo run --release -p sanqi-cli -- best-time 4 250 a1-b3
cargo run --release -p sanqi-cli -- presets
cargo run --release -p sanqi-cli -- bench 4 250
cargo run --release -p sanqi-cli -- bench-save 4 250 baseline.tsv
cargo run --release -p sanqi-cli -- bench-compare baseline.tsv candidate.tsv
cargo run --release -p sanqi-cli -- record h1-d3 h8-d6 a1-d4
cargo run --release -p sanqi-cli -- replay examples/game.sanqi
cargo run --release -p sanqi-cli -- svg a7-b5 a1-b3
cargo run --release -p sanqi-cli -- play normal human machine
```

`bench` prints one tab-separated row per benchmark case plus a `summary` row, so repeated runs can be compared easily.
`bench-save` writes the same tabular format to a file, and `bench-compare` prints deltas between two saved benchmark files.

The move list after a command is applied in order, starting from the initial position.

## Movetext

Games can be serialized in a simple PGN-like movetext:

```text
1. h1-d3 h8-d6 2. a1-d4
```

Use `record` to format a move list as movetext and `replay` to load a movetext
file and show the final board.

## Interactive Play

```bash
cargo run -p sanqi-cli -- play
```

Optional arguments:

```bash
cargo run --release -p sanqi-cli -- play
cargo run --release -p sanqi-cli -- play fast human machine
cargo run --release -p sanqi-cli -- play normal machine human
cargo run --release -p sanqi-cli -- play think human human
cargo run --release -p sanqi-cli -- play analysis machine machine
cargo run --release -p sanqi-cli -- play 3 250 human machine
```

Without arguments, `play` uses the `normal` preset.
The first optional argument can be either a preset name (`fast`, `normal`, `think`, `analysis`)
or an explicit depth. With an explicit depth, the next argument must be the time budget in milliseconds.
The optional player arguments are given as `white black` and each can be either `human` or `machine`.

Inside the REPL:

- `a1-b3` applies a move
- `moves` lists legal moves
- `go` asks the engine for the current side to move
- `svg a1-b3` prints annotated SVG for that move
- `quit` exits
