"""Command-line interface for example-package."""

import argparse
from collections.abc import Sequence

from example_package import __version__


def build_parser() -> argparse.ArgumentParser:
    """Build the argument parser for example-command."""
    parser = argparse.ArgumentParser(
        prog="example-command",
        description="A short description of example-command.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """Run example-command and return its exit status."""
    build_parser().parse_args(argv)
    return 0
