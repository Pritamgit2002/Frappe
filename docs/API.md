# REST API

The backend's API is [Frappe's built-in REST API](https://docs.frappe.io/framework/user/en/api/rest). Every DocType gets CRUD endpoints for free; `todo_app` adds two small methods.

- Base URL (dev): `http://127.0.0.1:8000`
- DocType: `Todo Item` (URL-encode the space: `Todo%20Item`)
- Bodies and responses are JSON. Successful responses are `{"data": …}` (resources) or `{"message": …}` (methods).

## Authentication

Two ways to call the API. Both act as a specific Frappe user, and Frappe's permissions apply to them.

**Session cookie** is what the web app uses (server-side). `POST /api/method/login` returns a `sid` cookie; send it back on later calls.

```bash
BASE=http://127.0.0.1:8000
curl -s -c cookies.txt -X POST "$BASE/api/method/login" \
  -H 'Content-Type: application/json' \
  -d '{"usr":"demo@example.com","pwd":"<password>"}'
# {"message":"Logged In","home_page":"/app","full_name":"Demo User"}
```

**API token** is better for scripts: no login step, no cookie. Send `Authorization: token <api_key>:<api_secret>`. Generate a pair as a System Manager, in the desk under User → *API Access* → *Generate Keys*, or:

```bash
cd apps/api/bench
bench --site todo.localhost execute frappe.core.doctype.user.user.generate_keys --kwargs "{'user': 'demo@example.com'}"
```

> Cookie sessions and CSRF: Frappe only enforces a CSRF token on a session once a Frappe-rendered page (like the desk) has been opened with it. A session created by `curl` never is, so the examples below work. If you reuse a `sid` from a browser that has the desk open, POST/PUT/DELETE need an `X-Frappe-CSRF-Token` header. Token auth avoids all of this.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/method/login` | Log in (`usr`, `pwd`); sets `sid` |
| `POST` | `/api/method/logout` | End the session |
| `GET` | `/api/method/todo_app.api.me` | `{"user","full_name"}`, or `null` for a guest / expired session |
| `GET` | `/api/method/todo_app.api.stats` | Counts per status for the current user |
| `GET` | `/api/resource/Todo%20Item` | List (filters, fields, ordering, paging below) |
| `POST` | `/api/resource/Todo%20Item` | Create |
| `GET` | `/api/resource/Todo%20Item/{name}` | Read one |
| `PUT` | `/api/resource/Todo%20Item/{name}` | Update: only the fields you send change |
| `DELETE` | `/api/resource/Todo%20Item/{name}` | Delete |
| `GET` | `/api/method/ping` | Liveness (`{"message":"pong"}`), no auth |

### The `Todo Item` document

| Field | Type | Notes |
| --- | --- | --- |
| `name` | string | `TODO-00001`, assigned by Frappe |
| `title` | string | required; trimmed; blank is rejected |
| `description` | string \| null | |
| `status` | `Open` \| `In Progress` \| `Done` | default `Open` |
| `priority` | `Low` \| `Medium` \| `High` | default `Medium` |
| `due_date` | `YYYY-MM-DD` \| null | |
| `completed_at` | datetime \| null | read-only: set when `status` becomes `Done`, cleared when reopened |
| `owner`, `creation`, `modified` | | maintained by Frappe |

Permissions: role **Todo User** can create, read, write and delete only documents it owns (`if_owner`); **System Manager** has full access.

## Examples

```bash
# Create
curl -s -b cookies.txt -X POST "$BASE/api/resource/Todo%20Item" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Write docs","priority":"High","due_date":"2026-10-01"}'
# {"data":{"name":"TODO-00001","title":"Write docs","status":"Open","priority":"High", …}}

# List open items, newest first
curl -s -G -b cookies.txt "$BASE/api/resource/Todo%20Item" \
  --data-urlencode 'fields=["name","title","status","priority","due_date"]' \
  --data-urlencode 'filters=[["status","=","Open"]]' \
  --data-urlencode 'order_by=creation desc' \
  --data-urlencode 'limit_page_length=20'
# {"data":[{"name":"TODO-00001","title":"Write docs", …}]}

# Mark done
curl -s -b cookies.txt -X PUT "$BASE/api/resource/Todo%20Item/TODO-00001" \
  -H 'Content-Type: application/json' -d '{"status":"Done"}'

# Delete
curl -s -b cookies.txt -X DELETE "$BASE/api/resource/Todo%20Item/TODO-00001"
# {"message":"ok"}

# Counts
curl -s -b cookies.txt "$BASE/api/method/todo_app.api.stats"
# {"message":{"Open":0,"In Progress":0,"Done":1,"total":1}}

# The same with a token instead of a cookie
curl -s "$BASE/api/resource/Todo%20Item" -H "Authorization: token <api_key>:<api_secret>"
```

### Query parameters for the list endpoint

| Parameter | Format | Example |
| --- | --- | --- |
| `fields` | JSON array | `["name","title"]` (default: just `name`) |
| `filters` | JSON array of `[field, operator, value]` | `[["status","=","Open"],["due_date","<","2026-10-01"]]` |
| `order_by` | `field asc\|desc` | `due_date asc` |
| `limit_start` | integer | `40` |
| `limit_page_length` | integer | `20` (Frappe's default; `0` returns everything) |

`fields` and `filters` are JSON inside the query string, so URL-encode them (`--data-urlencode` does it for curl).

## Errors

Failures return a non-2xx status and a body Frappe fills in:

```json
{
  "exc_type": "ValidationError",
  "exception": "frappe.exceptions.ValidationError: Title cannot be empty.",
  "_server_messages": "[\"{\\\"message\\\": \\\"Title cannot be empty.\\\", …}\"]"
}
```

`_server_messages` is a JSON string holding a list of JSON strings, each with a user-facing `message` (may contain HTML). The web app's client (`apps/web/src/lib/frappe/client.ts`) unwraps it.

| Status | Typical cause |
| --- | --- |
| `401` | Wrong username or password on login |
| `403` | Not logged in / expired session, or not permitted (e.g. someone else's todo) |
| `404` | No such document |
| `417` | Validation failed (blank title, invalid select value, …) |

## Web app endpoint

`GET http://localhost:3000/api/health` → `{"web":"up","frappe":"up"}` (HTTP 200) or `{"web":"up","frappe":"down"}` (HTTP 503). It probes Frappe's `/api/method/ping` from the Next.js server.
