#!/usr/bin/env bash
# Smoke test for a running PerfectTemplate server.
#
#   Scripts/smoke-test.sh [base-url]          full API round trip (needs MySQL)
#   Scripts/smoke-test.sh --no-db [base-url]  health, pages, and 503 from /api/posts
#
# The base URL defaults to http://127.0.0.1:9191. Waits up to 60 seconds for /api/health.
set -euo pipefail

no_db=false
if [ "${1:-}" = "--no-db" ]; then no_db=true; shift; fi
base="${1:-http://127.0.0.1:9191}"

fail() { echo "FAIL: $*" >&2; exit 1; }

# request METHOD PATH [JSON-BODY] -> sets $status and $body
request() {
    local out
    if [ $# -ge 3 ]; then
        out=$(curl -sS -X "$1" -H 'Content-Type: application/json' --data "$3" -w '\n%{http_code}' "$base$2")
    else
        out=$(curl -sS -X "$1" -w '\n%{http_code}' "$base$2")
    fi
    status="${out##*$'\n'}"
    body="${out%$'\n'*}"
}

expect() { # expect STATUS [SUBSTRING] DESCRIPTION
    local want="$1" text="$2" what="$3"
    [ "$status" = "$want" ] || fail "$what: expected $want, got $status: $body"
    [ -z "$text" ] || [[ "$body" == *"$text"* ]] || fail "$what: body lacks '$text': $body"
    echo "ok   $what ($status)"
}

for _ in $(seq 1 60); do
    curl -sf "$base/api/health" > /dev/null 2>&1 && break
    sleep 1
done

request GET /api/health;  expect 200 '"status":"ok"' "GET /api/health"
request GET /;            expect 200 'PerfectTemplate' "GET /"
request GET /posts;       expect 200 'Posts' "GET /posts"
request GET /static/favicon.svg; expect 200 '<svg' "GET /static/favicon.svg"

if $no_db; then
    request GET /api/posts; expect 503 'Database unavailable' "GET /api/posts without MySQL"
    echo "smoke test passed (no database)"
    exit 0
fi

request POST /api/posts '{"title":"Smoke test","body":"Created by smoke-test.sh"}'
expect 201 '"title":"Smoke test"' "POST /api/posts"
id=$(sed -E 's/.*"id":"([0-9A-F-]{36})".*/\1/' <<< "$body")
[[ "$id" =~ ^[0-9A-F-]{36}$ ]] || fail "no id in: $body"

request GET /api/posts;           expect 200 "$id" "GET /api/posts lists the new post"
request GET "/api/posts/$id";     expect 200 '"body":"Created by smoke-test.sh"' "GET /api/posts/:id"
request PUT "/api/posts/$id" '{"title":"Smoke test, edited"}'
expect 200 '"title":"Smoke test, edited"' "PUT /api/posts/:id"
request POST /api/posts '{"title":"  ","body":"x"}'; expect 400 'Title' "POST with an empty title"
request DELETE "/api/posts/$id";  expect 200 "$id" "DELETE /api/posts/:id"
request GET "/api/posts/$id";     expect 404 '' "GET after DELETE"
request DELETE "/api/posts/$id";  expect 404 '' "DELETE again"
echo "smoke test passed"
