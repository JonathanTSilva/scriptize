# ruff: noqa: S101, INP001
"""Atheris fuzz target for the scriptize strings utilities.

Run (atheris is not a project dependency). libFuzzer writes new inputs into the corpus
directory it is given, so fuzz a scratch copy and keep `fuzz/corpus/` for hand-written seeds:

    cp -r fuzz/corpus/strings /tmp/strings-corpus
    uv run --with atheris python fuzz/fuzz_strings.py -runs=100000 /tmp/strings-corpus

The input is split on the first NUL byte into `text` and `pattern`. Every helper must accept
any text. The only documented exception is `re.error`, from an invalid user pattern in
`regex_match` and `regex_capture`. Anything else, or a broken round trip, is a crash.
"""

import re
import sys
from pathlib import Path

# `python fuzz/<file>.py` puts fuzz/ on sys.path, not the repo root.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scriptize.assets.python.utilities import strings

MAX_PATTERN = 24  # bound the regex so a hostile pattern cannot stall a run


def fuzz_one(data: bytes) -> None:
    """Exercise every strings helper with `data`; only `re.error` may escape."""
    raw_text, _, raw_pattern = data.partition(b"\x00")
    text = raw_text.decode("utf-8", errors="replace")
    pattern = raw_pattern.decode("utf-8", errors="replace")[:MAX_PATTERN]

    for func in (
        strings.trim,
        strings.ltrim,
        strings.rtrim,
        strings.strip_ansi,
        strings.clean_string,
        strings.to_lower,
        strings.to_upper,
        strings.encode_url,
        strings.decode_url,
        strings.encode_html,
        strings.decode_html,
    ):
        assert isinstance(func(text), str)

    # Round trips: encoding must be reversible for any text.
    assert strings.decode_url(strings.encode_url(text)) == text
    assert strings.decode_html(strings.encode_html(text)) == text
    # clean_string is a fixed point after one pass.
    cleaned = strings.clean_string(text)
    assert strings.clean_string(cleaned) == cleaned
    # A literal pattern agrees with the plain substring check.
    assert strings.regex_match(text, re.escape(pattern)) == strings.contains(text, pattern)

    try:
        matched = strings.regex_match(text, pattern)
        captured = strings.regex_capture(text, pattern)
    except re.error:
        return
    assert isinstance(matched, bool)
    assert isinstance(captured, list)
    assert matched == bool(re.search(pattern, text))


def main() -> None:
    """Instrument the target and hand control to libFuzzer."""
    import atheris  # noqa: PLC0415

    atheris.instrument_all()
    atheris.Setup(sys.argv, fuzz_one)
    atheris.Fuzz()


if __name__ == "__main__":
    main()
