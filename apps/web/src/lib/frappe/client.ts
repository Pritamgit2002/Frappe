import "server-only";

import { env } from "@/lib/env";

const REQUEST_TIMEOUT_MS = 10_000;

export class FrappeError extends Error {
  readonly status: number;
  readonly excType?: string;

  constructor(message: string, status: number, excType?: string) {
    super(message);
    this.name = "FrappeError";
    this.status = status;
    this.excType = excType;
  }
}

type QueryValue = string | number | boolean | null | undefined | object;

export interface FrappeRequest {
  method?: "GET" | "POST" | "PUT" | "DELETE";
  query?: Record<string, QueryValue>;
  body?: unknown;
  /** Frappe session id, sent as the `sid` cookie. Omit for anonymous calls (login, ping). */
  sid?: string | null;
}

function buildUrl(path: string, query: FrappeRequest["query"]): URL {
  const url = new URL(path, env.FRAPPE_URL);
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value === undefined || value === null) continue;
    // Frappe wants lists and objects (fields, filters, ...) JSON-encoded in the query string.
    url.searchParams.set(key, typeof value === "object" ? JSON.stringify(value) : String(value));
  }
  return url;
}

/**
 * Low-level call to Frappe. Returns the Response untouched so callers can read headers
 * (login needs Set-Cookie). Only network-level failures throw here.
 */
export async function frappeFetch(path: string, req: FrappeRequest = {}): Promise<Response> {
  const headers = new Headers({ Accept: "application/json" });
  if (req.body !== undefined) headers.set("Content-Type", "application/json");
  if (req.sid) headers.set("Cookie", `sid=${req.sid}`);
  if (env.FRAPPE_SITE_NAME) headers.set("X-Frappe-Site-Name", env.FRAPPE_SITE_NAME);

  try {
    return await fetch(buildUrl(path, req.query), {
      method: req.method ?? "GET",
      headers,
      body: req.body === undefined ? undefined : JSON.stringify(req.body),
      cache: "no-store",
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch {
    throw new FrappeError(
      `Cannot reach the Frappe backend at ${env.FRAPPE_URL}. Is it running? (npm run dev:api)`,
      503,
      "Unreachable",
    );
  }
}

interface FrappeErrorBody {
  message?: unknown;
  exc_type?: string;
  _server_messages?: string;
}

const stripTags = (html: string) => html.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();

/** Turn a non-2xx Frappe response into a FrappeError carrying Frappe's own user-facing message. */
export async function toFrappeError(res: Response): Promise<FrappeError> {
  let body: FrappeErrorBody = {};
  try {
    body = await res.json();
  } catch {
    // Not JSON (e.g. an HTML error page from a proxy): fall back to the status line below.
  }

  let message: string | undefined;
  if (body._server_messages) {
    try {
      // A JSON string holding a list of JSON strings: '["{\"message\": \"...\"}"]'
      const parts = (JSON.parse(body._server_messages) as string[])
        .map((raw) => (JSON.parse(raw) as { message?: string }).message)
        .filter((part): part is string => Boolean(part));
      if (parts.length > 0) message = stripTags(parts.join(" "));
    } catch {
      // Malformed _server_messages: use `message` instead.
    }
  }
  if (!message && typeof body.message === "string") message = stripTags(body.message);

  return new FrappeError(message || `Frappe responded with HTTP ${res.status}.`, res.status, body.exc_type);
}

/** Call Frappe and return the parsed JSON body ({ data } for /api/resource, { message } for /api/method). */
export async function frappeJson<T>(path: string, req: FrappeRequest = {}): Promise<T> {
  const res = await frappeFetch(path, req);
  if (!res.ok) throw await toFrappeError(res);

  try {
    return (await res.json()) as T;
  } catch {
    throw new FrappeError(`Unexpected (non-JSON) response from Frappe for ${path}.`, 502);
  }
}
