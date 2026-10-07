export function installProtocol(wss) {
// One local game and phone; retain only the current request, never face success.
// Stage cues are retained per channel so a prompt and a private IFB never replace each other.
const STAGE_CHANNELS = ["prompt", "ifb"];
let game = null;
let request = null;
let speechTurn = null;
const speechClients = () => [...wss.clients].filter(c => c.role === "speech_client" && c.readyState === 1);
const tellSpeech = message => { for (const c of speechClients()) send(c,message); };
const stageCues = {prompt: null, ifb: null};
function stagePhones() { return [...wss.clients].filter(c => c.role === "stage_phone" && c.readyState === 1); }
function matchesStage(phone, cue) { return !!cue && (!cue.recipient || cue.recipient === phone.recipient); }
function clearStage(channel) {
  for (const name of channel ? [channel] : STAGE_CHANNELS) {
    const cue = stageCues[name];
    if (!cue) continue;
    for (const phone of stagePhones()) send(phone, {kind:"stage_cancel", channel:name, requestId:cue.requestId});
    console.log(`[relay] cleared ${name} cue ${cue.requestId}`);
    stageCues[name] = null;
  }
}
function phones() { return [...wss.clients].filter(c => c.role === "phone" && c.readyState === 1); }
function send(client, message) { if (client?.readyState === 1) client.send(JSON.stringify(message)); }
function stageStatus() {
  const all = stagePhones();
  const acknowledged = [];
  for (const name of STAGE_CHANNELS) {
    const cue = stageCues[name];
    if (cue && all.some(p => matchesStage(p, cue) && p.stageAcks?.has(cue.requestId))) acknowledged.push(cue.requestId);
  }
  send(game, {kind:"stage_phone_status", connected:all.length > 0, acknowledged});
}
function phoneStatus() { send(game, {kind: "phone_status", connected: phones().length > 0}); stageStatus(); }
const heartbeat = setInterval(() => {
  for (const client of wss.clients) {
    if (client.isAlive === false) { client.terminate(); continue; }
    client.isAlive = false;
    client.ping();
  }
  stageStatus();
}, 3000);
wss.on("close", () => clearInterval(heartbeat));
wss.on("connection", (socket, req) => {
  socket.address = req.socket.remoteAddress ?? "unknown";
  socket.isAlive = true;
  socket.on("pong", () => { socket.isAlive = true; });
  socket.on("message", data => {
    let message;
    try { message = JSON.parse(data.toString()); } catch { return; }
    if (!message || typeof message !== "object") return;
    if (message.kind === "hello") {
      if (socket.role || (socket.allowedRole && message.role !== socket.allowedRole)) { socket.close(1008, "Invalid role"); return; }
      if (message.role === "game") {
        if (game && game !== socket) { tellSpeech({type:"speech_control",action:"stop",session_id:speechTurn?.session_id}); speechTurn=null; game.close(); }
        clearStage();
        console.log(`[relay] game connected ${socket.address}`);
        game = socket;
        socket.role = "game";
        request = null;
      } else if (message.role === "speech_client") {
        if (speechClients().length) { socket.close(1008, "One speech tester per session"); return; }
        socket.role = "speech_client";
        send(socket, {type:"speech_status", status:"connected"});
        if (speechTurn) send(socket, speechTurn);
      } else if (message.role === "stage_phone") {
        socket.role = "stage_phone";
        socket.recipient = typeof message.recipient === "string" ? message.recipient : "";
        socket.stageAcks = new Set();
        console.log("[relay] stage phone connected");
        for (const name of STAGE_CHANNELS) if (matchesStage(socket, stageCues[name])) send(socket, stageCues[name]);
      } else if (message.role === "phone") {
        socket.role = "phone";
        if (request) send(socket, request);
      }
      phoneStatus();
    } else if (socket === game) {
      if (message.type === "speech_control") {
        if (typeof message.session_id !== "string" || !["start","stop"].includes(message.action)) return;
        speechTurn = message.action === "start" ? message : null;
        tellSpeech(message); return;
      }
      if (["speech_observation","speech_attempt"].includes(message.type)) { tellSpeech(message); return; }
      if (message.kind === "stage_cue") {
        if (typeof message.requestId !== "string" || typeof message.text !== "string" || typeof message.recipient !== "string") return;
        const channel = STAGE_CHANNELS.includes(message.channel) ? message.channel : "ifb";
        clearStage(channel);
        const cue = {kind:"stage_cue", channel, requestId:message.requestId, text:message.text, recipient:message.recipient, cueType:["PROMPTER","PRIVATE","SCRIPT_UPDATE","WARNING"].includes(message.cueType) ? message.cueType : "PRIVATE"};
        stageCues[channel] = cue;
        const targets = stagePhones().filter(phone => matchesStage(phone, cue));
        for (const phone of targets) send(phone, cue);
        console.log(`[relay] ${channel} cue ${cue.requestId} forwarded to ${targets.length} stage phone(s)`);
        stageStatus();
        return;
      }
      if (message.kind === "stage_cancel") {
        for (const name of STAGE_CHANNELS) if (stageCues[name] && message.requestId === stageCues[name].requestId) clearStage(name);
        return;
      }
      if (message.kind === "face_request" && typeof message.requestId === "string" && message.cue === "smile") request = message;
      else if (message.kind === "face_cancel" && message.requestId === request?.requestId) request = null;
      else if (message.kind !== "face_ack") return;
      for (const phone of phones()) send(phone, message);
    } else if (socket.role === "speech_client") {
      if (!speechTurn || message.session_id !== speechTurn.session_id || message.source !== "web_speech") return;
      if (!["speech_result","speech_status","speech_error"].includes(message.type)) return;
      if (message.type === "speech_result" && (typeof message.transcript !== "string" || typeof message.is_final !== "boolean" || !Array.isArray(message.alternatives) || message.alternatives.length > 3)) return;
      if (message.type === "speech_result" && message.alternatives.some(a => !a || typeof a.transcript !== "string" || (a.confidence !== null && (typeof a.confidence !== "number" || !Number.isFinite(a.confidence))))) return;
      send(game, message);
    } else if (socket.role === "stage_phone") {
      const cue = STAGE_CHANNELS.map(name => stageCues[name]).find(c => c && c.requestId === message.requestId);
      if (message.kind === "stage_ack" && cue && matchesStage(socket, cue)) {
        socket.stageAcks.add(cue.requestId);
        send(game, {kind:"stage_ack", channel:cue.channel, requestId:cue.requestId});
        stageStatus();
      }
    } else if (socket.role === "phone") {
      if (message.kind === "face_present" && typeof message.present === "boolean") send(game, message);
      if (message.kind === "face_cue" && request && message.requestId === request.requestId && message.cue === request.cue && message.met === true) send(game, message);
    }
  });
  socket.on("error", error => console.error("[relay] socket error", error.message));
  socket.on("close", () => {
    if (socket === game) {
      console.log("[relay] game disconnected; clearing stage cues");
      clearStage();
      for (const phone of phones()) send(phone, {kind: "face_cancel", requestId: request?.requestId});
      game = null;
      request = null;
      tellSpeech({type:"speech_control",action:"stop",session_id:speechTurn?.session_id});
      speechTurn = null;
    }
    if (socket.role === "speech_client" && speechTurn) send(game,{type:"speech_error",source:"web_speech",session_id:speechTurn.session_id,error:"browser_disconnected",recoverable:true});
    if (socket.role === "stage_phone") console.log(`[relay] stage phone disconnected ${socket.address}`);
    phoneStatus();
  });
});

}
