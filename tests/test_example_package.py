"""Tests for the package metadata."""

import tomllib
from pathlib import Path

import example_package

PYPROJECT = Path(__file__).resolve().parent.parent / "pyproject.toml"


def test_version_matches_pyproject() -> None:
    project = tomllib.loads(PYPROJECT.read_text(encoding="utf-8"))["project"]
    assert example_package.__version__ == project["version"]
