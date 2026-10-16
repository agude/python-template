# example-package

A short description of example-package.

## Installation

```sh
pip install example-package
```

## Usage

```sh
example-command --help
```

## Development

Requires [uv](https://docs.astral.sh/uv/) and [just](https://just.systems/).

```sh
just sync           # Install the locked development environment.
just hooks-install  # Install the pre-commit hook, which runs `just lint`.
just check          # Run lint, type-check, and test.
```

Run `just` to list every recipe.

## Releasing

```sh
just release patch  # Or minor or major. Runs `just check`, then commits and tags.
git push origin HEAD vX.Y.Z
```

Pushing the tag runs the Release workflow. It checks that the tag matches the
version in `pyproject.toml`, builds and smoke-tests the package, and publishes
it to PyPI with Trusted Publishing. Before the first release, register a
Trusted Publisher on PyPI for this repository with workflow `release.yml` and
environment `pypi`.

## License

[CC0 1.0 Universal](LICENSE.md)
