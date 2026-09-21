import "server-only";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { cache } from "react";
import { whoAmI } from "@/lib/frappe/auth";
import type { SessionUser } from "@/lib/types";

// Frappe's session id lives in our own httpOnly cookie, so browser JavaScript never sees it.
// The name differs from Frappe's own `sid` on purpose: browsers share cookies across ports on
// localhost, so reusing `sid` would make the Frappe desk (:8000) and this app (:3000) overwrite
// each other's sessions.
export const SESSION_COOKIE = "todo_sid";

// The cookie only carries the sid. Frappe enforces the real (idle) expiry, and `verifySession`
// re-checks the sid against Frappe on every request.
const COOKIE_MAX_AGE_SECONDS = 60 * 60 * 24 * 7;

export async function readSid(): Promise<string | null> {
  return (await cookies()).get(SESSION_COOKIE)?.value ?? null;
}

/** Only callable from a Server Function or Route Handler (cookies are read-only while rendering). */
export async function saveSid(sid: string): Promise<void> {
  (await cookies()).set(SESSION_COOKIE, sid, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: COOKIE_MAX_AGE_SECONDS,
  });
}

export async function clearSid(): Promise<void> {
  (await cookies()).delete(SESSION_COOKIE);
}

export interface Session {
  sid: string;
  user: SessionUser;
}

/**
 * The current session, or null. Memoised per request. Throws FrappeError when Frappe is
 * unreachable, so an outage shows the error page instead of silently logging everyone out.
 */
export const getSession = cache(async (): Promise<Session | null> => {
  const sid = await readSid();
  if (!sid) return null;

  const user = await whoAmI(sid);
  return user ? { sid, user } : null;
});

/** Guard for pages and server functions: returns the session or redirects to /login. */
export async function verifySession(): Promise<Session> {
  const session = await getSession();
  if (!session) redirect("/login");
  return session;
}
