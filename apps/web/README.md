# @todo/web

The Next.js 16 frontend (App Router, TypeScript, Tailwind). It is part of the `frappe-todo` monorepo: setup, environment variables and scripts are documented in the [root README](../../README.md).

```
src/app/            pages, Server Functions (actions/), GET /api/health
src/components/     todo form, todo row, status tabs
src/lib/frappe/     typed client for Frappe's REST API (server-only)
src/lib/session.ts  session cookie + verifySession() guard
```

Run it from the repo root (`npm run dev:web`) so the root `.env` is loaded.
