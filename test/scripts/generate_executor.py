"""Generates the executor.json metadata file for local Allure reports."""

import json
import time
from pathlib import Path


def create_local_executor() -> None:
    """Creates the executor.json for a local Allure run."""
    results_dir = Path("test/allure-results")
    if not results_dir.is_dir():
        # This print is fine for a helper script.
        print("Allure results directory not found, skipping executor.json creation.")  # noqa: T201
        return

    executor_file = results_dir / "executor.json"
    data = {
        "name": "Local Build",
        "buildName": f"Run @ {time.strftime('%Y-%m-%d %H:%M:%S')}",
        "type": "local",
    }

    with executor_file.open("w") as f:
        json.dump(data, f)


if __name__ == "__main__":
    create_local_executor()
