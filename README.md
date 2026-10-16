# example-package
<!-- init:template-begin -->

> **This repository is a template.** Create a project from it with
> `scripts/init`, as described below. `scripts/init` removes this section and
> every other template-only part.

## Creating a project

Requires Git, [uv](https://docs.astral.sh/uv/), and
[just](https://just.systems/).

```sh
git clone https://github.com/agude/python-template.git ~/Projects/python-template
cd ~/Projects/python-template
scripts/init ~/Projects/my-project my_project
cd ~/Projects/my-project
just sync && just hooks-install && just check
git commit
```

`scripts/init <dest> <import-name>` does the following:

1. Fetches `origin` and exports `origin/main` with `git archive`.
   Uncommitted changes in the clone are not used.
2. Replaces the placeholders and removes the template-only parts.
3. Fails, and creates nothing, if any placeholder remains.
4. Runs `uv lock`, `git init`, and `git add`. It does not commit.

| Option | Effect |
| --- | --- |
| `--distribution NAME` | Sets the distribution name. Default: the import name with `_` replaced by `-`. |
| `--command NAME` | Sets the console script name. Default: the distribution name. |
| `--library` | Leaves out the command-line interface. |
| `--no-publish` | Leaves out the PyPI release workflow. |
| `--ref REF` | Copies `REF` instead of `origin/main`, without fetching. |

## How the template works

| Placeholder | Meaning |
| --- | --- |
| `example_package` | Import name |
| `example-package` | Distribution name |
| `example-command` | Console script name |

Optional content sits between `init:<name>-begin` and `init:<name>-end`
marker comments. `scripts/init` always removes `template` blocks, removes
`cli` blocks for `--library`, and removes `publish` blocks for
`--no-publish`. It removes the marker lines of the blocks it keeps.

Files that only the template needs are marked `export-ignore` in
`.gitattributes`, so `git archive` leaves them out.

## Maintaining the template

The template is itself a working project, so `just check package-check`
must pass. In addition:

- `just test-init` runs the Bats tests for `scripts/init`.
- `just test-generated <variant>` creates a project from `HEAD` and checks
  it. The variants are `cli`, `library`, `no-publish`, and `custom-names`.

The Template test workflow runs both on every push and once a week, which
catches upstream releases that break new projects between Dependabot
updates.

---
<!-- init:template-end -->

A short description of example-package.
<!-- init:publish-begin -->

## Installation

```sh
pip install example-package
```
<!-- init:publish-end -->
<!-- init:cli-begin -->

## Usage

```sh
example-command --help
```
<!-- init:cli-end -->

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
<!-- init:publish-begin -->

Pushing the tag runs the Release workflow. It checks that the tag matches the
version in `pyproject.toml`, builds and smoke-tests the package, and publishes
it to PyPI with Trusted Publishing. Before the first release, register a
Trusted Publisher on PyPI for this repository with workflow `release.yml` and
environment `pypi`.
<!-- init:publish-end -->

## License

[CC0 1.0 Universal](LICENSE.md)
