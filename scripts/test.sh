#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
v="${1:?Specify Lua version 5.1 or 5.4}"
for f in AutoEnchanter/*.lua tests/*.lua; do "luac$v" -p "$f"; done
"lua$v" tests/regression.lua
"lua$v" tests/group.lua
