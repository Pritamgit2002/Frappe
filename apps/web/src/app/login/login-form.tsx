"use client";

import { useActionState } from "react";
import { type LoginState, login } from "@/app/actions/auth";

const inputClass =
  "w-full rounded-lg border border-neutral-300 bg-white px-3 py-2 text-sm outline-none focus:border-neutral-900 focus:ring-2 focus:ring-neutral-900/10 dark:border-neutral-700 dark:bg-neutral-900 dark:focus:border-neutral-300 dark:focus:ring-neutral-300/20";

export function LoginForm() {
  const [state, formAction, pending] = useActionState<LoginState, FormData>(login, {});

  return (
    <form action={formAction} className="space-y-4">
      <label className="block text-sm font-medium">
        Email or username
        <input
          name="usr"
          type="text"
          autoComplete="username"
          defaultValue={state.usr}
          required
          autoFocus
          className={`${inputClass} mt-1 font-normal`}
        />
      </label>

      <label className="block text-sm font-medium">
        Password
        <input
          name="pwd"
          type="password"
          autoComplete="current-password"
          required
          className={`${inputClass} mt-1 font-normal`}
        />
      </label>

      {state.error && (
        <p role="alert" className="text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}

      <button
        type="submit"
        disabled={pending}
        className="w-full rounded-lg bg-neutral-900 px-4 py-2 text-sm font-medium text-white hover:bg-neutral-700 disabled:opacity-50 dark:bg-white dark:text-neutral-900 dark:hover:bg-neutral-200"
      >
        {pending ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
