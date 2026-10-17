# AGENTS.md

Guidance for coding agents that work in this repository.

<!-- init:template-begin -->
## This repository is a template

`scripts/init` creates projects from this repository; `README.md` describes
how. When you change the template:

- Keep it a working project. `just check package-check` must pass with the
  placeholders in place.
- Write the placeholders `example_package`, `example-package`, and
  `example-command` only where the project's own names belong. `init`
  replaces every occurrence and fails on any other case variant.
- Wrap optional content in `init:<name>-begin` and `init:<name>-end`
  comments, using the existing names `template`, `cli`, and `publish`. Do not
  nest blocks.
- Mark files that only the template needs as `export-ignore` in
  `.gitattributes`.
- After changing `scripts/init` or a marker block, run `just test-init` and
  `just test-generated <variant>` for each affected variant.
- `scripts/init` must run under Bash 3.2 with BSD or GNU tools: no `sed -i`,
  no associative arrays, and no `grep -P`.

<!-- init:template-end -->
## Project

example-package is a Python package with the import name `example_package`
and a `src/` layout. It supports Python 3.11 and newer.

## Commands

Use the `just` recipes. CI calls the same recipes, so a local pass predicts a
CI pass.

| Recipe | Effect |
| --- | --- |
| `just sync` | Installs the locked environment. |
| `just lint` | Runs ruff, ruff format in check mode, actionlint, and zizmor. Read-only. |
| `just format` | Applies ruff format and the safe ruff fixes. |
| `just type-check` | Runs mypy in strict mode. |
| `just test` | Runs pytest with a 90% branch-coverage floor. |
| `just check` | Runs lint, type-check, and test. Run it before every commit. |
| `just build package-check` | Builds the package, installs the wheel in a clean environment, and smoke-tests it. |
| `just lock` | Updates `uv.lock` after a dependency change. |
| `just release <bump>` | Bumps the version, commits, and tags. Does not push. |

## Rules

- Use uv for every Python operation. Add dependencies with `uv add` or
  `uv add --dev`, and commit `uv.lock`.
- `exclude-newer = "7 days"` in `pyproject.toml` hides releases younger than
  a week. Do not remove it to get a newer release; wait for the release to
  age.
- The version exists only in `pyproject.toml`. Change it with
  `just release`. Code reads it with `importlib.metadata.version()`.
- Workflows call `just` recipes and nothing else, apart from setup steps. To
  change what CI does, change a recipe.
- Actions are pinned to a full commit SHA with a `# vX.Y.Z` comment, every
  checkout sets `persist-credentials: false`, and each workflow starts from
  `permissions: {}`. zizmor enforces this in `just lint`.
- Dependabot does not update these pins, so bump them by hand:
  - `just-version` in every workflow.
  - The uv `version` in the CI lint job. It matches the uv in Dependabot's
    updater, so the lint job proves that Dependabot can update `uv.lock`.
    Raise it, and `required-version` in `pyproject.toml`, only after a
    Dependabot job log shows a newer uv.
- Each test-matrix leg sets `UV_PYTHON`. Without it, uv follows
  `.python-version` and every leg tests the same interpreter.
- A Python version in the test matrix is a support claim. Keep the matrix,
  the classifiers, `requires-python`, ruff's `target-version`, and mypy's
  `python_version` consistent.
- The pre-commit hook runs `just lint` and changes nothing. If it fails, run
  `just format`, then commit again.
