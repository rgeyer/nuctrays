#!/usr/bin/env bash
# render.sh — Render a compose.yaml template into a deployable file by
# substituting all ${VAR} placeholders with values from a .env file.
#
# Usage:
#   ./render.sh <app>
#
# Examples:
#   ./render.sh traefik
#   ./render.sh blackpearl
#
# The rendered file is written to .rendered/<app>/compose.yaml and is
# gitignored. Paste its contents into the TrueNAS UI when deploying.
#
# Prerequisites:
#   - envsubst  (part of gettext; see README for install instructions)
#   - A filled-in .env file at truenas-ix-apps/<app>/.env
#     (copy from <app>/.env.example and fill in all values)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Argument validation ---

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <app>" >&2
  echo "  e.g. $0 traefik" >&2
  echo "  e.g. $0 blackpearl" >&2
  exit 1
fi

APP="$1"
TEMPLATE="$SCRIPT_DIR/$APP/compose.yaml"
ENV_FILE="$SCRIPT_DIR/$APP/.env"
OUTPUT_DIR="$SCRIPT_DIR/.rendered/$APP"
OUTPUT_FILE="$OUTPUT_DIR/compose.yaml"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Error: template not found: $TEMPLATE" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  # If there are no ${VAR} references in the template, a .env is not needed.
  # Check whether the template actually contains any substitution placeholders.
  if grep -qE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "$TEMPLATE"; then
    echo "Error: .env file not found: $ENV_FILE" >&2
    echo "Copy $SCRIPT_DIR/$APP/.env.example to $ENV_FILE and fill in all values." >&2
    exit 1
  else
    # No variables to substitute — render is a straight copy.
    mkdir -p "$OUTPUT_DIR"
    cp "$TEMPLATE" "$OUTPUT_FILE"
    echo "Rendered: $OUTPUT_FILE (no variable substitution needed)"
    echo ""
    echo "Next steps:"
    echo "  1. In TrueNAS: Apps → Discover Apps → Install via YAML (or edit existing app)"
    echo "  2. Paste the contents of $OUTPUT_FILE into the YAML editor."
    echo "  3. Click Save."
    exit 0
  fi
fi

# --- Load .env and check for unfilled values ---

# Export variables from the .env file, skipping comments and blank lines
set -o allexport
# shellcheck source=/dev/null
source "$ENV_FILE"
set +o allexport

# Warn about any variables that are still empty
EMPTY_VARS=()
while IFS= read -r line; do
  # Skip comments and blank lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// }" ]] && continue
  VAR_NAME="${line%%=*}"
  VAR_VALUE="${line#*=}"
  if [[ -z "$VAR_VALUE" ]]; then
    EMPTY_VARS+=("$VAR_NAME")
  fi
done < "$ENV_FILE"

if [[ ${#EMPTY_VARS[@]} -gt 0 ]]; then
  echo "Warning: the following variables in $ENV_FILE have no value:" >&2
  for v in "${EMPTY_VARS[@]}"; do
    echo "  $v" >&2
  done
  echo "The rendered file will contain empty substitutions for these." >&2
  echo ""
fi

# --- Render ---

mkdir -p "$OUTPUT_DIR"
envsubst < "$TEMPLATE" > "$OUTPUT_FILE"

echo "Rendered: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review the rendered file to confirm all values are correct."
echo "  2. In TrueNAS: Apps → Discover Apps → Install via YAML (or edit existing app)"
echo "  3. Paste the contents of $OUTPUT_FILE into the YAML editor."
echo "  4. Click Save."
