### Todo App

The Frappe app behind the `frappe-todo` monorepo. It lives in the monorepo (not in its own git repo) and is
symlinked into the bench by `apps/api/scripts/setup.sh`.

| What | Where |
| --- | --- |
| DocType `Todo Item` (fields, permissions) | `todo_app/todo/doctype/todo_item/todo_item.json` |
| Validation / business rules | `todo_app/todo/doctype/todo_item/todo_item.py` |
| Custom REST methods (`/api/method/todo_app.api.*`) | `todo_app/api.py` |
| `Todo User` role + demo user | `todo_app/install.py` |
| Tests | `todo_app/todo/doctype/todo_item/test_todo_item.py` |

Frappe already exposes CRUD for every DocType at `/api/resource/<DocType>`; `api.py` only adds what the
generic API can't do cheaply (a session check and per-status counts).

Editing the DocType JSON by hand? Bump its `modified` timestamp, otherwise `bench migrate` sees nothing new.
Editing it from the desk with `developer_mode` on (setup enables it) writes the JSON for you.

Run the tests from the repo root: `npm run test:api`.
