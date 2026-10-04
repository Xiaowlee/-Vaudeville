import assert from "node:assert/strict";
import {WebSocket} from "ws";
// RELAY_BASE = relay/pairing server; WEBSITE = the address phone links should use (same as RELAY_BASE in single-host mode).
const base=(process.env.RELAY_BASE||"http://localhost:3100").replace(/\/$/,"");
const website=(process.env.WEBSITE||base).replace(/\/$/,"");
async function pair(origin){const r=await fetch(base+"/api/pair",{method:"POST",headers:origin?{Origin:origin}:{}});assert.equal(r.status,201);return r.json();}
async function connect(url,role,origin){const ws=new WebSocket(url,origin?{origin}:{});ws.messages=[];ws.on("message",x=>ws.messages.push(JSON.parse(x)));await new Promise((ok,no)=>{ws.once("open",ok);ws.once("error",no);});ws.send(JSON.stringify({kind:"hello",role}));return ws;}
const wait=()=>new Promise(r=>setTimeout(r,150));
const a=await pair(),b=await pair(website);assert.notEqual(a.phone_url,b.phone_url);assert(a.qr_svg.startsWith("<svg"));
assert(a.phone_url.startsWith(website+"/stage#relay="),a.phone_url);
const phoneURL=p=>new URLSearchParams(new URL(p.phone_url).hash.slice(1)).get("relay");
const relayHost=new URL(base).host;assert.equal(new URL(a.game_relay).host,relayHost);assert.equal(new URL(phoneURL(a)).host,relayHost);
const preflight=await fetch(base+"/api/pair",{method:"OPTIONS",headers:{Origin:website,"Access-Control-Request-Method":"POST"}});
assert.equal(preflight.status,204);assert.equal(preflight.headers.get("access-control-allow-origin"),website);
assert.equal((await fetch(base+"/api/pair",{method:"POST",headers:{Origin:"https://evil.example"}})).status,403);
const foreign=new WebSocket(phoneURL(a),{origin:"https://evil.example"});await new Promise(resolve=>foreign.on("error",resolve));
const ga=await connect(a.game_relay,"game"),gb=await connect(b.game_relay,"game",website),pa=await connect(phoneURL(a),"stage_phone",website),pb=await connect(phoneURL(b),"stage_phone",website);
ga.send(JSON.stringify({kind:"keepalive"}));pa.send(JSON.stringify({kind:"keepalive"}));
ga.send(JSON.stringify({kind:"stage_cue",channel:"prompt",requestId:"a1",text:"A only",recipient:""}));
ga.send(JSON.stringify({kind:"stage_cue",channel:"ifb",requestId:"a2",text:"Private A",recipient:""}));
gb.send(JSON.stringify({kind:"stage_cue",channel:"prompt",requestId:"b1",text:"B only",recipient:""}));await wait();
assert.deepEqual(pa.messages.filter(x=>x.kind==="stage_cue").map(x=>x.text),["A only","Private A"]);assert.deepEqual(pb.messages.filter(x=>x.kind==="stage_cue").map(x=>x.text),["B only"]);
pa.send(JSON.stringify({kind:"stage_ack",requestId:"a1"}));await wait();assert(ga.messages.some(x=>x.kind==="stage_ack"&&x.requestId==="a1"));assert(!gb.messages.some(x=>x.requestId==="a1"));
const impersonator=await connect(phoneURL(a),"game");await wait();assert.equal(impersonator.readyState,WebSocket.CLOSED);
const invalid=new WebSocket(a.game_relay.replace(/token=.*/,"token=invalid"));await new Promise(resolve=>invalid.on("error",resolve));
pa.close();await wait();const reconnected=await connect(phoneURL(a),"stage_phone",website);await wait();assert.equal(reconnected.messages.filter(x=>x.kind==="stage_cue").length,2);
ga.close();await wait();assert.equal(reconnected.messages.filter(x=>x.kind==="stage_cancel").length,2);assert(!pb.messages.some(x=>x.kind==="stage_cancel"));
for(const ws of [gb,pa,pb,reconnected]) ws.close();
console.log(`PASS (relay ${base}, website ${website}): website phone links, relay addresses, CORS/origin checks, keep-alive, unique QR/session, room isolation, two channels, ACK isolation, role protection, invalid token, reconnect and disconnect clearing`);
