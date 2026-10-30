import assert from "node:assert/strict";
import test from "node:test";
import { artCropStyle, railBounds } from "../components/stage-frame-settings.ts";
import {
  applyStageMessage,
  parseStageSound,
  emptyStageChannels,
  resolveStageRecipient,
  resolveStageRelayUrl,
  stageAck,
  stageHello,
  stageKeepalive,
  stageView,
} from "./stage-phone.ts";

const channels = emptyStageChannels();

test("pairing fragment keeps a token-scoped socket address", () => {
  const socket = "wss://relay.example/socket?room=green&token=secret";
  const hash = `#relay=${encodeURIComponent(socket)}`;
  assert.equal(resolveStageRelayUrl(hash, "phone.example"), socket);
});

test("local insecure sockets are accepted only for localhost", () => {
  assert.equal(resolveStageRelayUrl("#relay=ws://localhost:8787", "10.0.0.4"), "ws://localhost:8787");
  assert.equal(resolveStageRelayUrl("#relay=ws://127.0.0.1:8787", "10.0.0.4"), "wss://10.0.0.4:8787");
  assert.equal(resolveStageRelayUrl("", "10.0.0.4"), "wss://10.0.0.4:8787");
  assert.equal(resolveStageRelayUrl("#other=1", ""), "wss://127.0.0.1:8787");
});

test("recipient comes from the page query and is sent with the phone hello", () => {
  assert.equal(resolveStageRecipient("?recipient=north"), "north");
  assert.equal(resolveStageRecipient(""), "");
  assert.deepEqual(stageHello("north"), { kind: "hello", role: "stage_phone", recipient: "north" });
  assert.deepEqual(stageKeepalive(), { kind: "keepalive" });
  assert.deepEqual(stageAck("p1"), { kind: "stage_ack", requestId: "p1" });
});

test("prompt and private cues stay independent and each is acknowledged", () => {
  const prompt = applyStageMessage(channels, {
    kind: "stage_cue",
    channel: "prompt",
    requestId: "p1",
    text: "Say the line.",
    cueType: "PROMPTER",
    expression: "Cue",
    dialogueBoundary: true,
  });
  const both = applyStageMessage(prompt.state, {
    kind: "stage_cue",
    channel: "ifb",
    requestId: "i1",
    text: "Look across.",
    cueType: "PRIVATE",
  });
  assert.equal(prompt.ackRequestId, "p1");
  assert.equal(prompt.presentation?.expression, "Cue");
  assert.equal(both.ackRequestId, "i1");
  assert.equal(both.state.prompt?.requestId, "p1");
  assert.equal(both.state.ifb?.text, "Look across.");
  assert.equal(stageView("open", both.state), "cues");
});

test("optional presentation messages do not change cue channels", () => {
  const withCue = applyStageMessage(channels, {
    kind: "stage_cue",
    channel: "prompt",
    requestId: "p1",
    text: "Say the line.",
    cueType: "PROMPTER",
  });
  const posed = applyStageMessage(withCue.state, {
    kind: "stage_presentation",
    expression: "Waiting",
    talking: false,
    dialogueBoundary: true,
  });
  assert.equal(posed.state, withCue.state);
  assert.equal(posed.ackRequestId, null);
  assert.deepEqual(posed.presentation, {
    expression: "Waiting",
    talking: false,
    dialogueBoundary: true,
  });
});

test("a missing channel is the private cue, and an unknown channel is ignored", () => {
  const assumed = applyStageMessage(channels, { kind: "stage_cue", requestId: "i2", text: "Private." });
  assert.equal(assumed.state.ifb?.requestId, "i2");
  assert.equal(assumed.state.prompt, null);
  const ignored = applyStageMessage(assumed.state, {
    kind: "stage_cue",
    channel: "face",
    requestId: "x",
    text: "no",
  });
  assert.equal(ignored.ackRequestId, null);
  assert.equal(ignored.state, assumed.state);
});

test("cancel clears only the matching request", () => {
  const both = {
    prompt: { requestId: "p2", text: "Second prompt", cueType: "PROMPTER" },
    ifb: { requestId: "i1", text: "Still private", cueType: "PRIVATE" },
  };
  const stale = applyStageMessage(both, { kind: "stage_cancel", requestId: "p1" });
  assert.equal(stale.state, both);
  const cleared = applyStageMessage(both, { kind: "stage_cancel", requestId: "p2" });
  assert.equal(cleared.state.prompt, null);
  assert.equal(cleared.state.ifb?.requestId, "i1");
  assert.equal(cleared.ackRequestId, null);
});

test("replacing a cue leaves a later cancel of the old id alone", () => {
  const first = applyStageMessage(channels, {
    kind: "stage_cue",
    channel: "prompt",
    requestId: "p1",
    text: "First",
  });
  const second = applyStageMessage(first.state, {
    kind: "stage_cue",
    channel: "prompt",
    requestId: "p2",
    text: "Second",
  });
  const late = applyStageMessage(second.state, { kind: "stage_cancel", requestId: "p1" });
  assert.equal(late.state.prompt?.text, "Second");
});

test("disconnect clears the view even if cues were showing", () => {
  const showing = {
    prompt: { requestId: "p1", text: "Line", cueType: "PROMPTER" },
    ifb: null,
  };
  assert.equal(stageView("open", showing), "cues");
  assert.equal(stageView("open", channels), "waiting");
  assert.equal(stageView("closed", channels), "disconnected");
  assert.equal(stageView("error", showing), "cues");
  assert.equal(stageView("connecting", channels), "connecting");
  assert.equal(stageView("open", { prompt: { requestId: "p", text: "", cueType: "" }, ifb: null }), "waiting");
});

test("ornament crops ignore transparent padding", () => {
  const top = artCropStyle({ x: 0, y: 0, right: 1080, bottom: 361 }, 1080, 2400);
  assert.equal(top.left, "0%");
  assert.equal(top.top, "0%");
  assert.equal(top.width, "100%");
  const bottom = artCropStyle({ x: 0, y: 2024, right: 1080, bottom: 2387 }, 1080, 2400);
  assert.ok(Math.abs(Number.parseFloat(bottom.top) + (2024 / 363) * 100) < 0.001);
  const right = railBounds("right");
  assert.equal(right.x, 1006);
  assert.equal(right.right, 1080);
  const crop = artCropStyle(right, 1080, 2400);
  assert.ok(Number.parseFloat(crop.left) < 0);
});

test("phone sound accepts only named assets and bounded volumes", () => {
  const command = {kind:"stage_sound", sound:"tea", action:"play", volumeDb:-22, requestId:"sound_1"};
  assert.equal(parseStageSound(command)?.sound, "tea");
  assert.equal(parseStageSound({...command, volumeDb:8})?.volumeDb, 0);
  assert.equal(parseStageSound({...command, volumeDb:-90})?.volumeDb, -60);
  assert.equal(parseStageSound({...command, sound:"https://elsewhere/audio.mp3"}), null);
  assert.equal(parseStageSound({...command, sound:"all"}), null);
  assert.equal(parseStageSound({...command, volumeDb:NaN}), null);
  assert.equal(parseStageSound({...command, action:"stop", sound:"all"})?.action, "stop");
});
