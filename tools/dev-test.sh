#!/bin/bash
# Runs an input script against the development build (cmake -DBCQ_DEV=ON) on a throw-away copy of a vault.
#   tools/dev-test.sh tools/drive/smoke.drv            # uses a generated fixture vault
#   VAULT=/path/to/vault tools/dev-test.sh script.drv   # or a copy of a real vault (boards copied, attachments linked)
# Nothing touches the real vault, the real preferences or the screen: events are posted straight to the window.
set -euo pipefail
cd "$(dirname "$0")/.."
SCRIPT="$1"; WORK="${TMPDIR:-/tmp}/bcq-test"; rm -rf "$WORK"; mkdir -p "$WORK/data"
if [ -n "${VAULT:-}" ]; then
  mkdir -p "$WORK/vault"; cp -R "$VAULT/boards" "$VAULT/vault.json" "$WORK/vault/"; ln -s "$VAULT/attachments" "$WORK/vault/attachments"
else
  python3 tools/make_fixture.py "$WORK/vault" >/dev/null
fi
sed "s#\$WORK#$WORK#g" "$SCRIPT" > "$WORK/script.drv"
BCQ_DATA_DIR="$WORK/data" BCQ_VAULT="$WORK/vault" BCQ_SKIP_LOCK=1 \
  "build/Brotherhood Canvas.app/Contents/MacOS/Brotherhood Canvas" --size "${SIZE:-1440x860}" --board "${BOARD:-}" --drive "$WORK/script.drv"
