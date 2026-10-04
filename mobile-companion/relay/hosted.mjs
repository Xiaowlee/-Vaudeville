// One HTTPS origin (TLS supplied by the host) serves Next, the game and isolated relay rooms.
import { createServer } from "node:http";
import { randomBytes } from "node:crypto";
import next from "next";
import QRCode from "qrcode";
import { WebSocketServer } from "ws";
import { installProtocol } from "./protocol.mjs";
const port = Number(process.env.PORT || 3000);
const origin = new URL(process.env.PUBLIC_ORIGIN || process.env.RENDER_EXTERNAL_URL || `http://localhost:${port}`).origin;
if (process.env.NODE_ENV === "production" && !origin.startsWith("https://")) throw Error("Set PUBLIC_ORIGIN to the public HTTPS address");
process.env.VAUDEVILLE_HOSTED = "1";
const app = next({dev: process.env.NODE_ENV !== "production"});
await app.prepare();
const handle = app.getRequestHandler();
const rooms = new Map();
const limits = new Map();
const secret = () => randomBytes(24).toString("base64url");
const ttl = 12 * 60 * 60 * 1000;
function reply(res, code, data) {
 res.writeHead(code, {"Content-Type":"application/json", "Cache-Control":"no-store"}); res.end(JSON.stringify(data));
}
const server = createServer(async (req, res) => {
 try {
  const path = new URL(req.url, origin).pathname;
  if (path === "/health") return reply(res, 200, {ok:true});
  if (path !== "/api/pair") return handle(req, res);
  if (req.method !== "POST") return reply(res,405,{error:"POST required"});
  if (req.headers.origin && req.headers.origin !== origin) return reply(res,403,{error:"Origin rejected"});
  const ip = req.socket.remoteAddress;
  const count = limits.get(ip) || 0;
  if (count >= 60 || rooms.size >= 200) return reply(res,429,{error:"Please retry later"});
  limits.set(ip,count+1);
  const id=secret(), gameToken=secret(), phoneToken=secret();
  const room = {wss:new WebSocketServer({noServer:true,maxPayload:16384}),gameToken,phoneToken,expires:Date.now()+ttl};
  installProtocol(room.wss);
  rooms.set(id,room);
  const relay = origin.replace(/^http/,"ws")+"/relay";
  const phoneRelay = `${relay}?room=${id}&token=${phoneToken}`;
  const gameRelay = `${relay}?room=${id}&token=${gameToken}`;
  // Fragment stays out of ordinary website request/access logs.
  const phoneUrl = `${origin}/stage#relay=${encodeURIComponent(phoneRelay)}`;
  const qr = await QRCode.toString(phoneUrl,{type:"svg",errorCorrectionLevel:"M",margin:4});
  return reply(res,201,{game_relay:gameRelay,phone_url:phoneUrl,qr_svg:qr,expires_at:room.expires});
 } catch (error) { console.error("Pairing request failed:",error.message); reply(res,500,{error:"Pairing unavailable"}); }
});
server.on("upgrade",(req,socket,head)=>{
 const url=new URL(req.url,origin);
 if(url.pathname!=="/relay") { socket.destroy();return; }
 const room=rooms.get(url.searchParams.get("room"));
 const token=url.searchParams.get("token");
 const role=room && (token===room.gameToken ? "game" : token===room.phoneToken ? "stage_phone" : "");
 if(!role || room.expires<Date.now() || room.wss.clients.size>=8) {socket.write("HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n");socket.destroy();return;}
 room.wss.handleUpgrade(req,socket,head,ws=>{ws.allowedRole=role;room.wss.emit("connection",ws,req);});
});
setInterval(()=>limits.clear(),60000).unref();
setInterval(()=>{for(const [id,room] of rooms) if(room.expires<Date.now()) {
 for(const ws of room.wss.clients) ws.close(1001,"Session expired");
 room.wss.close();rooms.delete(id);
}},60000).unref();
server.listen(port,"0.0.0.0",()=>console.log(`Hosted game and relay ready on port ${port}`));
