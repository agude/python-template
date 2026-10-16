#!/usr/bin/env bats
# Tests for scripts/init. Successful runs copy the committed HEAD, so commit
# template changes before running these tests.

setup() {
    TEMPLATE_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    INIT="$TEMPLATE_ROOT/scripts/init"
    DEST="$BATS_TEST_TMPDIR/out"
}

# Clone the template into a fixture repository that runs the working-tree
# scripts/init, so a test can commit a defect into the template content.
make_fixture() {
    FIXTURE="$BATS_TEST_TMPDIR/fixture"
    git clone --quiet "$TEMPLATE_ROOT" "$FIXTURE"
    cp "$INIT" "$FIXTURE/scripts/init"
}

commit_fixture() {
    (
        cd "$FIXTURE" || return 1
        git add --all
        git -c user.name=Test -c user.email=test@example.com commit --quiet --message "Inject a defect"
    )
}

assert_no_dest() {
    [ ! -e "$DEST" ]
    # The staging directory is removed as well.
    [ -z "$(find "$BATS_TEST_TMPDIR" -maxdepth 1 -name '.init.*')" ]
}

# Bash ignores `set -e` for a command negated with `!`, so negative
# assertions go through this function.
refute() {
    if "$@"; then
        echo "expected to fail: $*" >&2
        return 1
    fi
}

# Search the staged files, which are exactly the project's files. BusyBox
# grep, in the Bash 3.2 container, has no --exclude-dir.
assert_no_leftovers() {
    run git --git-dir="$DEST/.git" grep --cached -niE 'example[-_](package|command)|init:[a-z]+-(begin|end)'
    [ "$status" -eq 1 ]
    run git --git-dir="$DEST/.git" ls-files
    [ "$status" -eq 0 ]
    refute grep -qiE 'example[-_](package|command)' <<<"$output"
}

@test "--help prints usage and succeeds" {
    run "$INIT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: scripts/init <dest> <import-name>"* ]]
}

@test "missing arguments are a usage error" {
    run "$INIT" "$DEST"
    [ "$status" -eq 2 ]
    assert_no_dest
}

@test "an unknown option is a usage error" {
    run "$INIT" "$DEST" my_pkg --bogus
    [ "$status" -eq 2 ]
    assert_no_dest
}

@test "an invalid import name fails without creating dest" {
    run "$INIT" "$DEST" My-Package --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"import name 'My-Package' must match"* ]]
    assert_no_dest
}

@test "a Python keyword as the import name fails" {
    run "$INIT" "$DEST" class --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"is a Python keyword"* ]]
    assert_no_dest
}

@test "an import name with no valid default distribution name fails" {
    run "$INIT" "$DEST" _private --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"pass --distribution"* ]]
    assert_no_dest
}

@test "an invalid distribution name fails" {
    run "$INIT" "$DEST" my_pkg --distribution My_Dist --ref HEAD
    [ "$status" -eq 1 ]
    assert_no_dest
}

@test "an invalid command name fails" {
    run "$INIT" "$DEST" my_pkg --command my--cmd --ref HEAD
    [ "$status" -eq 1 ]
    assert_no_dest
}

@test "--command with --library is a usage error" {
    run "$INIT" "$DEST" my_pkg --library --command my-cmd --ref HEAD
    [ "$status" -eq 2 ]
    assert_no_dest
}

@test "a name that contains a placeholder fails" {
    run "$INIT" "$DEST" my_pkg --distribution example-command-tools --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"contains a template placeholder"* ]]
    assert_no_dest
}

@test "an existing dest fails and is left untouched" {
    mkdir "$DEST"
    touch "$DEST/keep"
    run "$INIT" "$DEST" my_pkg --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"destination already exists"* ]]
    [ "$(ls -A "$DEST")" = "keep" ]
}

@test "an unknown ref fails without creating dest" {
    run "$INIT" "$DEST" my_pkg --ref no-such-ref
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown ref: no-such-ref"* ]]
    assert_no_dest
}

@test "a leftover placeholder fails without creating dest" {
    make_fixture
    echo "EXAMPLE_PACKAGE_DEBUG=1" >"$FIXTURE/leftover.txt"
    commit_fixture
    run "$FIXTURE/scripts/init" "$DEST" my_pkg --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"leftover.txt"* ]]
    assert_no_dest
}

@test "a leftover placeholder in a file name fails without creating dest" {
    make_fixture
    touch "$FIXTURE/Example-Command.txt"
    commit_fixture
    run "$FIXTURE/scripts/init" "$DEST" my_pkg --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"Example-Command.txt"* ]]
    assert_no_dest
}

