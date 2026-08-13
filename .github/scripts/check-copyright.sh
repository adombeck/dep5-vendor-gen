#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Checks whether a committed debian/copyright file is up to date with what
# dep5-vendor-gen would generate from the current vendor tree(s).
#
# Inputs (environment variables, all set by action.yml):
#   COPYRIGHT_FILE     Path to the debian/copyright file to check.
#   WORKING_DIRECTORY  Directory to resolve COPYRIGHT_FILE and vendor dirs from.
#   VENDOR_DIRS        Space-separated vendor directories (may be empty to
#                       let dep5-vendor-gen auto-detect ./vendor*).
#   FAIL_ON_DIFF       "true"/"false" - whether to exit non-zero on a diff.
#   DEBUG              "true"/"false" - whether to pass --debug through.
#   DEP5_VENDOR_GEN    Path to the dep5-vendor-gen executable.
#
# Outputs (written to $GITHUB_OUTPUT):
#   up-to-date   "true" or "false"
#   diff         The unified diff (empty when up to date)

set -euo pipefail

COPYRIGHT_FILE="${COPYRIGHT_FILE:-debian/copyright}"
WORKING_DIRECTORY="${WORKING_DIRECTORY:-.}"
VENDOR_DIRS="${VENDOR_DIRS:-}"
FAIL_ON_DIFF="${FAIL_ON_DIFF:-true}"
DEBUG="${DEBUG:-false}"
DEP5_VENDOR_GEN="${DEP5_VENDOR_GEN:?DEP5_VENDOR_GEN must be set}"

cd "$WORKING_DIRECTORY"

debug_args=()
if [[ "$DEBUG" == "true" ]]; then
  debug_args+=(--debug)
fi

vendor_args=()
if [[ -n "$VENDOR_DIRS" ]]; then
  # shellcheck disable=SC2206 # intentional word-splitting of space-separated dirs
  vendor_args=($VENDOR_DIRS)
fi

tmp_copyright="$(mktemp)"
trap 'rm -f "$tmp_copyright"' EXIT

if [[ -f "$COPYRIGHT_FILE" ]]; then
  cp "$COPYRIGHT_FILE" "$tmp_copyright"
else
  echo "::warning::$COPYRIGHT_FILE does not exist yet; a fresh file will be generated for comparison"
  : > "$tmp_copyright"
fi

echo "Running dep5-vendor-gen against ${VENDOR_DIRS:-<auto-detected vendor dirs>}..."
"$DEP5_VENDOR_GEN" "${debug_args[@]}" --debian-copyright "$tmp_copyright" "${vendor_args[@]}"

diff_output=""
up_to_date=true
if [[ -f "$COPYRIGHT_FILE" ]]; then
  if ! diff_output="$(diff -u "$COPYRIGHT_FILE" "$tmp_copyright")"; then
    up_to_date=false
  fi
else
  # File did not exist before: everything generated is "new" from the diff's
  # point of view.
  diff_output="$(diff -u /dev/null "$tmp_copyright" || true)"
  up_to_date=false
fi

{
  echo "up-to-date=$up_to_date"
} >> "$GITHUB_OUTPUT"

{
  echo "diff<<DEP5_VENDOR_GEN_DIFF_EOF"
  echo "$diff_output"
  echo "DEP5_VENDOR_GEN_DIFF_EOF"
} >> "$GITHUB_OUTPUT"

if [[ "$up_to_date" == "true" ]]; then
  echo "✅ $COPYRIGHT_FILE is up to date." | tee -a "$GITHUB_STEP_SUMMARY"
  exit 0
fi

{
  echo "## ❌ $COPYRIGHT_FILE is out of date"
  echo
  echo "Run \`dep5-vendor-gen ${VENDOR_DIRS}\` and commit the result."
  echo
  echo '```diff'
  echo "$diff_output"
  echo '```'
} >> "$GITHUB_STEP_SUMMARY"

echo "::error file=${COPYRIGHT_FILE}::${COPYRIGHT_FILE} is out of date with the vendored dependencies. Run dep5-vendor-gen and commit the result."
echo "$diff_output"

if [[ "$FAIL_ON_DIFF" == "true" ]]; then
  exit 1
fi

exit 0
