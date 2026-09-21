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

# --- first-run bootstrap (used by setup.sh) -------------------------------------------------------

# Dedicated MariaDB admin that bench uses to create the site's database. Homebrew's own `root` only
# accepts the OS user `root` (unix_socket), so it can't be used with a password.
MANAGED_DB_USER="frappe_admin"

gen_secret() { openssl rand -base64 24 | tr -d '/+=\n' | cut -c1-24; }

# set_env_value KEY VALUE: edit ROOT/.env in place (append if missing) and export it for this run.
set_env_value() {
  local key="$1" value="$2" file="$ROOT_DIR/.env" tmp line found=0
  tmp="$(mktemp)"
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "${line%%=*}" == "$key" ]]; then
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
        found=1
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$file"
  fi
  if (( found == 0 )); then
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi
  cat "$tmp" > "$file"
  rm -f "$tmp"
  chmod 600 "$file"
  export "$key=$value"
}

# fill_secret KEY: give KEY a generated value if it is empty.
fill_secret() {
  if [[ -z "${!1:-}" ]]; then
    set_env_value "$1" "$(gen_secret)"
    info "Generated $1 (saved in .env)"
  fi
  return 0
}

# Create .env from the example on first run and fill in whatever would otherwise block setup.
# Existing non-empty values are never touched. DEMO_USER_PASSWORD is only generated for a brand-new .env,
# because leaving it empty is how you opt out of the demo user.
ensure_env_file() {
  local created=0
  if [[ ! -f "$ROOT_DIR/.env" ]]; then
    info "Creating .env from .env.example"
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
    chmod 600 "$ROOT_DIR/.env"
    created=1
    load_env
  fi

  fill_secret FRAPPE_ADMIN_PASSWORD
  if [[ -z "${MARIADB_ROOT_PASSWORD:-}" ]]; then
    set_env_value MARIADB_ROOT_USERNAME "$MANAGED_DB_USER"
    set_env_value MARIADB_ROOT_PASSWORD "$(gen_secret)"
    info "Generated a MariaDB admin login ($MANAGED_DB_USER, saved in .env)"
  fi
  if (( created )); then
    fill_secret DEMO_USER_PASSWORD
  fi
  return 0
}

db_client() { command -v mariadb || command -v mysql || true; }

# Escape a value for a single-quoted MariaDB string literal: \ becomes \\ and ' becomes ''.
# (sed, not ${var//x/y}: bash 3.2 and 5 disagree about backslashes in that replacement.)
sql_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/''/g"; }

# db_login_ok USER PASSWORD: can we log in over the default socket? (Password goes via env, not argv.)
db_login_ok() {
  local client
  client="$(db_client)"
  [[ -n "$client" ]] && MYSQL_PWD="$2" "$client" -u "$1" --batch --skip-column-names -e 'SELECT 1' >/dev/null 2>&1
}

# If .env points at the managed admin account and it can't log in yet, create it. This connects as
# your macOS user, which Homebrew's MariaDB makes an admin over the unix socket (no password, no sudo).
ensure_db_admin() {
  local client pw sql
  if [[ "$MARIADB_ROOT_USERNAME" != "$MANAGED_DB_USER" ]]; then
    return 0
  fi
  if db_login_ok "$MARIADB_ROOT_USERNAME" "$MARIADB_ROOT_PASSWORD"; then
    return 0
  fi

  client="$(db_client)"
  if [[ -z "$client" ]]; then
    die "MariaDB client not found. Run: npm run doctor"
  fi

  info "Creating MariaDB admin account '$MANAGED_DB_USER' (needs MariaDB running)"
  pw="$(sql_escape "$MARIADB_ROOT_PASSWORD")"
  sql="CREATE USER IF NOT EXISTS '$MANAGED_DB_USER'@'localhost' IDENTIFIED BY '$pw';
ALTER USER '$MANAGED_DB_USER'@'localhost' IDENTIFIED BY '$pw';
GRANT ALL PRIVILEGES ON *.* TO '$MANAGED_DB_USER'@'localhost' WITH GRANT OPTION;"

  # SQL goes over stdin so the password never appears in a process listing.
  if ! printf '%s\n' "$sql" | "$client" --batch 2>/dev/null; then
    die "Couldn't create the MariaDB account as your macOS user (is MariaDB running? brew services start mariadb@11.8).
    Do it by hand as MariaDB's OS-level root instead:
      sudo $client -u root -e \"CREATE USER '$MANAGED_DB_USER'@'localhost' IDENTIFIED BY '<password>'; GRANT ALL PRIVILEGES ON *.* TO '$MANAGED_DB_USER'@'localhost' WITH GRANT OPTION;\"
    and put the same password in .env as MARIADB_ROOT_PASSWORD."
  fi

  if ! db_login_ok "$MARIADB_ROOT_USERNAME" "$MARIADB_ROOT_PASSWORD"; then
    die "Created '$MANAGED_DB_USER' but still can't log in with it. Check MARIADB_ROOT_PASSWORD in .env."
  fi
  return 0
}

# --- Redis for one-off bench commands ------------------------------------------------------------

# `bench migrate`, `execute` and `run-tests` refuse to run without Redis, which `bench start` normally
# provides. Start bench's own instances if nothing is listening yet, and stop just those on exit.
BENCH_REDIS_PIDS=""

stop_bench_redis() {
  if [[ -n "$BENCH_REDIS_PIDS" ]]; then
    kill $BENCH_REDIS_PIDS 2>/dev/null || true
  fi
  return 0
}

start_bench_redis() {
  local name port i
  for name in redis_cache redis_queue; do
    port="$(awk '$1=="port"{print $2}' "$BENCH_DIR/config/$name.conf")"
    if redis-cli -p "$port" ping >/dev/null 2>&1; then
      continue   # already running (e.g. `npm run dev` is up)
    fi
    ( cd "$BENCH_DIR" && exec redis-server "config/$name.conf" ) >/dev/null 2>&1 &
    BENCH_REDIS_PIDS="$BENCH_REDIS_PIDS $!"
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      if redis-cli -p "$port" ping >/dev/null 2>&1; then break; fi
      sleep 0.5
    done
  done
  if [[ -n "$BENCH_REDIS_PIDS" ]]; then
    trap stop_bench_redis EXIT
  fi
  return 0
}
