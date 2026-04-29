#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "[check_gettext_sync] Running gettext extract+merge..."
mix gettext.extract --merge >/tmp/check_gettext_sync.log 2>&1 || {
  cat /tmp/check_gettext_sync.log
  echo "[check_gettext_sync] mix gettext.extract --merge failed"
  exit 1
}

echo "[check_gettext_sync] Checking gettext files are committed..."
if ! git diff --quiet -- priv/gettext/default.pot priv/gettext/en/LC_MESSAGES/default.po priv/gettext/zh/LC_MESSAGES/default.po priv/gettext/ja/LC_MESSAGES/default.po; then
  echo "[check_gettext_sync] Gettext files are out of sync."
  echo "[check_gettext_sync] Please run: mix gettext.extract --merge"
  echo "[check_gettext_sync] And commit changes under priv/gettext/."
  git --no-pager diff -- priv/gettext/default.pot priv/gettext/en/LC_MESSAGES/default.po priv/gettext/zh/LC_MESSAGES/default.po priv/gettext/ja/LC_MESSAGES/default.po || true
  exit 1
fi

echo "[check_gettext_sync] OK"
