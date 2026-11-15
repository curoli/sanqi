# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by Keep a Changelog, with versions following Semantic
Versioning.

## [Unreleased]

### Fixed

- Use the full safe height for the mobile board in landscape by placing the
  header beside it. Example move cycles all legal moves across every piece,
  regardless of the current selection.
- Cancel mobile computer turns even when their initial Rust snapshot is still
  queued when Pause, New Game, Undo, restore, or a mode change occurs.

### Added

- Fourteen mobile skins with light/dark palettes, geometric backgrounds, button
  styling, and offline fonts; a localized preview chooser saves the selection
  without changing the board, pieces, or game state.
- Localized mobile About dialog with pronunciation, slogan, author credit,
  build date/commit metadata, and browser links to the repository and rules in
  the selected language. Links stay visible in a fixed footer; a scrollbar and
  localized scrolling cue reveal hidden text. Android/iOS CI and a local Flutter
  wrapper record build metadata at compilation.
- Mobile language selector with flags and saved preferences for English, German,
  Indonesian, Arabic, Chinese, Spanish, and Turkish, including right-to-left UI
  for Arabic and unchanged board orientation/movetext.
- Warm geometric mobile background, a bordered control panel, and tinted controls.
- Responsive mobile layout without scrolling, cycling example moves, recent-move
  display, and Computer vs Computer play with pause/resume.
- Four-square Sanqi logo with outlined 三棋 characters and contrasting game
  pieces, used for Android/iOS icons, native launch screens, app header, and README.
- Mobile computer opponent with a choice of color, asynchronous time-bounded
  search, thinking/retry UI, saved mode, stale-result protection, and round undo.
- Private `sanqi-mobile` crate with Rust-owned local game sessions through
  Flutter Rust Bridge v2, leaving the existing crate APIs unchanged.
- Android/iOS Flutter prototype with the Rust SVG board, legal move selection,
  supporting-pair and pivot previews, New Game, Undo, and movetext persistence.
- Mobile API, widget, native bridge, and on-device smoke tests, plus setup docs
  and Flutter CI.

## [0.1.2] - 2026-11-14

### Changed

- Update the development toolchain to Rust 1.100.0 and wheel builds to maturin 1.16.0.
- Refresh transitive Rust dependencies while retaining Rust 1.88 compatibility.
- Remove redundant Cargo homepage metadata flagged by Rust 1.100.

### Fixed

- Install Rust 1.88 explicitly in the minimum-version CI job so dependency updates
  cannot change the compiler version being installed.

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
