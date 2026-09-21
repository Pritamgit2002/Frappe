"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { login as frappeLogin, logout as frappeLogout } from "@/lib/frappe/auth";
import { FrappeError } from "@/lib/frappe/client";
import { clearSid, readSid, saveSid } from "@/lib/session";

export interface LoginState {
  error?: string;
  /** Echoed back so the field keeps its value after a failed attempt. */
  usr?: string;
}

const loginSchema = z.object({
  usr: z.string().trim().min(1, "Enter your email or username."),
  pwd: z.string().min(1, "Enter your password."),
});

export async function login(_previous: LoginState, formData: FormData): Promise<LoginState> {
  const usr = String(formData.get("usr") ?? "");

  const parsed = loginSchema.safeParse({ usr, pwd: formData.get("pwd") ?? "" });
  if (!parsed.success) return { error: parsed.error.issues[0]?.message, usr };

  try {
    await saveSid(await frappeLogin(parsed.data.usr, parsed.data.pwd));
  } catch (error) {
    return { error: describeLoginError(error), usr };
  }

  // redirect() works by throwing, so it must stay outside the try/catch above.
  redirect("/");
}

export async function logout(): Promise<void> {
  const sid = await readSid();
  if (sid) await frappeLogout(sid);
  await clearSid();
  redirect("/login");
}

function describeLoginError(error: unknown): string {
  if (error instanceof FrappeError) {
    return error.status === 401 ? "Invalid email or password." : error.message;
  }
  return "Something went wrong. Please try again.";
}
