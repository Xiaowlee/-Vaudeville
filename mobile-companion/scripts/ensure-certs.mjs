import { mkdirSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import os from "node:os";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const selfsigned = require("selfsigned");

const certDir = join(dirname(fileURLToPath(import.meta.url)), "..", ".certs");
const keyPath = join(certDir, "key.pem");
const certPath = join(certDir, "cert.pem");

function lanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((item) => item && item.family === "IPv4" && !item.internal)
    .map((item) => item.address);
}

if (existsSync(keyPath) && existsSync(certPath)) {
  process.exit(0);
}

const ips = lanAddresses();
const pems = selfsigned.generate([{ name: "commonName", value: "localhost" }], {
  days: 365,
  keySize: 2048,
  algorithm: "sha256",
  extensions: [
    {
      name: "subjectAltName",
      altNames: [
        { type: 2, value: "localhost" },
        { type: 7, ip: "127.0.0.1" },
        ...ips.map((ip) => ({ type: 7, ip })),
      ],
    },
  ],
});

mkdirSync(certDir, { recursive: true });
writeFileSync(keyPath, pems.private);
writeFileSync(certPath, pems.cert);
console.log("Wrote local HTTPS certificates to .certs/");
