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

## License

[CC0 1.0 Universal](LICENSE.md)
