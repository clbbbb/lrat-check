#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

moon run "$root/cmd/main" -- "$root/examples/paper.cnf" "$root/examples/paper.lrat"
if moon run "$root/cmd/main" -- "$root/examples/paper.cnf" "$root/examples/bad.lrat"; then
  echo "MoonBit checker unexpectedly accepted examples/bad.lrat" >&2
  exit 1
fi

# Pin drat-trim to an immutable upstream commit so CI checks are reproducible.
reference_commit=2e3b2dc0ecf938addbd779d42877b6ed69d9a985
source_url="https://raw.githubusercontent.com/marijnheule/drat-trim/${reference_commit}/lrat-check.c"

curl --fail --silent --show-error --location "$source_url" --output "$tmp/lrat-check.c"
gcc -std=c99 -DLONGTYPE -O2 "$tmp/lrat-check.c" -o "$tmp/lrat-check"

"$tmp/lrat-check" "$root/examples/paper.cnf" "$root/examples/paper.lrat"

if "$tmp/lrat-check" "$root/examples/paper.cnf" "$root/examples/bad.lrat"; then
  echo "Reference checker unexpectedly accepted examples/bad.lrat" >&2
  exit 1
fi

echo "Independent LRAT cross-check passed (valid proof accepted; invalid proof rejected)."
