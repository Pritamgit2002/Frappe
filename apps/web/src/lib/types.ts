// Shapes of the `Todo Item` DocType as served by Frappe's REST API.
// Client-safe: no server-only imports, so components can use these too.
// Keep in sync with apps/api/todo_app/todo_app/todo/doctype/todo_item/todo_item.json.

export const TODO_STATUSES = ["Open", "In Progress", "Done"] as const;
export const TODO_PRIORITIES = ["Low", "Medium", "High"] as const;

export type TodoStatus = (typeof TODO_STATUSES)[number];
export type TodoPriority = (typeof TODO_PRIORITIES)[number];

export interface Todo {
  /** Frappe document name, e.g. "TODO-00001". */
  name: string;
  title: string;
  description: string | null;
  status: TodoStatus;
  priority: TodoPriority;
  /** "YYYY-MM-DD" */
  due_date: string | null;
  /** "YYYY-MM-DD HH:mm:ss.ffffff", set by Frappe when the item becomes Done. */
  completed_at: string | null;
  creation: string;
  modified: string;
}

/** Response of `todo_app.api.stats`. */
export type TodoStats = Record<TodoStatus, number> & { total: number };

/** Response of `todo_app.api.me`. */
export interface SessionUser {
  user: string;
  full_name: string;
}
