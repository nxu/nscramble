import { json } from "./http";

/** A solve on the wire: same columns as the database, times in epoch milliseconds. */
export interface SyncSolve {
  id: string;
  created_at: number;
  date: string;
  time_ms: number;
  scramble: string;
  penalty: number;
  updated_at: number;
  deleted_at: number | null;
}

/** Most solves accepted in one request. */
export const MAX_PUSH = 500;
/** Most solves returned in one response; `more` tells the client to ask again. */
export const PULL_LIMIT = 500;

// Last write wins: an incoming solve replaces the stored one only if it was edited later.
// Every stored change gets the next revision; D1 runs a batch as one transaction.
const UPSERT = `
INSERT INTO solves (id, created_at, date, time_ms, scramble, penalty, updated_at, deleted_at, rev)
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, (SELECT COALESCE(MAX(rev), 0) + 1 FROM solves))
ON CONFLICT (id) DO UPDATE SET
  created_at = excluded.created_at,
  date = excluded.date,
  time_ms = excluded.time_ms,
  scramble = excluded.scramble,
  penalty = excluded.penalty,
  updated_at = excluded.updated_at,
  deleted_at = excluded.deleted_at,
  rev = excluded.rev
WHERE excluded.updated_at > solves.updated_at`;

const PULL = `
SELECT id, created_at, date, time_ms, scramble, penalty, updated_at, deleted_at, rev
FROM solves WHERE rev > ?1 ORDER BY rev LIMIT ?2`;

/**
 * `POST /sync` with `{ since, changes }`: stores `changes`, then returns every solve whose revision
 * is above `since` as `{ rev, more, changes }`. The client saves `rev` as its next `since`.
 */
export async function handleSync(request: Request, db: D1Database): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid JSON" }, 400);
  }
  const parsed = parseBody(body);
  if ("error" in parsed) {
    return json({ error: parsed.error }, 400);
  }
  const { since, changes } = parsed;

  if (changes.length > 0) {
    await db.batch(
      changes.map((s) =>
        db.prepare(UPSERT).bind(s.id, s.created_at, s.date, s.time_ms, s.scramble, s.penalty, s.updated_at, s.deleted_at),
      ),
    );
  }

  const { results } = await db.prepare(PULL).bind(since, PULL_LIMIT + 1).all<SyncSolve & { rev: number }>();
  const more = results.length > PULL_LIMIT;
  const page = results.slice(0, PULL_LIMIT);
  const rev = page.length > 0 ? page[page.length - 1].rev : since;
  return json({ rev, more, changes: page.map(({ rev: _, ...solve }) => solve) });
}

function parseBody(body: unknown): { since: number; changes: SyncSolve[] } | { error: string } {
  if (typeof body !== "object" || body === null) {
    return { error: "expected an object" };
  }
  const { since, changes } = body as Record<string, unknown>;
  if (!Number.isSafeInteger(since) || (since as number) < 0) {
    return { error: "since must be a non-negative integer" };
  }
  if (!Array.isArray(changes)) {
    return { error: "changes must be an array" };
  }
  if (changes.length > MAX_PUSH) {
    return { error: `at most ${MAX_PUSH} changes per request` };
  }
  const solves: SyncSolve[] = [];
  for (const [i, c] of changes.entries()) {
    const solve = parseSolve(c);
    if (!solve) {
      return { error: `invalid solve at index ${i}` };
    }
    solves.push(solve);
  }
  return { since: since as number, changes: solves };
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;

function parseSolve(value: unknown): SyncSolve | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }
  const v = value as Record<string, unknown>;
  const isMs = (x: unknown) => Number.isSafeInteger(x) && (x as number) >= 0;
  const valid =
    typeof v.id === "string" && UUID.test(v.id) &&
    isMs(v.created_at) &&
    typeof v.date === "string" && DAY.test(v.date) &&
    isMs(v.time_ms) &&
    typeof v.scramble === "string" && v.scramble.length <= 200 &&
    (v.penalty === 0 || v.penalty === 1 || v.penalty === 2) &&
    isMs(v.updated_at) &&
    (v.deleted_at === null || v.deleted_at === undefined || isMs(v.deleted_at));
  if (!valid) {
    return null;
  }
  return {
    id: v.id as string,
    created_at: v.created_at as number,
    date: v.date as string,
    time_ms: v.time_ms as number,
    scramble: v.scramble as string,
    penalty: v.penalty as number,
    updated_at: v.updated_at as number,
    deleted_at: (v.deleted_at ?? null) as number | null,
  };
}
