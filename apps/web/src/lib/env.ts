import "server-only";

import { z } from "zod";

const schema = z.object({
  FRAPPE_URL: z.url(),
  FRAPPE_SITE_NAME: z.string().min(1).optional(),
});

// `FRAPPE_SITE_NAME=` in .env is an empty string; treat that as "not set".
const clean = (value: string | undefined) => value?.trim() || undefined;

/** Server-only configuration. None of this is sent to the browser. */
export const env = schema.parse({
  FRAPPE_URL: clean(process.env.FRAPPE_URL) ?? "http://127.0.0.1:8000",
  FRAPPE_SITE_NAME: clean(process.env.FRAPPE_SITE_NAME),
});