@test "an unclosed marker block fails without creating dest" {
    make_fixture
    printf '# init:cli-begin\nprint("cli")\n' >"$FIXTURE/unclosed.py"
    commit_fixture
    run "$FIXTURE/scripts/init" "$DEST" my_pkg --ref HEAD
    [ "$status" -eq 1 ]
    [[ "$output" == *"block cli is never closed"* ]]
    assert_no_dest
}

@test "the default project has a CLI and a release workflow" {
    run "$INIT" "$DEST" my_pkg --ref HEAD
    [ "$status" -eq 0 ]
    assert_no_leftovers
    [ -f "$DEST/src/my_pkg/__init__.py" ]
    [ -f "$DEST/src/my_pkg/cli.py" ]
    [ -f "$DEST/src/my_pkg/__main__.py" ]
    [ -f "$DEST/tests/test_my_pkg.py" ]
    [ -f "$DEST/.github/workflows/release.yml" ]
    grep -qx 'name = "my-pkg"' "$DEST/pyproject.toml"
    grep -qx 'my-pkg = "my_pkg.cli:main"' "$DEST/pyproject.toml"
    grep -qx 'module-name = "my_pkg"' "$DEST/pyproject.toml"
    grep -q 'venv/bin/my-pkg" --help' "$DEST/justfile"
    grep -qx 'name = "my-pkg"' "$DEST/uv.lock"
}

@test "template-only files and content are left out" {
    run "$INIT" "$DEST" my_pkg --ref HEAD
    [ "$status" -eq 0 ]
    [ ! -e "$DEST/scripts" ]
    [ ! -e "$DEST/tests/init" ]
    [ ! -e "$DEST/.github/workflows/template-test.yml" ]
    refute grep -q 'test-init' "$DEST/justfile"
    refute grep -q 'export-ignore' "$DEST/.gitattributes"
    refute grep -qi 'template' "$DEST/README.md"
    refute grep -qi 'template' "$DEST/AGENTS.md"
}

@test "the project is a Git repository with staged files and no commits" {
    run "$INIT" "$DEST" my_pkg --ref HEAD
    [ "$status" -eq 0 ]
    cd "$DEST"
    [ "$(git symbolic-ref --short HEAD)" = "main" ]
    refute git rev-parse --verify --quiet HEAD
    git diff --cached --name-only | grep -qx 'pyproject.toml'
    [ "$(git status --porcelain --untracked-files=all | grep -cv '^A ')" -eq 0 ]
}

@test "the lock is already in uv's canonical form" {
    run "$INIT" "$DEST" my_pkg --ref HEAD
    [ "$status" -eq 0 ]
    cd "$DEST"
    uv lock --quiet
    git diff --exit-code -- uv.lock
}

@test "--library leaves out the CLI" {
    run "$INIT" "$DEST" my_lib --library --ref HEAD
    [ "$status" -eq 0 ]
    assert_no_leftovers
    [ -f "$DEST/src/my_lib/__init__.py" ]
    [ ! -e "$DEST/src/my_lib/cli.py" ]
    [ ! -e "$DEST/src/my_lib/__main__.py" ]
    [ ! -e "$DEST/tests/test_cli.py" ]
    refute grep -q 'project.scripts' "$DEST/pyproject.toml"
    refute grep -q -- '--help' "$DEST/justfile"
    refute grep -q '## Usage' "$DEST/README.md"
}

@test "--no-publish leaves out the release workflow" {
    run "$INIT" "$DEST" my_pkg --no-publish --ref HEAD
    [ "$status" -eq 0 ]
    assert_no_leftovers
    [ ! -e "$DEST/.github/workflows/release.yml" ]
    refute grep -q 'release-check' "$DEST/justfile"
    refute grep -q 'PyPI' "$DEST/README.md"
    grep -q '^release bump:' "$DEST/justfile"
}

@test "custom distribution and command names are kept separate" {
    run "$INIT" "$DEST" my_pkg --distribution my-dist --command my-tool --ref HEAD
    [ "$status" -eq 0 ]
    assert_no_leftovers
    grep -qx 'name = "my-dist"' "$DEST/pyproject.toml"
    grep -qx 'my-tool = "my_pkg.cli:main"' "$DEST/pyproject.toml"
    grep -q 'prog="my-tool"' "$DEST/src/my_pkg/cli.py"
    grep -q 'version("my-dist")' "$DEST/src/my_pkg/__init__.py"
    grep -q 'pypi.org/p/my-dist' "$DEST/.github/workflows/release.yml"
}
