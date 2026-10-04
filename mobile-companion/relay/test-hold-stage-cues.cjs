// Synthetic game for a manual/browser look at the phone display: holds one prompt and one IFB active.
// Run with the relay started: node test-hold-stage-cues.cjs [seconds]
const WebSocket = require("ws");
const seconds = Number(process.argv[2] || 60);
const ws = new WebSocket(process.env.RELAY_URL || "wss://127.0.0.1:8787", {rejectUnauthorized: false});
ws.on("open", () => {
  ws.send(JSON.stringify({kind: "hello", role: "game"}));
  ws.send(JSON.stringify({kind: "stage_cue", channel: "ifb", requestId: "hold_ifb", recipient: "", text: "Private: look at the mother before you answer.", cueType: "PRIVATE"}));
  ws.send(JSON.stringify({kind: "stage_cue", channel: "prompt", requestId: "hold_prompt", recipient: "", text: "Say: I am here.", cueType: "PROMPTER"}));
  console.log(`holding prompt + IFB for ${seconds}s`);
  setTimeout(() => { ws.close(); process.exit(0); }, seconds * 1000);
});
ws.on("message", d => console.log("relay:", d.toString()));
