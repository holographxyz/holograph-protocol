#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# generate_abis.sh – Extracts all contract ABIs from Foundry build artifacts
# ----------------------------------------------------------------------------
# 1. Ensures the project is built (forge build should be run beforehand)
# 2. Creates/clears the ./abis directory
# 3. Iterates over every JSON artifact in ./out and writes its .abi portion
#    to a standalone file inside ./abis with the same base filename.
# ----------------------------------------------------------------------------
set -euo pipefail

ARTIFACT_DIR="out"
ABI_DIR="abis"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required but not installed. Please install jq and retry." >&2
  exit 1
fi

# Ensure ABIs directory exists
mkdir -p "$ABI_DIR"

# Clear existing ABIs (optional; comment out if you want incremental)
rm -f "$ABI_DIR"/*.json || true

# Extract ABIs for contracts whose source files are under ./src
find "$ARTIFACT_DIR" -type f -name "*.json" | while read -r artifact; do
  # Keep artifacts that have an ABI and whose compilation target file is under ./src
  if jq -e 'has("abi") and (try (.metadata.settings.compilationTarget | keys[] | startswith("src/")) catch false)' "$artifact" >/dev/null 2>&1; then
    base=$(basename "$artifact")
    jq '.abi' "$artifact" > "$ABI_DIR/${base%.json}.json"
  fi
done

echo "✅ ABIs written to $ABI_DIR (total $(ls -1 "$ABI_DIR" | wc -l) files)" 