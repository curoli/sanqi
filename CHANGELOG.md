# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by Keep a Changelog, with versions following Semantic
Versioning.

## [Unreleased]

## [0.1.1] - 2026-10-19

### Changed

- Pin the development toolchain to Rust 1.99.1 and correct the minimum supported
  Rust version to 1.88, as required by existing let chains.
- Upgrade PyO3 to 0.30.1 and refresh transitive Rust dependencies.
- Enable PyO3's extension-module feature only when building Python packages with maturin.
- Update GitHub Actions and use locked dependencies in CI and release builds.

### Added

- CI check for the minimum supported Rust version and Rust documentation tests.
- Python wheel installation and binding tests on Python 3.9, 3.13, and 3.14.
- Monthly Dependabot updates for Cargo, Python build dependencies, and GitHub Actions.
- Release wheel builds and binding tests for CPython 3.9 through 3.14 on Linux x86-64/ARM64,
  Windows x86-64, and macOS Intel/Apple Silicon; Linux wheels use manylinux 2.28.
- RustSec dependency audits on pushes, pull requests, weekly, and before publishing.

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
