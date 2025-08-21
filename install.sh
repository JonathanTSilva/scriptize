#!/usr/bin/env bash

set -euo pipefail

# Define destination for the helper script
BIN_DIR="/usr/local/bin"
UTIL_NAME="new-script"

# Check for root privileges
if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

echo "Starting installation..."

# --- Install Utility Script ---
echo "Installing '${UTIL_NAME}' utility to ${BIN_DIR}..."
# We need to know where the script-templates repo is to tell new-script where to find templates
# Let's find the absolute path of this install.sh script's directory
REPO_PATH="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create a configuration for our new-script utility
mkdir -p /etc/script-templates
echo "TEMPLATE_REPO_PATH=${REPO_PATH}" >/etc/script-templates/config

cp ./scriptize/utils/new-script "${BIN_DIR}/${UTIL_NAME}"
chmod 755 "${BIN_DIR}/${UTIL_NAME}"
echo "'${UTIL_NAME}' utility installed."

# --- Check for Recommended Dependencies ---
echo ""
echo "Checking for recommended tools..."
for cmd in shellcheck shfmt bats; do
    if ! command -v "${cmd}" &>/dev/null; then
        echo "WARNING: '${cmd}' is not installed. It is highly recommended for script development."
    else
        echo "✓ ${cmd} is installed."
    fi
done

echo -e "\nInstallation complete!"
echo "You can now create new scripts using: ${UTIL_NAME} <bash|python> <your_script_name>"
