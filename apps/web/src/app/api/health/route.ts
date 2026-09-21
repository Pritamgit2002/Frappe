import { frappeFetch } from "@/lib/frappe/client";

/** GET /api/health: is the web app up, and can it reach Frappe? (Frappe's own /api/method/ping is the probe.) */
export async function GET() {
  let frappe: "up" | "down" = "down";
  try {
    const res = await frappeFetch("/api/method/ping");
    if (res.ok) frappe = "up";
  } catch {
    // Unreachable: report "down" below.
  }

  return Response.json({ web: "up", frappe }, { status: frappe === "up" ? 200 : 503 });
}
