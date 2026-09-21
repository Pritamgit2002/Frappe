import Link from "next/link";
import { TODO_STATUSES, type TodoStats, type TodoStatus } from "@/lib/types";

const TABS: { label: string; status?: TodoStatus }[] = [
  { label: "All" },
  ...TODO_STATUSES.map((status) => ({ label: status, status })),
];

export function StatusTabs({ active, stats }: { active?: TodoStatus; stats: TodoStats }) {
  return (
    <nav aria-label="Filter by status" className="mb-4 flex flex-wrap gap-1 border-b border-neutral-200 dark:border-neutral-800">
      {TABS.map(({ label, status }) => {
        const isActive = status === active;
        const count = status ? stats[status] : stats.total;
        return (
          <Link
            key={label}
            href={status ? { pathname: "/", query: { status } } : "/"}
            aria-current={isActive ? "page" : undefined}
            className={`-mb-px border-b-2 px-3 py-2 text-sm ${
              isActive
                ? "border-neutral-900 font-medium dark:border-white"
                : "border-transparent text-neutral-500 hover:text-neutral-900 dark:hover:text-neutral-100"
            }`}
          >
            {label} <span className="ml-1 text-xs text-neutral-400">{count}</span>
          </Link>
        );
      })}
    </nav>
  );
}
