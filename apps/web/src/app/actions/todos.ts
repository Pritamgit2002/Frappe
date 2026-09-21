"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { FrappeError } from "@/lib/frappe/client";
import { createTodo as apiCreate, deleteTodo as apiDelete, updateTodo as apiUpdate } from "@/lib/frappe/todos";
import { verifySession } from "@/lib/session";
import { TODO_PRIORITIES, TODO_STATUSES } from "@/lib/types";

// Server Functions are public endpoints: each one re-checks the session and validates its input.
// Frappe enforces document permissions too (a Todo User can only touch their own items).

export interface CreateTodoState {
  error?: string;
  /** Echoed back so the title survives a failed submit. */
  values?: { title: string };
}

export type ActionResult = { ok: true } | { ok: false; error: string };

const titleSchema = z.string().trim().min(1, "Give the todo a title.").max(140, "Keep the title under 140 characters.");
const nameSchema = z.string().min(1).max(140);

const createSchema = z.object({
  title: titleSchema,
  priority: z.enum(TODO_PRIORITIES),
  // <input type="date"> submits "" when empty.
  due_date: z.union([z.iso.date(), z.literal("")]).transform((value) => value || undefined),
});

export async function createTodo(_previous: CreateTodoState, formData: FormData): Promise<CreateTodoState> {
  const { sid } = await verifySession();

  const parsed = createSchema.safeParse({
    title: formData.get("title"),
    priority: formData.get("priority"),
    due_date: formData.get("due_date") ?? "",
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "Invalid input.", values: { title: String(formData.get("title") ?? "") } };
  }

  try {
    await apiCreate(sid, parsed.data);
  } catch (error) {
    return { error: describe(error), values: { title: parsed.data.title } };
  }

  revalidatePath("/");
  return {};
}

export async function setTodoStatus(name: string, status: string): Promise<ActionResult> {
  const parsed = z.object({ name: nameSchema, status: z.enum(TODO_STATUSES) }).safeParse({ name, status });
  if (!parsed.success) return { ok: false, error: "Invalid status." };

  return mutate((sid) => apiUpdate(sid, parsed.data.name, { status: parsed.data.status }));
}

export async function renameTodo(name: string, title: string): Promise<ActionResult> {
  const parsed = z.object({ name: nameSchema, title: titleSchema }).safeParse({ name, title });
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0]?.message ?? "Invalid title." };

  return mutate((sid) => apiUpdate(sid, parsed.data.name, { title: parsed.data.title }));
}

export async function removeTodo(name: string): Promise<ActionResult> {
  const parsed = nameSchema.safeParse(name);
  if (!parsed.success) return { ok: false, error: "Invalid todo." };

  return mutate((sid) => apiDelete(sid, parsed.data));
}

async function mutate(work: (sid: string) => Promise<unknown>): Promise<ActionResult> {
  const { sid } = await verifySession();
  try {
    await work(sid);
  } catch (error) {
    return { ok: false, error: describe(error) };
  }
  revalidatePath("/");
  return { ok: true };
}

function describe(error: unknown): string {
  return error instanceof FrappeError ? error.message : "Something went wrong. Please try again.";
}
