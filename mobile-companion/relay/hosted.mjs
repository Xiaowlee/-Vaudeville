// One address serves Next, the game and isolated relay rooms (local combined test / single-host option).
// For Vercel + a separate relay, use public-relay.mjs instead.
import { createServer } from "node:http";
import next from "next";
import { createSessions } from "./sessions.mjs";
const port = Number(process.env.PORT || 3000);
const origin = new URL(process.env.PUBLIC_ORIGIN || process.env.RENDER_EXTERNAL_URL || `http://localhost:${port}`).origin;
if (process.env.NODE_ENV === "production" && !origin.startsWith("https://")) throw Error("Set PUBLIC_ORIGIN to the public HTTPS address");
process.env.VAUDEVILLE_HOSTED = "1";
const app = next({dev: process.env.NODE_ENV !== "production"});
await app.prepare();
const handle = app.getRequestHandler();
const sessions = createSessions({relayOrigin: origin, websiteOrigin: origin, trustProxy: !!(process.env.RENDER || process.env.TRUST_PROXY)});
const server = createServer(async (req, res) => {
 try {
  const path = new URL(req.url, origin).pathname;
  if (path === "/health") { res.writeHead(200, {"Content-Type":"application/json"}); res.end('{"ok":true}'); return; }
  if (path !== "/api/pair") return handle(req, res);
  return await sessions.handlePair(req, res);
 } catch (error) {
  console.error("Pairing request failed:", error.message);
  if (!res.headersSent) { res.writeHead(500, {"Content-Type":"application/json"}); res.end('{"error":"Pairing unavailable"}'); }
 }
});
server.on("upgrade", sessions.handleUpgrade);
server.listen(port, "0.0.0.0", () => console.log(`Hosted game and relay ready on port ${port}`));
