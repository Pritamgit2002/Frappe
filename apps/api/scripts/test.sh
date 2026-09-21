#!/usr/bin/env bash
# Run the todo_app tests against the dev site. Extra args are passed to `bench run-tests`,
# e.g.  npm run test:api -- --doctype "Todo Item"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
init_env
require_bench

cd "$BENCH_DIR"
bench --site "$FRAPPE_SITE_NAME" set-config allow_tests true
bench --site "$FRAPPE_SITE_NAME" run-tests --app "$APP_NAME" "$@"
