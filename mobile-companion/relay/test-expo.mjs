import assert from "node:assert/strict";
import {WebSocket, WebSocketServer} from "ws";
import {installProtocol} from "./protocol.mjs";
const server=new WebSocketServer({port:0,host:"127.0.0.1"});
installProtocol(server);
await new Promise(resolve=>server.once("listening",resolve));
const url=`ws://127.0.0.1:${server.address().port}`;
const sockets=[];
const wait=()=>new Promise(resolve=>setTimeout(resolve,90));
async function connect(role){
 const socket=new WebSocket(url);socket.messages=[];sockets.push(socket);
 socket.on("message",data=>socket.messages.push(JSON.parse(data.toString())));
 await new Promise((resolve,reject)=>{socket.once("open",resolve);socket.once("error",reject);});
 socket.send(JSON.stringify({kind:"hello",role}));await wait();return socket;
}
const send=(socket,message)=>socket.send(JSON.stringify(message));
try {
 const phone=await connect("stage_phone");
 assert(phone.messages.some(x=>x.kind==="stage_game_connection" && x.connected===false));
 const game=await connect("game");
 assert(phone.messages.some(x=>x.kind==="stage_game_connection" && x.connected===true));
 send(game,{kind:"stage_presentation",expression:"Waiting",managerVisible:false,talking:false});await wait();
 assert(phone.messages.some(x=>x.kind==="stage_presentation" && x.managerVisible===false));
 send(game,{kind:"stage_presentation",expression:"Cue",managerVisible:true,talking:false});
 send(game,{kind:"stage_cue",channel:"prompt",requestId:"full-turn",recipient:"",text:"I want to become a writer",cueType:"PROMPTER"});await wait();
 const other=await connect("stage_phone");
 assert(other.messages.some(x=>x.kind==="stage_cue" && x.requestId==="full-turn"));
 assert(other.messages.some(x=>x.kind==="stage_presentation" && x.managerVisible===true));
 send(phone,{kind:"stage_presentation",managerVisible:false});await wait();
 assert(!other.messages.some(x=>x.kind==="stage_presentation" && x.managerVisible===false));
 game.close();await wait();
 assert.equal(other.messages.filter(x=>x.kind==="stage_game_connection").at(-1).connected,false);
 const reconnected=await connect("stage_phone");
 assert(!reconnected.messages.some(x=>x.kind==="stage_cue"));
 assert.equal(reconnected.messages.filter(x=>x.kind==="stage_game_connection").at(-1).connected,false);
 console.log("RESULT Expo relay: connection, pre-show hiding, cue replay, no phone injection, disconnect cleanup passed");
} finally {
 for(const socket of sockets)socket.terminate();
 await new Promise(resolve=>server.close(resolve));
}
