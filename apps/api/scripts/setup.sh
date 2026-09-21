#!/usr/bin/env bash
# One-time (and safely re-runnable) backend setup:
#   bench init -> link todo_app -> create site -> install app -> demo user
# Run from the repo root:  npm run setup:api
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
init_env

# First run: create .env with generated passwords and the MariaDB admin account bench needs.
# Both are no-ops when already in place, and never overwrite values you set yourself.
ensure_env_file
ensure_db_admin

bash "$SCRIPTS_DIR/doctor.sh"

# `bench` must run inside the bench directory.
in_bench() { ( cd "$BENCH_DIR" && "$@" ); }

# --- 1. bench + Frappe ------------------------------------------------------------------------------
if [[ -d "$BENCH_DIR/apps/frappe" ]]; then
  info "Bench already initialised at apps/api/bench, skipping bench init"
else
  if [[ -e "$BENCH_DIR" ]]; then
    die "apps/api/bench exists but isn't a complete bench (a previous init failed?). Delete it and re-run: rm -rf apps/api/bench"
  fi
  info "Creating bench with Frappe $FRAPPE_BRANCH (clones Frappe, builds assets: takes a few minutes)"
  # --no-backups: don't touch this machine's crontab.
  ( cd "$API_DIR" && bench init bench --frappe-branch "$FRAPPE_BRANCH" --python "$(pick_python)" --no-backups )
fi

# --- 2. link todo_app into the bench ----------------------------------------------------------------
# `bench get-app <path>` insists that the app is its own git repo, which doesn't fit a monorepo.
# So do what get-app does ourselves: symlink into apps/, editable-install into the bench env, list in apps.txt.
if [[ -L "$BENCH_DIR/apps/$APP_NAME" || -e "$BENCH_DIR/apps/$APP_NAME" ]]; then
  info "$APP_NAME already linked into the bench"
else
  info "Linking $APP_NAME into the bench"
  ln -s "$APP_SRC" "$BENCH_DIR/apps/$APP_NAME"
fi

info "Installing $APP_NAME (editable) into the bench Python env"
uv pip install --quiet -e "$BENCH_DIR/apps/$APP_NAME" --python "$BENCH_DIR/env/bin/python"

APPS_TXT="$BENCH_DIR/sites/apps.txt"
if ! grep -qx "$APP_NAME" "$APPS_TXT"; then
  info "Registering $APP_NAME in sites/apps.txt"
  # apps.txt may lack a trailing newline; don't glue our entry onto the last app's name.
  if [[ -n "$(tail -c1 "$APPS_TXT")" ]]; then echo >> "$APPS_TXT"; fi
  echo "$APP_NAME" >> "$APPS_TXT"
fi

# --- 3. site + app ----------------------------------------------------------------------------------
if [[ -d "$BENCH_DIR/sites/$FRAPPE_SITE_NAME" ]]; then
  info "Site $FRAPPE_SITE_NAME already exists, skipping new-site"
else
  info "Creating site $FRAPPE_SITE_NAME (MariaDB database + user)"
  in_bench bench new-site "$FRAPPE_SITE_NAME" \
    --db-root-username "$MARIADB_ROOT_USERNAME" \
    --db-root-password "$MARIADB_ROOT_PASSWORD" \
    --admin-password "$FRAPPE_ADMIN_PASSWORD"
fi

info "Installing $APP_NAME on $FRAPPE_SITE_NAME"
in_bench bench --site "$FRAPPE_SITE_NAME" install-app "$APP_NAME"   # no-op if already installed

info "Pinning $FRAPPE_SITE_NAME as the default site and enabling developer mode"
in_bench bench use "$FRAPPE_SITE_NAME"
in_bench bench set-config -g developer_mode 1

info "Migrating (syncs DocType changes)"
in_bench bench --site "$FRAPPE_SITE_NAME" migrate

# --- 4. demo user -----------------------------------------------------------------------------------
if [[ -n "${DEMO_USER_EMAIL:-}" && -n "${DEMO_USER_PASSWORD:-}" ]]; then
  info "Creating demo user $DEMO_USER_EMAIL"
  # Credentials travel via the environment (exported by load_env), not the command line.
  in_bench bench --site "$FRAPPE_SITE_NAME" execute "$APP_NAME.install.create_demo_user"
else
  warn "DEMO_USER_EMAIL / DEMO_USER_PASSWORD not set in .env, skipping the demo user (Administrator still works)"
fi

cat <<EOF

${C_GREEN}✔ Backend ready.${C_RESET}
  Start everything:   npm run dev
  Frappe desk:        http://127.0.0.1:8000/app   (user: Administrator)
  REST API:           http://127.0.0.1:8000/api/resource/Todo%20Item
  Web app:            http://localhost:3000
EOF
