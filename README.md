# scriptize

➕ Improve maintainability, readability, and efficiency of your scripts by standardize your scripting environment .

## Requirements

### On Debian/Ubuntu

```bash
sudo apt update
sudo apt install shellcheck bats shell-format
```

### On Fedora

```bash
sudo dnf install ShellCheck bats shfmt
```

### On macOS (using Homebrew)

```bash
brew install shellcheck bats shfmt
```

## How to use

1. Clone the Repo: git clone <your-repo-url> script-templates
2. Run Installer: `cd script-templates && sudo ./install.sh`
3. Create a New Script:
   - `new-script bash my-awesome-tool`: This creates `./my-awesome-tool.sh`, makes it executable, and you're ready to add your logic.
   - `new-script python my-data-processor`: This creates `./my-data-processor.py` for your Python project.

## If keep .pre-commit-config.yaml

### Install pre-commit (once per system)

```bash
pip install pre-commit
```

### Install the hooks into your git repo (run inside the repo)

```bash
pre-commit install
```