# Releasing Sanqi

This repository publishes:

- `sanqi-core` to `crates.io`
- `sanqi-engine` to `crates.io`
- `sanqi-render` to `crates.io`
- `sanqi-python` to PyPI

`sanqi-cli` and the Rust crate `sanqi-python` are marked `publish = false` on
`crates.io`.

## One-time setup

Configure GitHub before the first release:

- add the repository secret `CARGO_REGISTRY_TOKEN`
- create the GitHub Actions environment `crates-io`
- create the GitHub Actions environment `pypi`
- configure PyPI Trusted Publishing for the `pypi` environment

For the PyPI Trusted Publisher, use values that match the workflow claims:

- PyPI project: `sanqi-python`
- owner: `curoli`
- repository: `sanqi`
- workflow file: `.github/workflows/release-python.yml`
- environment: `pypi`

## Before cutting a release

1. Update versions consistently.
2. Update `CHANGELOG.md`.
3. Make sure CI is green.
4. Confirm that the release workflows still match the package names and versions.

## Rust crate publish order

The release workflow publishes Rust crates in this order:

1. `sanqi-core`
2. `sanqi-engine`
3. `sanqi-render`

This order matters because `sanqi-engine` and `sanqi-render` depend on
`sanqi-core`.

## Cutting a release

Create and push an annotated tag:

```bash
git tag -a v0.1.0 -m "Sanqi 0.1.0"
git push origin v0.1.0
```

Tag pushes trigger:

- `.github/workflows/release-rust.yml`
- `.github/workflows/release-python.yml`

## After release

1. Verify the crates on `crates.io`.
2. Verify the wheel and sdist on PyPI.
3. Create or update the GitHub release notes.
