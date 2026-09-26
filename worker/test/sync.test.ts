import { beforeEach, describe, expect, test } from "bun:test";
import worker from "../src/index";
import { PULL_LIMIT, type SyncSolve } from "../src/sync";
import { FakeD1 } from "./fake-d1";

const TOKEN = "test-token";
let d1: FakeD1;

beforeEach(() => {
  d1 = new FakeD1();
});

function solve(n: number, overrides: Partial<SyncSolve> = {}): SyncSolve {
  const id = `0199a7c1-0000-7000-8000-${n.toString(16).padStart(12, "0")}`;
  return {
    id,
    created_at: 1_790_000_000_000 + n,
    date: "2026-09-26",
    time_ms: 10_000 + n,
    scramble: "R U R' U'",
    penalty: 0,
    updated_at: 1_790_000_000_000 + n,
    deleted_at: null,
    ...overrides,
  };
}

async function call(body: unknown, token = TOKEN, method = "POST") {
  const request = new Request("https://sync.example/sync", {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
  const response = await worker.fetch(request, { DB: d1.asD1(), SYNC_TOKEN: TOKEN });
  return { status: response.status, body: (await response.json()) as any };
}

describe("auth", () => {
  test("rejects a wrong token", async () => {
    expect((await call({ since: 0, changes: [] }, "nope")).status).toBe(401);
  });

  test("health needs no token", async () => {
    const response = await worker.fetch(new Request("https://sync.example/health"), { DB: d1.asD1(), SYNC_TOKEN: TOKEN });
    expect(response.status).toBe(200);
  });

  test("rejects everything when no token is configured", async () => {
    const request = new Request("https://sync.example/sync", { method: "POST", headers: { authorization: "Bearer " } });
    const response = await worker.fetch(request, { DB: d1.asD1(), SYNC_TOKEN: "" });
    expect(response.status).toBe(401);
  });
});

describe("sync", () => {
  test("push then pull from another device", async () => {
    const pushed = await call({ since: 0, changes: [solve(1), solve(2)] });
    expect(pushed.status).toBe(200);
    expect(pushed.body.rev).toBe(2);

    const other = await call({ since: 0, changes: [] });
    expect(other.body.changes).toEqual([solve(1), solve(2)]);
    expect(other.body.more).toBe(false);

    const nothingNew = await call({ since: other.body.rev, changes: [] });
    expect(nothingNew.body).toEqual({ rev: 2, more: false, changes: [] });
  });

  test("newer edit wins, older edit is ignored", async () => {
    await call({ since: 0, changes: [solve(1)] });
    await call({ since: 0, changes: [solve(1, { penalty: 2, updated_at: solve(1).updated_at + 100 })] });
    await call({ since: 0, changes: [solve(1, { penalty: 1, updated_at: solve(1).updated_at + 50 })] });

    const { body } = await call({ since: 0, changes: [] });
    expect(body.changes).toHaveLength(1);
    expect(body.changes[0].penalty).toBe(2);
  });

  test("an accepted edit gets a new revision; a rejected one does not", async () => {
    await call({ since: 0, changes: [solve(1), solve(2)] });
    const edited = await call({ since: 2, changes: [solve(1, { deleted_at: 5, updated_at: solve(1).updated_at + 1 })] });
    expect(edited.body.rev).toBe(3);
    expect(edited.body.changes.map((s: SyncSolve) => s.id)).toEqual([solve(1).id]);

    const stale = await call({ since: 3, changes: [solve(2)] });
    expect(stale.body).toEqual({ rev: 3, more: false, changes: [] });
  });

  test("pages large pulls", async () => {
    const all = Array.from({ length: PULL_LIMIT + 20 }, (_, i) => solve(i + 1));
    await call({ since: 0, changes: all.slice(0, 500) });
    await call({ since: 0, changes: all.slice(500) });

    const first = await call({ since: 0, changes: [] });
    expect(first.body.changes).toHaveLength(PULL_LIMIT);
    expect(first.body.more).toBe(true);
    const second = await call({ since: first.body.rev, changes: [] });
    expect(second.body.changes).toHaveLength(20);
    expect(second.body.more).toBe(false);
  });

  test("rejects invalid input", async () => {
    expect((await call({ since: -1, changes: [] })).status).toBe(400);
    expect((await call({ since: 0 })).status).toBe(400);
    expect((await call({ since: 0, changes: [solve(1, { penalty: 3 })] })).status).toBe(400);
    expect((await call({ since: 0, changes: [solve(1, { id: "not-a-uuid" })] })).status).toBe(400);
    expect((await call({ since: 0, changes: [solve(1, { date: "26/09/2026" })] })).status).toBe(400);
    expect((await call(undefined, TOKEN, "GET")).status).toBe(405);
  });

  test("a missing deleted_at means not deleted", async () => {
    const { deleted_at: _, ...withoutDeletedAt } = solve(1);
    expect((await call({ since: 0, changes: [withoutDeletedAt] })).body.changes).toEqual([solve(1)]);
  });

  test("a batch with an invalid solve stores nothing", async () => {
    await call({ since: 0, changes: [solve(1), solve(2, { time_ms: -5 })] });
    expect((await call({ since: 0, changes: [] })).body.changes).toEqual([]);
  });
});
