# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by Keep a Changelog, with versions following Semantic
Versioning.

## [0.1.0] - 2026-04-07

Initial public release.

### Added

- Rust workspace with `sanqi-core`, `sanqi-engine`, `sanqi-render`, `sanqi-cli`, and `sanqi-python`
- Sanqi position, move, and game modeling in Rust
- legal move generation, parsing, validation, apply/undo, and outcome detection
- search engine with iterative deepening, transposition table, quiescence search, and diagnostics
- ASCII and SVG board rendering with highlighted moves and pivots
- Python bindings via `pyo3`
- CLI commands for play, analysis, benchmarking, movetext import/export, and SVG output
- PGN-like movetext support for Sanqi games
- CI and release workflows for `crates.io` and PyPI
