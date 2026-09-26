-- Keep in sync with Packages/Storage/Sources/Storage/AppDatabase.swift (migration "v1").
CREATE TABLE sessions (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
);
CREATE TABLE solves (
    id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL REFERENCES sessions(id),
    scramble TEXT NOT NULL,
    time_ms INTEGER NOT NULL,
    penalty INTEGER NOT NULL DEFAULT 0,
    comment TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER
);
CREATE INDEX solves_session_created ON solves(session_id, created_at);
CREATE INDEX solves_updated ON solves(updated_at);
CREATE INDEX sessions_updated ON sessions(updated_at);
