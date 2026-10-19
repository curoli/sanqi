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

1. Update the workspace version, internal dependency versions, and Python project
   version consistently, then regenerate `Cargo.lock`.
2. Move the pending changes in `CHANGELOG.md` into the release entry with its date.
3. Run the Rust publish dry run and build and test the Python distributions locally.
4. Commit and push the release changes, then wait for CI and the dependency security
   workflow to pass on that commit, including the Python wheel platform matrix.
5. Confirm that the release workflows still match the package names and versions.

Both release workflows must pass the RustSec dependency audit before publishing.

## Python distributions

The reusable `python-wheels.yml` workflow builds release wheels for CPython
3.9 through 3.14 on:

- Linux x86-64 and ARM64, using manylinux 2.28 (glibc 2.28 or newer)
- Windows x86-64
- macOS Intel and Apple Silicon

Each wheel is installed and the Python binding tests run on its native runner
before it is uploaded. CI exercises the same workflow on Python 3.9, 3.13, and
3.14. The release workflow builds a separate source distribution and merges it
with the tested wheels for PyPI Trusted Publishing. Publication requires every
wheel build, its tests, the source distribution, and the security audit to pass.

## Rust crate publish order

The release workflow publishes Rust crates in this order:

1. `sanqi-core`
2. `sanqi-engine`
3. `sanqi-render`

This order matters because `sanqi-engine` and `sanqi-render` depend on
`sanqi-core`.

## Cutting a release

After the checks above pass, create and push an annotated tag on the tested commit:

```bash
git tag -a v0.1.1 -m "Sanqi 0.1.1"
git push origin v0.1.1
```

Tag pushes trigger:

- `.github/workflows/release-rust.yml`
- `.github/workflows/release-python.yml`

## After release

1. Verify the crates on `crates.io`.
2. Verify the wheel and sdist on PyPI.
3. Create or update the GitHub release notes.
