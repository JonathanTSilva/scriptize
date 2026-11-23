# ruff: noqa: S101
"""Replay the atheris seed corpus through the fuzz targets, without atheris installed."""

from pathlib import Path

import pytest
from fuzz_strings import fuzz_one

CORPUS = Path(__file__).resolve().parent.parent / "fuzz" / "corpus" / "strings"
SEEDS = sorted(CORPUS.iterdir())


def test_corpus_is_not_empty() -> None:
    """A missing corpus would make the replay below pass vacuously."""
    assert SEEDS


@pytest.mark.parametrize("seed", SEEDS, ids=lambda p: p.name)
def test_strings_seed(seed: Path) -> None:
    """Every seed runs through the strings helpers without an unexpected exception."""
    fuzz_one(seed.read_bytes())
