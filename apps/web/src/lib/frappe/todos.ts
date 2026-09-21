import "server-only";

import type { Todo, TodoPriority, TodoStats, TodoStatus } from "@/lib/types";
import { frappeJson } from "./client";

// Frappe's generic REST resource API: /api/resource/<DocType>[/<name>]
const DOCTYPE = "Todo Item";
const resourcePath = (name?: string) =>
  `/api/resource/${encodeURIComponent(DOCTYPE)}${name ? `/${encodeURIComponent(name)}` : ""}`;

const FIELDS = [
  "name",
  "title",
  "description",
  "status",
  "priority",
  "due_date",
  "completed_at",
  "creation",
  "modified",
] satisfies (keyof Todo)[];

export interface ListTodosParams {
  /** Frappe user id. Scopes the list to "my todos" even for users who could see everyone's. */
  owner: string;
  status?: TodoStatus;
  limit?: number;
}

/** GET /api/resource/Todo Item?fields=[..]&filters=[..]&order_by=..&limit_page_length=.. */
export async function listTodos(sid: string, { owner, status, limit = 100 }: ListTodosParams): Promise<Todo[]> {
  const filters: [string, string, string][] = [["owner", "=", owner]];
  if (status) filters.push(["status", "=", status]);

  const { data } = await frappeJson<{ data: Todo[] }>(resourcePath(), {
    sid,
    query: { fields: FIELDS, filters, order_by: "creation desc", limit_page_length: limit },
  });
  return data;
}

/** GET /api/method/todo_app.api.stats */
export async function getTodoStats(sid: string): Promise<TodoStats> {
  const { message } = await frappeJson<{ message: TodoStats }>("/api/method/todo_app.api.stats", { sid });
  return message;
}

export interface NewTodo {
  title: string;
  priority: TodoPriority;
  due_date?: string;
  description?: string;
}

/** POST /api/resource/Todo Item */
export async function createTodo(sid: string, todo: NewTodo): Promise<Todo> {
  const { data } = await frappeJson<{ data: Todo }>(resourcePath(), { method: "POST", sid, body: todo });
  return data;
}

export type TodoPatch = Partial<Pick<Todo, "title" | "description" | "status" | "priority" | "due_date">>;

/** PUT /api/resource/Todo Item/<name>: only the fields you send are changed. */
export async function updateTodo(sid: string, name: string, patch: TodoPatch): Promise<Todo> {
  const { data } = await frappeJson<{ data: Todo }>(resourcePath(name), { method: "PUT", sid, body: patch });
  return data;
}

/** DELETE /api/resource/Todo Item/<name> */
export async function deleteTodo(sid: string, name: string): Promise<void> {
  await frappeJson<unknown>(resourcePath(name), { method: "DELETE", sid });
}
