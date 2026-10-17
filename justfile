# Task runner for example-package. Run `just` to list the recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

# List the recipes.
default:
    @just --list

# Install the locked development environment.
sync:
    uv sync --locked

# Regenerate uv.lock after changing dependencies in pyproject.toml.
lock:
    uv lock

# Run every read-only static check.
lint:
    uv run --locked ruff check .
    uv run --locked ruff format --check .
    uv run --locked actionlint
    uv run --locked zizmor --pedantic --quiet .

# Apply the formatter and the safe lint fixes.
format:
    uv run --locked ruff format .
    uv run --locked ruff check --fix .

# Type-check the package and the tests.
type-check:
    uv run --locked mypy src tests

# Run the test suite. Extra arguments go to pytest.
test *args:
    uv run --locked pytest {{ args }}

# Run every check that CI runs on the source tree.
check: lint type-check test

# Install the pre-commit hook, which runs `just lint`.
hooks-install:
    #!/usr/bin/env bash
    set -euo pipefail
    hooks_path="$(git config --get core.hooksPath || true)"
    if [[ -z "$hooks_path" ]]; then
        uv run --locked pre-commit install
        exit 0
    fi
    # Print a path with symbolic links resolved. Its last components may not
    # exist yet.
    canonical() {
        local path="$1" suffix=""
        while [[ ! -d "$path" ]]; do
            suffix="/$(basename "$path")$suffix"
            path="$(dirname "$path")"
        done
        printf '%s%s\n' "$(cd "$path" && pwd -P)" "$suffix"
    }
    # `pre-commit install` refuses to run while core.hooksPath is set, so
    # write a hook that calls the pre-commit runner at Git's effective path.
    # A hooks directory outside this repository is shared with other
    # repositories, and this project's hook must not replace theirs.
    hooks_dir="$(canonical "$(git rev-parse --path-format=absolute --git-path hooks)")"
    top="$(canonical "$(git rev-parse --show-toplevel)")"
    git_dir="$(canonical "$(git rev-parse --path-format=absolute --git-common-dir)")"
    case "$hooks_dir/" in
        "$top/"* | "$git_dir/"*) ;;
        *)
            echo "hooks-install: core.hooksPath is $hooks_path, which is outside this repository." >&2
            echo "hooks-install: Call 'just lint' from the pre-commit hook there, or give this" >&2
            echo "hooks-install: repository its own: git config core.hooksPath .git/hooks" >&2
            exit 1
            ;;
    esac
    hook="$hooks_dir/pre-commit"
    content="$(printf '%s\n' \
        '#!/usr/bin/env bash' \
        '# Installed by `just hooks-install`.' \
        'exec uv run --locked pre-commit run --hook-stage pre-commit')"
    if [[ -f "$hook" && "$(cat "$hook")" == "$content" ]]; then
        echo "hooks-install: already installed at $hook"
        exit 0
    fi
    if [[ -e "$hook" || -L "$hook" ]]; then
        backup="$(mktemp "$hook.backup.XXXXXX")"
        mv "$hook" "$backup"
        echo "hooks-install: moved the existing hook to $backup"
    fi
    mkdir -p "$(dirname "$hook")"
    printf '%s\n' "$content" > "$hook"
    chmod +x "$hook"
    echo "hooks-install: installed $hook"

# Build the sdist and the wheel into dist/.
build:
    rm -rf dist
    uv build --out-dir dist

# Install the built wheel into a clean environment and smoke-test it.
package-check: build
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    wheels=(dist/*.whl)
    if [[ ${#wheels[@]} -ne 1 ]]; then
        echo "package-check: expected one wheel in dist/, found ${#wheels[@]}" >&2
        exit 1
    fi
    expected="$(uv version --short)"
    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' EXIT
    uv venv --quiet "$scratch/venv"
    uv pip install --quiet --python "$scratch/venv/bin/python" "${wheels[0]}"
    # -I keeps the source tree and PYTHONPATH off sys.path, so only the
    # installed wheel can satisfy the import.
    installed="$("$scratch/venv/bin/python" -I -c \
        'import importlib.metadata, example_package; print(importlib.metadata.version("example-package"))')"
    if [[ "$installed" != "$expected" ]]; then
        echo "package-check: wheel reports version $installed, pyproject.toml has $expected" >&2
        exit 1
    fi
    # init:cli-begin
    "$scratch/venv/bin/example-command" --help >/dev/null
    # init:cli-end
    echo "package-check: ${wheels[0]#dist/} installs and reports version $installed"

# Bump the version, then commit and tag it. Does not push.
release bump:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
        echo "release: commit or remove every change, including untracked files" >&2
        exit 1
    fi
    tag="v$(uv version --bump {{ quote(bump) }} --dry-run --short)"
    if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
        echo "release: tag $tag already exists" >&2
        exit 1
    fi
    just check
    uv version --bump {{ quote(bump) }} --frozen
    uv lock
    git add pyproject.toml uv.lock
    git commit --quiet --message "Release $tag"
    git tag --annotate "$tag" --message "Release $tag"
    echo "release: committed and tagged $tag. Push with: git push origin HEAD $tag"
# init:publish-begin

# Check that a release tag matches the version in pyproject.toml.
release-check tag="":
    #!/usr/bin/env bash
    set -euo pipefail
    tag={{ quote(tag) }}
    # The argument wins over GITHUB_REF_NAME, which CI sets on tag pushes.
    tag="${tag:-${GITHUB_REF_NAME:-}}"
    if [[ -z "$tag" ]]; then
        echo "release-check: pass a tag, or set GITHUB_REF_NAME" >&2
        exit 2
    fi
    version="$(uv version --short)"
    if [[ "$tag" != "v$version" ]]; then
        echo "release-check: tag $tag does not match version $version in pyproject.toml" >&2
        exit 1
    fi
    echo "release-check: tag $tag matches pyproject.toml"
# init:publish-end

# Remove build output, tool caches, and the virtual environment.
clean:
    rm -rf .coverage .mypy_cache .pytest_cache .ruff_cache .venv build dist htmlcov
# init:template-begin

# Lint scripts/init and run its Bats tests.
test-init:
    shellcheck scripts/init tests/init/*.bats
    bats tests/init

# Create a project from HEAD with one init variant, then check it.
test-generated variant:
    #!/usr/bin/env bash
    set -euo pipefail
    case {{ quote(variant) }} in
        cli) flags=() ;;
        library) flags=(--library) ;;
        no-publish) flags=(--no-publish) ;;
        custom-names) flags=(--distribution custom-dist --command custom-cmd) ;;
        *) echo "test-generated: unknown variant: {{ variant }}" >&2; exit 2 ;;
    esac
    root="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/test-generated.XXXXXX")"
    trap 'rm -rf "$root"' EXIT
    scripts/init "$root/out" generated_project --ref HEAD ${flags[@]+"${flags[@]}"}
    cd "$root/out"
    just sync check package-check
# init:template-end
