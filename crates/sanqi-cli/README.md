# sanqi-cli

Small command-line demo for the Sanqi Rust engine.

## Run

From the repository root:

```bash
cargo run -p sanqi-cli -- board
```

## Commands

```bash
cargo run -p sanqi-cli -- board
cargo run -p sanqi-cli -- moves a1-b3
cargo run -p sanqi-cli -- best 2 a1-b3
cargo run -p sanqi-cli -- best-time 4 250 a1-b3
cargo run -p sanqi-cli -- bench 4 250
cargo run -p sanqi-cli -- bench-save 4 250 baseline.tsv
cargo run -p sanqi-cli -- bench-compare baseline.tsv candidate.tsv
cargo run -p sanqi-cli -- svg a7-b5 a1-b3
cargo run -p sanqi-cli -- play 3 250 black
```

`bench` prints one tab-separated row per benchmark case plus a `summary` row, so repeated runs can be compared easily.
`bench-save` writes the same tabular format to a file, and `bench-compare` prints deltas between two saved benchmark files.

The move list after a command is applied in order, starting from the initial position.

## Interactive Play

```bash
cargo run -p sanqi-cli -- play
```

Optional arguments:

```bash
cargo run -p sanqi-cli -- play 3 250 black
cargo run -p sanqi-cli -- play 2 500 white
```

Inside the REPL:

- `a1-b3` applies a move
- `moves` lists legal moves
- `go` asks the engine for the current side to move
- `svg a1-b3` prints annotated SVG for that move
- `quit` exits
