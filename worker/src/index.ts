import { json } from "./http";
import { handleSync } from "./sync";

export interface Env {
  DB: D1Database;
  /** API key shared by the apps; set with `wrangler secret put SYNC_TOKEN`. */
  SYNC_TOKEN: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") {
      return json({ ok: true });
    }
    if (!isAuthorized(request, env)) {
      return json({ error: "unauthorized" }, 401);
    }
    if (url.pathname === "/sync") {
      if (request.method !== "POST") {
        return json({ error: "method not allowed" }, 405);
      }
      return handleSync(request, env.DB);
    }
    return json({ error: "not found" }, 404);
  },
} satisfies ExportedHandler<Env>;

function isAuthorized(request: Request, env: Env): boolean {
  if (!env.SYNC_TOKEN) {
    return false;
  }
  const header = request.headers.get("authorization") ?? "";
  return constantTimeEqual(header, `Bearer ${env.SYNC_TOKEN}`);
}

function constantTimeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}
