// Relay-only public server (e.g. Render). The website (Vercel) is hosted separately.
// TLS is supplied by the host; this process listens on plain HTTP behind it.
import { createServer } from "node:http";
import { createSessions } from "./sessions.mjs";

const port = Number(process.env.PORT || 8790);
const relayOrigin = new URL(process.env.RELAY_PUBLIC_ORIGIN || process.env.RENDER_EXTERNAL_URL || `http://localhost:${port}`).origin;
const websiteOrigin = process.env.WEBSITE_ORIGIN ? new URL(process.env.WEBSITE_ORIGIN).origin : "";
const extraOrigins = (process.env.EXTRA_ALLOWED_ORIGINS || "").split(",").map(s => s.trim()).filter(Boolean);
if (!websiteOrigin) throw Error("Set WEBSITE_ORIGIN to the website address, e.g. https://your-project.vercel.app");
if (process.env.NODE_ENV === "production" && ![relayOrigin, websiteOrigin, ...extraOrigins].every(o => o.startsWith("https://")))
  throw Error("In production the relay and website addresses must use https://");

const sessions = createSessions({relayOrigin, websiteOrigin, extraOrigins, trustProxy: !!(process.env.RENDER || process.env.TRUST_PROXY)});
const server = createServer(async (req, res) => {
  try {
    const path = new URL(req.url, relayOrigin).pathname;
    if (path === "/api/pair") return await sessions.handlePair(req, res);
    res.writeHead(path === "/health" || path === "/" ? 200 : 404, {"Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store"});
    res.end(path === "/health" ? "ok" : "Vaudeville relay");
  } catch (error) {
    console.error("Pairing request failed:", error.message);
    if (!res.headersSent) { res.writeHead(500, {"Content-Type": "application/json"}); res.end(JSON.stringify({error: "Pairing unavailable"})); }
  }
});
server.on("upgrade", sessions.handleUpgrade);
server.listen(port, "0.0.0.0", () => console.log(`Relay ready on port ${port}; public ${relayOrigin}; website ${websiteOrigin}`));
