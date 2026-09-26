import { Database } from "bun:sqlite";
import { readFileSync } from "node:fs";

/** Just enough of the D1 API for the worker, backed by an in-memory SQLite database. */
class FakeStatement {
  constructor(
    private db: Database,
    private sql: string,
    private params: unknown[] = [],
  ) {}

  bind(...params: unknown[]): FakeStatement {
    return new FakeStatement(this.db, this.sql, params);
  }

  async all<T>(): Promise<{ results: T[] }> {
    return { results: this.db.query(this.sql).all(...(this.params as never[])) as T[] };
  }

  async run() {
    this.runSync();
    return { success: true };
  }

  runSync() {
    this.db.query(this.sql).run(...(this.params as never[]));
  }
}

export class FakeD1 {
  readonly db = new Database(":memory:");

  constructor() {
    this.db.exec(readFileSync(`${import.meta.dir}/../migrations/0001_solves.sql`, "utf8"));
  }

  prepare(sql: string): FakeStatement {
    return new FakeStatement(this.db, sql);
  }

  async batch(statements: FakeStatement[]) {
    this.db.transaction(() => statements.forEach((s) => s.runSync()))();
    return statements.map(() => ({ success: true }));
  }

  asD1(): D1Database {
    return this as unknown as D1Database;
  }
}
