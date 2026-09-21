import { logout } from "@/app/actions/auth";
import { StatusTabs } from "@/components/status-tabs";
import { TodoForm } from "@/components/todo-form";
import { TodoRow } from "@/components/todo-row";
import { getTodoStats, listTodos } from "@/lib/frappe/todos";
import { verifySession } from "@/lib/session";
import { TODO_STATUSES } from "@/lib/types";

export default async function HomePage({ searchParams }: PageProps<"/">) {
  const { sid, user } = await verifySession();

  // Ignore anything in ?status= that isn't a real status.
  const { status: requested } = await searchParams;
  const status = TODO_STATUSES.find((candidate) => candidate === requested);

  const [todos, stats] = await Promise.all([
    listTodos(sid, { owner: user.user, status }),
    getTodoStats(sid),
  ]);

  console.log(stats);

  // Computed once on the server and passed down, so server and client agree on what "overdue" means.
  const today = new Date().toLocaleDateString("en-CA"); // YYYY-MM-DD

  return (
    <main className="mx-auto w-full max-w-2xl px-4 py-10">
      <header className="mb-8 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Todos</h1>
          <p className="mt-1 text-sm text-neutral-500">
            Signed in as {user.full_name}
          </p>
        </div>
        <form action={logout}>
          <button
            type="submit"
            className="rounded-lg border border-neutral-300 px-3 py-1.5 text-sm hover:bg-neutral-100 dark:border-neutral-700 dark:hover:bg-neutral-900"
          >
            Sign out
          </button>
        </form>
      </header>

      <TodoForm />
      <StatusTabs active={status} stats={stats} />

      {todos.length === 0 ? (
        <p className="rounded-xl border border-dashed border-neutral-300 px-4 py-12 text-center text-sm text-neutral-500 dark:border-neutral-700">
          {status
            ? `Nothing is "${status}" right now.`
            : "No todos yet. Add your first one above."}
        </p>
      ) : (
        <ul className="space-y-2">
          {todos.map((todo) => (
            <TodoRow key={todo.name} todo={todo} today={today} />
          ))}
        </ul>
      )}
    </main>
  );
}
