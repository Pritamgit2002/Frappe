#!/usr/bin/env bash
# Preflight: verifies everything the backend needs and prints the exact fix for anything missing.
# Read-only, safe to run any time:  npm run doctor
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
init_env

FAILURES=0
pass() { printf '  %s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
miss() {
  printf '  %s✘%s %s\n' "$C_RED" "$C_RESET" "$1"
  if [[ -n "${2:-}" ]]; then printf '      fix: %s\n' "$2"; fi
  FAILURES=$((FAILURES + 1))
}
soft() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }

info "Environment (Frappe branch: $FRAPPE_BRANCH, site: $FRAPPE_SITE_NAME)"

# --- .env -------------------------------------------------------------------------------------------
if [[ -f "$ROOT_DIR/.env" ]]; then
  pass ".env found"
else
  miss ".env not found" "npm run setup:api creates it with generated passwords   (or: cp .env.example .env and fill it in)"
fi
for var in FRAPPE_ADMIN_PASSWORD MARIADB_ROOT_PASSWORD; do
  if [[ -n "${!var:-}" ]]; then
    pass "$var is set"
  else
    miss "$var is empty" "set it in .env, or leave it empty and npm run setup:api generates it"
  fi
done

# --- toolchain --------------------------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then pass "git $(git --version | awk '{print $3}')"; else miss "git not found" "xcode-select --install"; fi

if command -v node >/dev/null 2>&1; then
  node_v="$(node --version | sed 's/^v//')"
  if version_ge "$node_v" "$(node_min)"; then
    pass "node $node_v (need >= $(node_min))"
  else
    miss "node $node_v is too old (need >= $(node_min) for Frappe $FRAPPE_BRANCH)" \
      "nvm install 24 && nvm use 24    (or: brew install node@24)"
  fi
else
  miss "node not found" "nvm install 24    (or: brew install node@24)"
fi

if command -v yarn >/dev/null 2>&1; then
  yarn_v="$(yarn --version 2>/dev/null || echo 0)"
  if [[ "${yarn_v%%.*}" == "1" ]]; then
    pass "yarn $yarn_v"
  else
    miss "yarn $yarn_v found, but Frappe's build needs yarn 1.x" "npm install -g yarn"
  fi
else
  miss "yarn not found" "npm install -g yarn"
fi

PY="$(pick_python 2>/dev/null || true)"
if [[ -n "$PY" ]] && command -v "$PY" >/dev/null 2>&1; then
  py_v="$("$PY" -c 'import platform; print(platform.python_version())')"
  py_ok=1
  py_need=">= $(python_min)"
  version_ge "$py_v" "$(python_min)" || py_ok=0
  if [[ "$FRAPPE_BRANCH" != "version-15" ]]; then
    py_need="3.14.x"                       # v16+ pins requires-python to >=3.14,<3.15
    [[ "${py_v%.*}" == "3.14" ]] || py_ok=0
  fi
  if (( py_ok )); then
    pass "python $py_v ($PY)"
  else
    miss "python $py_v ($PY) does not match Frappe $FRAPPE_BRANCH (needs $py_need)" \
      "brew install python@3.14    (or: uv python install 3.14)"
  fi
else
  miss "python3 not found" "brew install python@3.14"
fi

if command -v uv >/dev/null 2>&1; then pass "uv $(uv --version | awk '{print $2}')"; else miss "uv not found" "brew install uv"; fi

if command -v bench >/dev/null 2>&1; then
  pass "bench $(bench --version 2>/dev/null | tail -1)"
else
  miss "bench (frappe-bench) not found" "uv tool install frappe-bench && uv tool update-shell   (then open a new shell)"
fi

if command -v pkg-config >/dev/null 2>&1; then pass "pkg-config"; else miss "pkg-config not found" "brew install pkg-config"; fi
if [[ "$(uname)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
  if brew list --versions mariadb-connector-c >/dev/null 2>&1; then
    pass "mariadb-connector-c (builds the mysqlclient driver)"
  else
    miss "mariadb-connector-c not installed" "brew install mariadb-connector-c"
  fi
fi

if command -v redis-server >/dev/null 2>&1; then
  pass "redis-server $(redis-server --version | sed -E 's/.*v=([0-9.]+).*/\1/')"
else
  miss "redis-server not found (bench launches its own Redis instances)" "brew install redis"
fi

# --- MariaDB ----------------------------------------------------------------------------------------
DB_CLIENT=""
for candidate in mariadb mysql; do
  if command -v "$candidate" >/dev/null 2>&1; then DB_CLIENT="$candidate"; break; fi
done

if [[ -z "$DB_CLIENT" ]]; then
  miss "MariaDB client not found" "brew install mariadb@11.8"
elif [[ -z "${MARIADB_ROOT_PASSWORD:-}" ]]; then
  soft "MariaDB client found, skipping the connection test until MARIADB_ROOT_PASSWORD is set"
else
  if db_v="$(MYSQL_PWD="$MARIADB_ROOT_PASSWORD" "$DB_CLIENT" -u "$MARIADB_ROOT_USERNAME" --batch --skip-column-names -e 'SELECT VERSION()' 2>/dev/null)"; then
    pass "MariaDB $db_v reachable as '$MARIADB_ROOT_USERNAME'"
    if [[ "$FRAPPE_BRANCH" != "version-15" ]] && ! version_ge "${db_v%%-*}" "11.8"; then
      soft "Frappe $FRAPPE_BRANCH is documented against MariaDB 11.8; you have ${db_v%%-*}"
    fi
  else
    miss "cannot log in to MariaDB as '$MARIADB_ROOT_USERNAME' with MARIADB_ROOT_PASSWORD" \
      "is MariaDB running?  brew services start mariadb@11.8
             Homebrew's 'root' only accepts the OS user root, so it can't log in with a password. Leave
             MARIADB_ROOT_PASSWORD empty and run npm run setup:api: it creates a '$MANAGED_DB_USER' admin
             login for you (or create your own admin account and put its login in .env)"
  fi
fi

# --- ports ------------------------------------------------------------------------------------------
if command -v lsof >/dev/null 2>&1; then
  if [[ -n "$(lsof -tiTCP:8000 -sTCP:LISTEN 2>/dev/null)" ]]; then
    soft "port 8000 is already in use (fine if that's this bench running)"
  else
    pass "port 8000 (Frappe) is free"
  fi
fi

echo
if (( FAILURES > 0 )); then
  die "$FAILURES problem(s) found. Fix them and re-run: npm run doctor"
fi
printf '%s✔ All checks passed.%s\n' "$C_GREEN" "$C_RESET"
