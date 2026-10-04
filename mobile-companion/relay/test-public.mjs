import assert from "node:assert/strict";
import {WebSocket} from "ws";
const base="http://localhost:3100";
async function pair(){const r=await fetch(base+"/api/pair",{method:"POST"});assert.equal(r.status,201);return r.json();}
async function connect(url,role){const ws=new WebSocket(url);ws.messages=[];ws.on("message",x=>ws.messages.push(JSON.parse(x)));await new Promise((ok,no)=>{ws.once("open",ok);ws.once("error",no);});ws.send(JSON.stringify({kind:"hello",role}));return ws;}
const wait=()=>new Promise(r=>setTimeout(r,150));
const a=await pair(),b=await pair();assert.notEqual(a.phone_url,b.phone_url);assert(a.qr_svg.startsWith("<svg"));
const phoneURL=p=>new URLSearchParams(new URL(p.phone_url).hash.slice(1)).get("relay");
const ga=await connect(a.game_relay,"game"),gb=await connect(b.game_relay,"game"),pa=await connect(phoneURL(a),"stage_phone"),pb=await connect(phoneURL(b),"stage_phone");
ga.send(JSON.stringify({kind:"stage_cue",channel:"prompt",requestId:"a1",text:"A only",recipient:""}));
ga.send(JSON.stringify({kind:"stage_cue",channel:"ifb",requestId:"a2",text:"Private A",recipient:""}));
gb.send(JSON.stringify({kind:"stage_cue",channel:"prompt",requestId:"b1",text:"B only",recipient:""}));await wait();
assert.deepEqual(pa.messages.filter(x=>x.kind==="stage_cue").map(x=>x.text),["A only","Private A"]);assert.deepEqual(pb.messages.filter(x=>x.kind==="stage_cue").map(x=>x.text),["B only"]);
pa.send(JSON.stringify({kind:"stage_ack",requestId:"a1"}));await wait();assert(ga.messages.some(x=>x.kind==="stage_ack"&&x.requestId==="a1"));assert(!gb.messages.some(x=>x.requestId==="a1"));
const impersonator=await connect(phoneURL(a),"game");await wait();assert.equal(impersonator.readyState,WebSocket.CLOSED);
const invalid=new WebSocket(a.game_relay.replace(/token=.*/,"token=invalid"));await new Promise(resolve=>invalid.on("error",resolve));
pa.close();await wait();const reconnected=await connect(phoneURL(a),"stage_phone");await wait();assert.equal(reconnected.messages.filter(x=>x.kind==="stage_cue").length,2);
ga.close();await wait();assert.equal(reconnected.messages.filter(x=>x.kind==="stage_cancel").length,2);assert(!pb.messages.some(x=>x.kind==="stage_cancel"));
for(const ws of [gb,pa,pb,reconnected]) ws.close();
console.log("PASS: unique QR/session, room isolation, two channels, ACK isolation, role protection, invalid token, reconnect and disconnect clearing");
