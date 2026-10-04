// Synthetic check of the prompt / IFB stage channels. Run with the relay started: node test-stage-channels.cjs
const WebSocket = require("ws");
const url = process.env.RELAY_URL || "wss://127.0.0.1:8787";
const wait = ms => new Promise(r => setTimeout(r, ms));
let failures = 0;
function check(label, ok) { console.log(`${ok ? "PASS" : "FAIL"} ${label}`); if (!ok) failures++; }
function client(role, extra = {}) {
  return new Promise(resolve => {
    const ws = new WebSocket(url, {rejectUnauthorized: false});
    ws.inbox = [];
    ws.on("message", d => ws.inbox.push(JSON.parse(d.toString())));
    ws.on("open", () => { ws.send(JSON.stringify({kind: "hello", role, ...extra})); resolve(ws); });
  });
}
const send = (ws, m) => ws.send(JSON.stringify(m));
const take = (ws, kind) => { const found = ws.inbox.filter(m => m.kind === kind); ws.inbox = ws.inbox.filter(m => m.kind !== kind); return found; };

(async () => {
  const game = await client("game");
  const phone = await client("stage_phone", {recipient: ""});
  await wait(200);
  send(game, {kind: "stage_cue", channel: "prompt", requestId: "p1", recipient: "", text: "Say: I am here.", cueType: "PROMPTER"});
  send(game, {kind: "stage_cue", channel: "ifb", requestId: "i1", recipient: "", text: "Look at the mother.", cueType: "PRIVATE"});
  await wait(300);
  const cues = take(phone, "stage_cue");
  check("phone receives prompt on prompt channel", cues.some(c => c.channel === "prompt" && c.text === "Say: I am here."));
  check("phone receives IFB on ifb channel", cues.some(c => c.channel === "ifb" && c.text === "Look at the mother."));
  for (const c of cues) send(phone, {kind: "stage_ack", requestId: c.requestId});
  await wait(300);
  const acks = take(game, "stage_ack");
  check("game receives per-channel acks", acks.some(a => a.requestId === "p1" && a.channel === "prompt") && acks.some(a => a.requestId === "i1" && a.channel === "ifb"));
  const status = take(game, "stage_phone_status").pop();
  check("status lists both acknowledged requests", status && status.connected && status.acknowledged.includes("p1") && status.acknowledged.includes("i1"));

  send(game, {kind: "stage_cancel", channel: "prompt", requestId: "p1"});
  await wait(300);
  const cancels = take(phone, "stage_cancel");
  check("cancelling prompt only clears prompt", cancels.length === 1 && cancels[0].requestId === "p1");

  send(game, {kind: "stage_cue", channel: "prompt", requestId: "p2", recipient: "", text: "Second prompt", cueType: "PROMPTER"});
  await wait(300);
  check("new prompt does not cancel IFB", !take(phone, "stage_cancel").some(c => c.requestId === "i1"));
  send(game, {kind: "stage_cancel", channel: "prompt", requestId: "p2"});
  await wait(200);

  phone.close();
  await wait(300);
  const phone2 = await client("stage_phone", {recipient: ""});
  await wait(300);
  const resent = take(phone2, "stage_cue");
  check("reconnect shows only the active IFB", resent.length === 1 && resent[0].requestId === "i1");

  const facePhone = await client("phone");
  send(game, {kind: "face_request", requestId: "f1", cue: "smile"});
  await wait(300);
  check("face protocol still forwards face_request", take(facePhone, "face_request").some(m => m.requestId === "f1"));
  check("stage phone does not receive face messages", take(phone2, "face_request").length === 0);

  game.close();
  await wait(400);
  check("game disconnect clears active IFB on phone", take(phone2, "stage_cancel").some(c => c.requestId === "i1"));
  phone2.close(); facePhone.close();
  console.log(failures ? `${failures} failure(s)` : "All stage channel checks passed");
  process.exit(failures ? 1 : 0);
})();
