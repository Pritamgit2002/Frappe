"use client";

import { useOptimistic, useState, useTransition } from "react";
import { type ActionResult, removeTodo, renameTodo, setTodoStatus } from "@/app/actions/todos";
import { TODO_STATUSES, type Todo, type TodoPriority, type TodoStatus } from "@/lib/types";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Formatted by hand (not Intl) so the server render and the browser render can't disagree.
function formatDate(iso: string): string {
  const [year, month, day] = iso.split("-").map(Number);
  return `${MONTHS[month - 1]} ${day}, ${year}`;
}

const PRIORITY_STYLES: Record<TodoPriority, string> = {
  High: "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300",
  Medium: "bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-300",
  Low: "bg-neutral-100 text-neutral-600 dark:bg-neutral-800 dark:text-neutral-400",
};

const linkButton =
  "rounded px-1.5 py-0.5 text-xs text-neutral-500 hover:bg-neutral-100 hover:text-neutral-900 dark:hover:bg-neutral-800 dark:hover:text-neutral-100";

export function TodoRow({ todo, today }: { todo: Todo; today: string }) {
  const [pending, startTransition] = useTransition();
  const [status, setOptimisticStatus] = useOptimistic<TodoStatus, TodoStatus>(todo.status, (_current, next) => next);
  const [editing, setEditing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const done = status === "Done";
  const overdue = !done && todo.due_date !== null && todo.due_date < today;

  function run(action: () => Promise<ActionResult>, onSuccess?: () => void) {
    setError(null);
    startTransition(async () => {
      const result = await action();
      if (result.ok) onSuccess?.();
      else setError(result.error);
    });
  }

  function changeStatus(next: TodoStatus) {
    setError(null);
    startTransition(async () => {
      setOptimisticStatus(next); // reverts by itself if the action fails
      const result = await setTodoStatus(todo.name, next);
      if (!result.ok) setError(result.error);
    });
  }

  return (
    <li
      className={`rounded-xl border border-neutral-200 bg-white p-3 transition-opacity dark:border-neutral-800 dark:bg-neutral-900 ${
        pending ? "opacity-60" : ""
      }`}
    >
      {/* Stacked on phones (controls under the title), one line from `sm` up. */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:gap-3">
        <div className="flex min-w-0 flex-1 items-start gap-3">
          <input
            type="checkbox"
            checked={done}
            onChange={() => changeStatus(done ? "Open" : "Done")}
            aria-label={`Mark "${todo.title}" as ${done ? "open" : "done"}`}
            className="mt-1 size-4 shrink-0 cursor-pointer accent-neutral-900 dark:accent-white"
          />

          <div className="min-w-0 flex-1">
            {editing ? (
              <form
                className="flex gap-2"
                onSubmit={(event) => {
                  event.preventDefault();
                  const title = String(new FormData(event.currentTarget).get("title") ?? "");
                  run(() => renameTodo(todo.name, title), () => setEditing(false));
                }}
              >
                <input
                  name="title"
                  defaultValue={todo.title}
                  aria-label="Title"
                  maxLength={140}
                  required
                  autoFocus
                  className="min-w-0 flex-1 rounded-md border border-neutral-300 bg-transparent px-2 py-1 text-sm dark:border-neutral-700"
                />
                <button type="submit" className={linkButton}>
                  Save
                </button>
                <button type="button" onClick={() => setEditing(false)} className={linkButton}>
                  Cancel
                </button>
              </form>
            ) : (
              <p className={`break-words text-sm ${done ? "text-neutral-400 line-through" : ""}`}>{todo.title}</p>
            )}

            <div className="mt-1.5 flex flex-wrap items-center gap-2 text-xs">
              <span className={`rounded-full px-2 py-0.5 font-medium ${PRIORITY_STYLES[todo.priority]}`}>
                {todo.priority}
              </span>
              {todo.due_date && (
                <span className={overdue ? "font-medium text-red-600 dark:text-red-400" : "text-neutral-500"}>
                  {overdue ? "Overdue · " : "Due "}
                  {formatDate(todo.due_date)}
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="flex shrink-0 items-center gap-2 pl-7 sm:pl-0">
          <select
            value={status}
            onChange={(event) => changeStatus(event.target.value as TodoStatus)}
            aria-label="Status"
            className="rounded-md border border-neutral-300 bg-transparent px-1.5 py-1 text-xs dark:border-neutral-700"
          >
            {TODO_STATUSES.map((option) => (
              <option key={option} value={option} className="text-neutral-900">
                {option}
              </option>
            ))}
          </select>

          <div className="flex gap-0.5">
            {!editing && (
              <button type="button" onClick={() => setEditing(true)} className={linkButton}>
                Edit
              </button>
            )}
            <button
              type="button"
              onClick={() => {
                if (window.confirm(`Delete "${todo.title}"?`)) run(() => removeTodo(todo.name));
              }}
              className={`${linkButton} hover:text-red-600 dark:hover:text-red-400`}
            >
              Delete
            </button>
          </div>
        </div>
      </div>

      {error && (
        <p role="alert" className="mt-2 text-xs text-red-600 dark:text-red-400">
          {error}
        </p>
      )}
    </li>
  );
}
