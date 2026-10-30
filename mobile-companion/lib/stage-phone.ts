/**
 * Browser-side rules for the stage phone. These follow Script/StageActs/mobile_display.gd
 * and Script/phone_cue_bridge.gd. An acknowledgement means the cue reached this page.
 * It does not mean the line was performed.
 */

export const STAGE_RELAY_PORT = 8787;
export const STAGE_RECONNECT_MS = 2000;
export const STAGE_KEEPALIVE_MS = 60_000;

const EXPRESSIONS = [
  "Default",
  "Waiting",
  "Cue",
  "Accept",
  "Confused",
  "Angry",
  "Menancing",
  "Unexpected",
  "Disappointed",
  "Speaking",
  "Speech",
] as const;

export type StageManagerExpression = (typeof EXPRESSIONS)[number];

export type StageChannelName = "prompt" | "ifb";

export type StagePresentationRequest = {
  expression?: StageManagerExpression | null;
  talking?: boolean | null;
  dialogueBoundary?: boolean;
};

export type StageCue = {
  requestId: string;
  text: string;
  cueType: string;
  expression?: StageManagerExpression;
  talking?: boolean;
  dialogueBoundary?: boolean;
};

export type StageChannels = {
  prompt: StageCue | null;
  ifb: StageCue | null;
};

export type StageRelayStatus = "idle" | "connecting" | "open" | "closed" | "error";

export type StageView = "connecting" | "waiting" | "disconnected" | "cues";

const CHANNELS: readonly StageChannelName[] = ["prompt", "ifb"];

export function emptyStageChannels(): StageChannels {
  return { prompt: null, ifb: null };
}

export function emptyStagePresentation() {
  return { expression: "Default" as StageManagerExpression, talking: false };
}

export function stageHello(recipient: string) {
  return { kind: "hello" as const, role: "stage_phone" as const, recipient };
}

export function stageKeepalive() {
  return { kind: "keepalive" as const };
}

export function stageAck(requestId: string) {
  return { kind: "stage_ack" as const, requestId };
}

/**
 * Pairing URLs look like /stage#relay=<encoded socket address>.
 * Accept the same addresses the Godot phone accepts, and use the same local fallback.
 */
export function resolveStageRelayUrl(hash: string, hostname: string): string {
  const body = hash.startsWith("#") ? hash.slice(1) : hash;
  const paired = new URLSearchParams(body).get("relay") ?? "";
  if (paired.startsWith("wss://") || paired.startsWith("ws://localhost:")) {
    return paired;
  }
  const host = hostname.trim() || "127.0.0.1";
  return `wss://${host}:${STAGE_RELAY_PORT}`;
}

export function resolveStageRecipient(search: string): string {
  const body = search.startsWith("?") ? search.slice(1) : search;
  return new URLSearchParams(body).get("recipient") ?? "";
}

function channelOf(value: unknown): StageChannelName | null {
  if (value === undefined) return "ifb";
  if (value === "prompt" || value === "ifb") return value;
  return null;
}

function isStageManagerExpression(value: unknown): value is StageManagerExpression {
  return typeof value === "string" && (EXPRESSIONS as readonly string[]).includes(value);
}

function presentationFields(raw: Record<string, unknown>): StagePresentationRequest | null {
  const request: StagePresentationRequest = {};
  let useful = false;
  if (isStageManagerExpression(raw.expression)) {
    request.expression = raw.expression;
    useful = true;
  }
  if (typeof raw.talking === "boolean") {
    request.talking = raw.talking;
    useful = true;
  }
  if (raw.dialogueBoundary === true) {
    request.dialogueBoundary = true;
    useful = true;
  }
  return useful ? request : null;
}

export function applyStageMessage(
  state: StageChannels,
  message: unknown,
): {
  state: StageChannels;
  ackRequestId: string | null;
  presentation: StagePresentationRequest | null;
} {
  if (!message || typeof message !== "object") {
    return { state, ackRequestId: null, presentation: null };
  }
  const kind = (message as { kind?: unknown }).kind;
  const raw = message as Record<string, unknown>;

  if (kind === "stage_presentation") {
    return { state, ackRequestId: null, presentation: presentationFields(raw) };
  }

  if (kind === "stage_cue") {
    const channel = channelOf(raw.channel);
    if (!channel) return { state, ackRequestId: null, presentation: null };
    if (typeof raw.requestId !== "string" || raw.requestId.length === 0) {
      return { state, ackRequestId: null, presentation: null };
    }
    if (typeof raw.text !== "string") return { state, ackRequestId: null, presentation: null };
    const cueType = typeof raw.cueType === "string" ? raw.cueType : "";
    const cue: StageCue = { requestId: raw.requestId, text: raw.text, cueType };
    const presentation = presentationFields(raw);
    if (presentation?.expression) cue.expression = presentation.expression;
    if (typeof presentation?.talking === "boolean") cue.talking = presentation.talking;
    if (presentation?.dialogueBoundary) cue.dialogueBoundary = true;
    return {
      state: { ...state, [channel]: cue },
      ackRequestId: raw.requestId,
      presentation,
    };
  }

  if (kind === "stage_cancel") {
    const requestId = raw.requestId;
    if (typeof requestId !== "string" || requestId.length === 0) {
      return { state, ackRequestId: null, presentation: null };
    }
    let prompt = state.prompt;
    let ifb = state.ifb;
    if (prompt?.requestId === requestId) prompt = null;
    if (ifb?.requestId === requestId) ifb = null;
    if (prompt === state.prompt && ifb === state.ifb) {
      return { state, ackRequestId: null, presentation: null };
    }
    return { state: { prompt, ifb }, ackRequestId: null, presentation: null };
  }

  return { state, ackRequestId: null, presentation: null };
}

export function stageView(relay: StageRelayStatus, cues: StageChannels): StageView {
  const showing = CHANNELS.some((channel) => {
    const cue = cues[channel];
    return cue !== null && cue.text !== "";
  });
  if (showing) return "cues";
  if (relay === "open") return "waiting";
  if (relay === "closed" || relay === "error") return "disconnected";
  return "connecting";
}

/** Allowlisted sound controls; never accept a remote audio URL from the relay. */
export function parseStageSound(message: unknown): { sound: "tea" | "suspense" | "all"; action: "play" | "stop"; volumeDb: number; requestId: string } | null {
  if (!message || typeof message !== "object") return null;
  const raw = message as Record<string, unknown>;
  if (raw.kind !== "stage_sound" || !["tea", "suspense", "all"].includes(String(raw.sound))) return null;
  if (raw.action !== "play" && raw.action !== "stop") return null;
  if (raw.sound === "all" && raw.action !== "stop") return null;
  if (typeof raw.requestId !== "string" || !raw.requestId) return null;
  if (typeof raw.volumeDb !== "number" || !Number.isFinite(raw.volumeDb)) return null;
  return { sound: raw.sound as "tea" | "suspense" | "all", action: raw.action, volumeDb: Math.max(-60, Math.min(0, raw.volumeDb)), requestId: raw.requestId };
}
