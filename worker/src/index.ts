import { Hono } from "hono";

type Bindings = {
  DB: D1Database;
  SYNC_TOKEN: string;
};

const app = new Hono<{ Bindings: Bindings }>();

app.get("/health", (c) => c.json({ ok: true }));

app.use("/sync/*", async (c, next) => {
  if (c.req.header("Authorization") !== `Bearer ${c.env.SYNC_TOKEN}`) {
    return c.json({ error: "unauthorized" }, 401);
  }
  await next();
});

// POST /sync is implemented in the sync step.
app.post("/sync", (c) => c.json({ error: "not implemented" }, 501));

export default app;
