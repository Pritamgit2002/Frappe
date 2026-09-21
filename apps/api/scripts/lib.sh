#!/usr/bin/env bash
# Shared helpers for apps/api/scripts/*. Source this file; don't run it.
# Written for macOS's stock bash 3.2: no associative arrays, mapfile or ${var,,}.

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
ROOT_DIR="$(cd "$API_DIR/../.." && pwd)"
BENCH_DIR="$API_DIR/bench"
APP_NAME="todo_app"
APP_SRC="$API_DIR/$APP_NAME"

if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; C_RESET=""
fi

info() { printf '%s==>%s %s\n' "$C_BOLD" "$C_RESET" "$*"; }
warn() { printf '%s!%s  %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%s✘%s  %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# Load ROOT/.env into the environment without overriding variables that are already set
# (so `FRAPPE_SITE_NAME=x npm run ...` still wins). Plain KEY=VALUE lines only.
load_env() {
  local file="$ROOT_DIR/.env" line key value
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*(#|$) ]]; then
      continue
    fi
    key="${line%%=*}"
    value="${line#*=}"
    key="${key//[[:space:]]/}"
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      continue
    fi
    value="${value#"${value%%[![:space:]]*}"}"   # trim leading whitespace, like dotenv does
    value="${value%"${value##*[![:space:]]}"}"   # ...and trailing
    value="${value%\"}"; value="${value#\"}"; value="${value%\'}"; value="${value#\'}"
    if [[ -z "${!key+x}" ]]; then
      export "$key=$value"
    fi
  done < "$file"
  return 0
}

# Tools that Homebrew/uv install outside the default PATH. Needs FRAPPE_BRANCH (see init_env).
extend_path() {
  local dir node_v
  for dir in \
    "$HOME/.local/bin" \
    /opt/homebrew/opt/mariadb@11.8/bin /opt/homebrew/opt/mariadb/bin \
    /usr/local/opt/mariadb@11.8/bin /usr/local/opt/mariadb/bin; do
    if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
      PATH="$dir:$PATH"
    fi
  done

  # `brew install node@24` is keg-only, so it never lands on PATH by itself. If the node you're
  # running is too old for this Frappe branch, use the Homebrew one for the backend scripts only
  # (your shell's node is left alone; Next.js runs fine on either).
  node_v="$(node --version 2>/dev/null | sed 's/^v//' || true)"
  if [[ -z "$node_v" ]] || ! version_ge "$node_v" "$(node_min)"; then
    for dir in /opt/homebrew/opt/node@24/bin /usr/local/opt/node@24/bin; do
      if [[ -x "$dir/node" ]]; then
        PATH="$dir:$PATH"
        break
      fi
    done
  fi
  export PATH
}

apply_defaults() {
  export FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-16}"
  export FRAPPE_SITE_NAME="${FRAPPE_SITE_NAME:-todo.localhost}"
  export MARIADB_ROOT_USERNAME="${MARIADB_ROOT_USERNAME:-root}"
}

init_env() {
  load_env
  apply_defaults   # before extend_path: it needs FRAPPE_BRANCH to know which node is required
  extend_path
}

# version_ge HAVE WANT -> success if HAVE >= WANT (dotted numbers, up to 3 components).
version_ge() {
  local have="$1" want="$2"
  local IFS=.
  local h1 h2 h3 w1 w2 w3
  set -- $have
  h1="${1:-0}"; h2="${2:-0}"; h3="${3:-0}"
  set -- $want
  w1="${1:-0}"; w2="${2:-0}"; w3="${3:-0}"
  h1="${h1//[^0-9]/}"; h2="${h2//[^0-9]/}"; h3="${h3//[^0-9]/}"
  w1="${w1//[^0-9]/}"; w2="${w2//[^0-9]/}"; w3="${w3//[^0-9]/}"
  if (( ${h1:-0} != ${w1:-0} )); then (( ${h1:-0} > ${w1:-0} )); return; fi
  if (( ${h2:-0} != ${w2:-0} )); then (( ${h2:-0} > ${w2:-0} )); return; fi
  (( ${h3:-0} >= ${w3:-0} ))
}

# Minimum tool versions for the configured Frappe branch.
node_min()   { case "$FRAPPE_BRANCH" in version-15) echo "20.9";; *) echo "24";; esac; }
python_min() { case "$FRAPPE_BRANCH" in version-15) echo "3.10";; *) echo "3.14";; esac; }

# Path of the python that bench should build its env with.
pick_python() {
  if [[ -n "${PYTHON_BIN:-}" ]]; then
    echo "$PYTHON_BIN"
  elif command -v python3.14 >/dev/null 2>&1; then
    command -v python3.14
  else
    command -v python3
  fi
}

require_bench() {
  if [[ ! -d "$BENCH_DIR/apps/frappe" ]]; then
    die "Bench not set up yet. Run: npm run setup:api"
  fi
}
