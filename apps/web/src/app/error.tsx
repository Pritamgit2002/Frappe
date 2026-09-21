"use client";

// Server errors are redacted in production builds, so this copy has to stand on its own.
export default function ErrorPage({ error, retry }: { error: Error & { digest?: string }; retry: () => void }) {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center px-4 py-10 text-center">
      <h1 className="text-xl font-semibold">Couldn&apos;t load your todos</h1>
      <p className="mt-2 text-sm text-neutral-500">
        The backend didn&apos;t answer or returned an error. Check that Frappe is running
        (<code className="font-mono">npm run dev:api</code>), then try again.
      </p>
      {process.env.NODE_ENV !== "production" && (
        <pre className="mt-4 rounded-lg bg-neutral-100 p-3 text-left text-xs break-words whitespace-pre-wrap dark:bg-neutral-900">
          {error.message}
        </pre>
      )}
      <button
        type="button"
        onClick={() => retry()}
        className="mx-auto mt-6 rounded-lg bg-neutral-900 px-4 py-2 text-sm font-medium text-white hover:bg-neutral-700 dark:bg-white dark:text-neutral-900 dark:hover:bg-neutral-200"
      >
        Try again
      </button>
    </main>
  );
}
