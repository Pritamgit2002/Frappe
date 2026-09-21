"use client";

import { useActionState } from "react";
import { type CreateTodoState, createTodo } from "@/app/actions/todos";
import { TODO_PRIORITIES } from "@/lib/types";

const fieldClass =
  "rounded-lg border border-neutral-300 bg-white px-3 py-2 text-sm outline-none focus:border-neutral-900 focus:ring-2 focus:ring-neutral-900/10 dark:border-neutral-700 dark:bg-neutral-900 dark:focus:border-neutral-300 dark:focus:ring-neutral-300/20";

export function TodoForm() {
  const [state, formAction, pending] = useActionState<CreateTodoState, FormData>(createTodo, {});

  return (
    <form action={formAction} className="mb-6 space-y-2">
      <div className="flex flex-col gap-2 sm:flex-row">
        <input
          name="title"
          type="text"
          placeholder="What needs doing?"
          aria-label="Title"
          defaultValue={state.values?.title}
          maxLength={140}
          required
          className={`${fieldClass} min-w-0 flex-1`}
        />
        <select name="priority" defaultValue="Medium" aria-label="Priority" className={fieldClass}>
          {TODO_PRIORITIES.map((priority) => (
            <option key={priority} value={priority}>
              {priority}
            </option>
          ))}
        </select>
        <input name="due_date" type="date" aria-label="Due date" className={fieldClass} />
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-neutral-900 px-4 py-2 text-sm font-medium text-white hover:bg-neutral-700 disabled:opacity-50 dark:bg-white dark:text-neutral-900 dark:hover:bg-neutral-200"
        >
          {pending ? "Adding…" : "Add"}
        </button>
      </div>
      {state.error && (
        <p role="alert" className="text-sm text-red-600 dark:text-red-400">
          {state.error}
        </p>
      )}
    </form>
  );
}
