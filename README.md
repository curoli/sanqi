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

## Development

The development toolchain is pinned to Rust 1.99.1 in `rust-toolchain.toml`.
Rustup installs it automatically. The minimum supported Rust version is
1.88 (Rust 2024, including let chains); CI checks both the minimum version and
current stable Rust.

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --locked
```

CI builds, installs, and tests Python wheels on Linux (x86-64 and ARM64), Windows
(x86-64), and macOS (Intel and Apple Silicon), using Python 3.9, 3.13, and 3.14.
Releases cover every Python version from 3.9 through 3.14. Linux wheels use
manylinux 2.28 (glibc 2.28 or newer).

The dependency security workflow checks `Cargo.lock` against RustSec advisories
on pushes, pull requests, every Monday, and before releases. Vulnerabilities and
advisory warnings block publication. To run it locally, install `cargo-audit`
with `cargo install cargo-audit --locked`, then run `cargo audit --deny warnings`.
Dependabot checks Cargo, Python build dependencies, and GitHub Actions monthly.

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

## Releasing

Tag pushes like `v0.1.1` trigger release workflows for:

- `sanqi-core`, `sanqi-engine`, and `sanqi-render` on `crates.io`
- `sanqi-python` on PyPI

Before the first release, configure:

- a GitHub Actions secret `CARGO_REGISTRY_TOKEN` for `crates.io`
- a PyPI Trusted Publisher for the `pypi` GitHub environment

Release details are collected in [RELEASING.md](RELEASING.md), and user-facing
changes in [CHANGELOG.md](CHANGELOG.md).
