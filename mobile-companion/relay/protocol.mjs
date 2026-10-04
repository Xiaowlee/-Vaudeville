export function installProtocol(wss) {
// One local game and phone; retain only the current request, never face success.
// Stage cues are retained per channel so a prompt and a private IFB never replace each other.
const STAGE_CHANNELS = ["prompt", "ifb"];
let game = null;
let request = null;
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
        if (game && game !== socket) game.close();
        clearStage();
        console.log(`[relay] game connected ${socket.address}`);
        game = socket;
        socket.role = "game";
        request = null;
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
    }
    if (socket.role === "stage_phone") console.log(`[relay] stage phone disconnected ${socket.address}`);
    phoneStatus();
  });
});

}
