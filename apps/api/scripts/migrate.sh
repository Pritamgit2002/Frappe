#!/usr/bin/env bash
# Sync DocType JSON / patches to the site's database. Run after pulling backend changes.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
init_env
require_bench

start_bench_redis
cd "$BENCH_DIR"
bench --site "$FRAPPE_SITE_NAME" migrate
