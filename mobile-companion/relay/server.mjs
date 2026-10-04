import { installProtocol } from "./protocol.mjs";
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

installProtocol(wss);

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
