// Local sync server for development: the real worker code on an in-memory database.
// Usage: SYNC_TOKEN=dev-token bun scripts/dev-server.ts   (listens on http://127.0.0.1:8788)
import worker from "../src/index";
import { FakeD1 } from "../test/fake-d1";

const d1 = new FakeD1();
const token = process.env.SYNC_TOKEN ?? "dev-token";
const server = Bun.serve({
  hostname: "127.0.0.1",
  port: Number(process.env.PORT ?? 8788),
  fetch: (request) => worker.fetch(request, { DB: d1.asD1(), SYNC_TOKEN: token }),
});
console.log(`sync dev server on ${server.url} (token: ${token})`);
