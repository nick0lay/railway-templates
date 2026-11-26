// Starts DataCat on Railway:
//   1. waits until Postgres (and ClickHouse when DATACAT_STORAGE=clickhouse) accept connections, so the
//      migrations at startup don't fail on the first deploy;
//   2. runs the upstream server as a child process and forwards SIGTERM/SIGINT to it;
//   3. on the first boot (no users yet) creates the admin and organization from ADMIN_EMAIL,
//      ADMIN_PASSWORD and ORG_NAME through the first-run setup API, using DATACAT_SETUP_TOKEN.
// After that DataCat is invite-only: setup answers 409 and members join through admin invite links.
import { spawn } from "node:child_process";
import net from "node:net";

const port = process.env.PORT || "3000";
const log = (m) => console.log(`start: ${m}`);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function tcpOpen(host, p) {
  return new Promise((resolve) => {
    const s = net.connect({ host, port: Number(p) });
    s.setTimeout(3000);
    s.once("connect", () => { s.destroy(); resolve(true); });
    s.once("timeout", () => { s.destroy(); resolve(false); });
    s.once("error", () => resolve(false));
  });
}

async function waitFor(name, check, seconds = 300) {
  const until = Date.now() + seconds * 1000;
  while (Date.now() < until) {
    if (await check().catch(() => false)) { log(`${name} is up`); return; }
    await sleep(2000);
  }
  log(`${name} not reachable after ${seconds}s, starting anyway`);
}

try {
  const u = new URL(process.env.DATABASE_URL || "");
  await waitFor("Postgres", () => tcpOpen(u.hostname.replace(/^\[|\]$/g, ""), u.port || 5432));
} catch { log("DATABASE_URL is not a URL, skipping the Postgres wait"); }

if ((process.env.DATACAT_STORAGE || "postgres") === "clickhouse") {
  const ch = (process.env.DATACAT_CLICKHOUSE_URL || "http://127.0.0.1:8123").replace(/\/$/, "");
  await waitFor("ClickHouse", async () => (await fetch(`${ch}/ping`, { signal: AbortSignal.timeout(3000) })).ok);
}

const child = spawn(process.execPath, ["--enable-source-maps", "/app/artifacts/api-server/dist/index.mjs"], { stdio: "inherit" });
for (const sig of ["SIGTERM", "SIGINT"]) process.on(sig, () => child.kill(sig));
child.on("exit", (code, sig) => process.exit(code ?? (sig ? 1 : 0)));

async function bootstrap() {
  const email = (process.env.ADMIN_EMAIL || "").trim();
  const password = process.env.ADMIN_PASSWORD || "";
  const setupToken = process.env.DATACAT_SETUP_TOKEN || "";
  if (!email || !password || !setupToken) { log("ADMIN_EMAIL, ADMIN_PASSWORD or DATACAT_SETUP_TOKEN not set, skipping admin setup"); return; }
  const base = `http://127.0.0.1:${port}`;
  for (let i = 0; i < 150; i++) {
    try {
      const r = await fetch(`${base}/api/healthz`, { signal: AbortSignal.timeout(3000) });
      if (r.ok) break;
    } catch {}
    await sleep(2000);
  }
  const state = await (await fetch(`${base}/api/auth/user`)).json();
  if (!state.setupRequired) { log("admin already set up, skipping"); return; }
  const r = await fetch(`${base}/api/auth/setup`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ setupToken, email, password, orgName: process.env.ORG_NAME || "My Organization" }),
  });
  if (r.ok || r.status === 409) log(`admin ${email} created; setup is now closed (invite-only)`);
  else log(`admin setup failed: HTTP ${r.status} ${(await r.text()).slice(0, 200)}`);
}
bootstrap().catch((e) => log(`admin setup error: ${e.message}`));
