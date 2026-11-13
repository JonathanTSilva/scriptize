# scriptize

➕ Improve maintainability, readability, and efficiency of your scripts by standardize your scripting environment.

<!-- badges:start -->
[![Status](https://img.shields.io/badge/status-active-brightgreen?style=flat-square)](https://www.repostatus.org/#active)
[![CI](https://img.shields.io/github/actions/workflow/status/JonathanTSilva/scriptize/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/JonathanTSilva/scriptize/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/JonathanTSilva/scriptize/graph/badge.svg)](https://codecov.io/gh/JonathanTSilva/scriptize)
[![Quality](https://sonarcloud.io/api/project_badges/measure?project=JonathanTSilva_scriptize&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=JonathanTSilva_scriptize)
[![Scorecard](https://img.shields.io/ossf-scorecard/github.com/JonathanTSilva/scriptize?style=flat-square&label=scorecard)](https://scorecard.dev/viewer/?uri=github.com/JonathanTSilva/scriptize)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Codespaces](https://img.shields.io/badge/codespaces-open-181717?style=flat-square&logo=github)](https://codespaces.new/JonathanTSilva/scriptize)
<!-- badges:end -->

## What it is

scriptize is a set of templates and utilities for Bash and Python scripts, plus a `new-script` helper that scaffolds a new script from them. The Bash utilities come with `shdoc` generated API docs and bats tests.

## Quick start

Install the tools the Bash templates and tests use.

On Debian/Ubuntu:

```bash
sudo apt update
sudo apt install shellcheck bats shell-format
```

On Fedora:

```bash
sudo dnf install ShellCheck bats shfmt
```

On macOS (using Homebrew):

```bash
brew install shellcheck bats shfmt
```

Then clone the repository and run the installer:

```bash
git clone https://github.com/JonathanTSilva/scriptize.git script-templates
cd script-templates && sudo ./install.sh
```

## Usage

Create a new script:

- `new-script bash my-awesome-tool` creates `./my-awesome-tool.sh`, makes it executable, and you are ready to add your logic.
- `new-script python my-data-processor` creates `./my-data-processor.py` for your Python project.

### Pre-commit hooks

If you keep `.pre-commit-config.yaml`, install pre-commit once per system and the hooks into your git repo (run inside the repo):

```bash
pip install pre-commit
pre-commit install
```

### Generating Bash docs

Run `shdoc` from the root of your repository without any installation. It behaves like the original shdoc.

Generate documentation for a single file:

```bash
./scriptize/utils/shdoc < ./bash/utilities/alerts.bash > docs/alerts_api.md
```

Generate a single documentation file for all utilities:

```bash
./scriptize/utils/shdoc < ./bash/utilities/*.bash > docs/BASH_API_REFERENCE.md
```

## Docs

- API reference: [`docs/`](docs/index.md), built with mkdocs.
- Test report: <https://jonathantsilva.github.io/scriptize/>

## Contributing

Read the [contribution guide](https://github.com/JonathanTSilva/.github/blob/main/CONTRIBUTING.md) first. To work on the Python code:

```bash
uv sync
uv run pytest
```

The Bash utilities are tested with bats, see [`.github/workflows/shell.yml`](.github/workflows/shell.yml) for how the tests are staged.

## License

[MIT](LICENSE)
