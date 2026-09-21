#!/usr/bin/env bash
# Starts the Frappe dev processes: web server (:8000), two Redis instances, socketio, scheduler, worker.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
init_env
require_bench

cd "$BENCH_DIR"
# PORT in .env is the Next.js port; keep it out of the Frappe processes' environment.
unset PORT
# watch=0: this app ships no JS/CSS assets, so skip the asset watcher (it's the heaviest process).
exec bench start -c watch=0
