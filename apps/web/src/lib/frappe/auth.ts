import "server-only";

import type { SessionUser } from "@/lib/types";
import { FrappeError, frappeFetch, frappeJson, toFrappeError } from "./client";

/** Log in via Frappe's session endpoint and return the session id (the value of Frappe's `sid` cookie). */
export async function login(usr: string, pwd: string): Promise<string> {
  const res = await frappeFetch("/api/method/login", { method: "POST", body: { usr, pwd } });
  if (!res.ok) throw await toFrappeError(res);

  const body = (await res.json().catch(() => ({}))) as { verification?: unknown; tmp_id?: string };
  if (body.verification || body.tmp_id) {
    throw new FrappeError("This account uses two-factor authentication, which this app doesn't support yet.", 501);
  }

  const sid = res.headers
    .getSetCookie()
    .map((cookie) => cookie.split(";")[0].trim())
    .find((cookie) => cookie.startsWith("sid="))
    ?.slice("sid=".length);
  if (!sid || sid === "Guest") {
    throw new FrappeError("Frappe accepted the login but did not return a session.", 502);
  }
  return sid;
}

export async function logout(sid: string): Promise<void> {
  try {
    await frappeFetch("/api/method/logout", { method: "POST", sid });
  } catch {
    // Best effort: the caller clears the local cookie either way.
  }
}

/**
 * Resolve a session id to a user. Returns null when the session is missing, expired or invalid
 * (Frappe then treats the request as Guest). Throws FrappeError if Frappe can't be reached.
 */
export async function whoAmI(sid: string): Promise<SessionUser | null> {
  // For a guest the method returns None, and Frappe then leaves `message` out of the response entirely.
  const { message } = await frappeJson<{ message?: SessionUser | null }>("/api/method/todo_app.api.me", { sid });
  return message ?? null;
}
