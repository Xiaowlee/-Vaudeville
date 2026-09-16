import { createServer } from "node:https";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import os from "node:os";
import { WebSocketServer } from "ws";

const port = Number(process.env.PORT || 8787);
const host = process.env.HOST || "0.0.0.0";
const certDir = join(dirname(fileURLToPath(import.meta.url)), "..", ".certs");
const keyPath = join(certDir, "key.pem");
const certPath = join(certDir, "cert.pem");

function lanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((item) => item && item.family === "IPv4" && !item.internal)
    .map((item) => item.address);
}

function loadExistingCerts() {
  if (!existsSync(keyPath) || !existsSync(certPath)) {
    console.error("Relay will not create or install a certificate.");
    console.error(`Missing Next.js HTTPS files:\n  ${keyPath}\n  ${certPath}`);
    console.error("Start the Next.js app first (npm run dev in mobile-companion) so these existing local certs are available.");
    process.exit(1);
  }

  return {
    key: readFileSync(keyPath),
    cert: readFileSync(certPath),
  };
}

function clientAddress(request) {
  return request.socket.remoteAddress ?? "unknown";
}

function logIncoming(text) {
  try {
    const parsed = JSON.parse(text);
    if (parsed?.kind === "face_cue") {
      console.log("[relay] received face_cue", text);
      return "face_cue";
    }
    console.log("[relay] received message", text);
    return parsed?.kind ?? "message";
  } catch {
    console.log("[relay] received message", text);
    return "message";
  }
}

const { key, cert } = loadExistingCerts();

const server = createServer({ key, cert }, (_req, res) => {
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("Face companion relay. Accept this certificate, then return to the phone page.");
});

const wss = new WebSocketServer({ server });

wss.on("error", (error) => {
  console.error("[relay] WebSocket server error", error);
});

// One local game and phone; retain only the current request, never face success.
let game = null;
let request = null;
function phones() { return [...wss.clients].filter(c => c.role === "phone" && c.readyState === 1); }
function send(client, message) { if (client?.readyState === 1) client.send(JSON.stringify(message)); }
function phoneStatus() { send(game, {kind: "phone_status", connected: phones().length > 0}); }
wss.on("connection", (socket) => {
  socket.on("message", data => {
    let message;
    try { message = JSON.parse(data.toString()); } catch { return; }
    if (!message || typeof message !== "object") return;
    if (message.kind === "hello") {
      if (message.role === "game") {
        if (game && game !== socket) game.close();
        game = socket;
        socket.role = "game";
        request = null;
      } else if (message.role === "phone") {
        socket.role = "phone";
        if (request) send(socket, request);
      }
      phoneStatus();
    } else if (socket === game) {
      if (message.kind === "face_request" && typeof message.requestId === "string" && message.cue === "smile") request = message;
      else if (message.kind === "face_cancel" && message.requestId === request?.requestId) request = null;
      else if (message.kind !== "face_ack") return;
      for (const phone of phones()) send(phone, message);
    } else if (socket.role === "phone") {
      if (message.kind === "face_present" && typeof message.present === "boolean") send(game, message);
      if (message.kind === "face_cue" && request && message.requestId === request.requestId && message.cue === request.cue && message.met === true) send(game, message);
    }
  });
  socket.on("error", error => console.error("[relay] socket error", error.message));
  socket.on("close", () => {
    if (socket === game) {
      for (const phone of phones()) send(phone, {kind: "face_cancel", requestId: request?.requestId});
      game = null;
      request = null;
    }
    phoneStatus();
  });
});

server.on("error", (error) => {
  console.error("[relay] HTTPS server error", error);
});

server.listen(port, host, () => {
  const ips = lanAddresses();
  console.log("[relay] started");
  console.log(`[relay] address/port ${host}:${port}`);
  console.log(`[relay] using existing Next.js cert ${certPath}`);
  console.log(`[relay] local wss://localhost:${port}`);
  for (const ip of ips) {
    console.log(`[relay] network wss://${ip}:${port}`);
  }
});
