#!/bin/sh
set -eu

stack_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
api_dir="$stack_dir/finance-api"
state_dir="$stack_dir/.local"
database="$state_dir/ios-tracker-dev.sqlite3"
snapshot="$state_dir/production-snapshot.sqlite3"

mkdir -p "$state_dir"
cd "$api_dir"
export DATABASE_URL="sqlite:///$database"
export ENVIRONMENT=local ENABLE_SCHEDULER=false ENABLE_REMOTE_DATA=false
export PERSONAL_API_TOKEN=dev-token-123

if [ ! -f "$database" ]; then
    if [ -f "$snapshot" ]; then
        sqlite3 -readonly "$snapshot" ".backup '$database'"
    else
        .venv/bin/python seed_local_performance_demo.py
    fi
fi

exec .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8017
