// Private game sessions: pairing (POST /api/pair + QR) and isolated WebSocket rooms.
// Used by public-relay.mjs (relay on its own address) and hosted.mjs (website and relay on one address).
import { randomBytes } from "node:crypto";
import QRCode from "qrcode";
import { WebSocketServer } from "ws";
import { installProtocol } from "./protocol.mjs";

const secret = () => randomBytes(24).toString("base64url");
const ttl = 12 * 60 * 60 * 1000;

// relayOrigin: public HTTPS address of this relay. websiteOrigin: address that serves /stage for phones.
// extraOrigins: other website addresses (e.g. Vercel previews) allowed to pair and connect.
export function createSessions({relayOrigin, websiteOrigin, extraOrigins = [], trustProxy = false}) {
  const allowed = new Set([relayOrigin, websiteOrigin, ...extraOrigins].map(o => new URL(o).origin));
  const rooms = new Map();
  const limits = new Map();
  // Browsers always send Origin; desktop Godot builds send none and rely on their private token.
  const originAllowed = origin => !origin || allowed.has(origin);
  const clientIp = req => (trustProxy && String(req.headers["x-forwarded-for"] || "").split(",")[0].trim()) || req.socket.remoteAddress;

  function reply(req, res, code, data) {
    const headers = {"Content-Type": "application/json", "Cache-Control": "no-store"};
    if (req.headers.origin && allowed.has(req.headers.origin)) Object.assign(headers, {"Access-Control-Allow-Origin": req.headers.origin, "Vary": "Origin"});
    res.writeHead(code, headers);
    res.end(data === undefined ? "" : JSON.stringify(data));
  }

  async function handlePair(req, res) {
    if (!originAllowed(req.headers.origin)) return reply(req, res, 403, {error: "Origin rejected"});
    if (req.method === "OPTIONS") {
      res.setHeader("Access-Control-Allow-Methods", "POST");
      res.setHeader("Access-Control-Allow-Headers", req.headers["access-control-request-headers"] || "");
      res.setHeader("Access-Control-Max-Age", "600");
      return reply(req, res, 204);
    }
    if (req.method !== "POST") return reply(req, res, 405, {error: "POST required"});
    const ip = clientIp(req);
    const count = limits.get(ip) || 0;
    if (count >= 60 || rooms.size >= 200) return reply(req, res, 429, {error: "Please retry later"});
    limits.set(ip, count + 1);
    const id = secret(), gameToken = secret(), phoneToken = secret(), speechToken = secret();
    const room = {wss: new WebSocketServer({noServer: true, maxPayload: 16384}), gameToken, phoneToken, speechToken, expires: Date.now() + ttl};
    installProtocol(room.wss);
    rooms.set(id, room);
    const relay = relayOrigin.replace(/^http/, "ws") + "/relay";
    const phoneRelay = `${relay}?room=${id}&token=${phoneToken}`;
    const gameRelay = `${relay}?room=${id}&token=${gameToken}`;
    // Fragment stays out of ordinary website request/access logs.
    const speechUrl = `${websiteOrigin}/speech-test#relay=${encodeURIComponent(`${relay}?room=${id}&token=${speechToken}`)}`;
    const phoneUrl = `${websiteOrigin}/stage#relay=${encodeURIComponent(phoneRelay)}`;
    const qr = await QRCode.toString(phoneUrl, {type: "svg", errorCorrectionLevel: "M", margin: 4});
    return reply(req, res, 201, {speech_url: speechUrl, game_relay: gameRelay, phone_url: phoneUrl, qr_svg: qr, expires_at: room.expires});
  }

  function handleUpgrade(req, socket, head) {
    const url = new URL(req.url, relayOrigin);
    const room = rooms.get(url.searchParams.get("room"));
    const token = url.searchParams.get("token");
    const role = room && (token === room.gameToken ? "game" : token === room.phoneToken ? "stage_phone" : token === room.speechToken ? "speech_client" : "");
    if (url.pathname !== "/relay" || !originAllowed(req.headers.origin) || !role || room.expires < Date.now() || room.wss.clients.size >= 8) {
      socket.write("HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n");
      socket.destroy();
      return;
    }
    room.wss.handleUpgrade(req, socket, head, ws => { ws.allowedRole = role; room.wss.emit("connection", ws, req); });
  }

  setInterval(() => limits.clear(), 60000).unref();
  setInterval(() => {
    for (const [id, room] of rooms) if (room.expires < Date.now()) {
      for (const ws of room.wss.clients) ws.close(1001, "Session expired");
      room.wss.close();
      rooms.delete(id);
    }
  }, 60000).unref();

  return {handlePair, handleUpgrade, rooms};
}
