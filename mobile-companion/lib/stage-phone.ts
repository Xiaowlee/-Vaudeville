/**
 * Browser-side rules for the stage phone. These follow Script/StageActs/mobile_display.gd.
 * An acknowledgement means the cue reached this page. It does not mean the line was performed.
 */

export const STAGE_RELAY_PORT = 8787;
export const STAGE_RECONNECT_MS = 2000;
export const STAGE_KEEPALIVE_MS = 60_000;

export type StageChannelName = "prompt" | "ifb";

export type StageCue = {
  requestId: string;
  text: string;
  cueType: string;
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

export function applyStageMessage(
  state: StageChannels,
  message: unknown,
): { state: StageChannels; ackRequestId: string | null } {
  if (!message || typeof message !== "object") return { state, ackRequestId: null };
  const kind = (message as { kind?: unknown }).kind;

  if (kind === "stage_cue") {
    const raw = message as { channel?: unknown; requestId?: unknown; text?: unknown; cueType?: unknown };
    const channel = channelOf(raw.channel);
    if (!channel) return { state, ackRequestId: null };
    if (typeof raw.requestId !== "string" || raw.requestId.length === 0) return { state, ackRequestId: null };
    if (typeof raw.text !== "string") return { state, ackRequestId: null };
    const cueType = typeof raw.cueType === "string" ? raw.cueType : "";
    return {
      state: {
        ...state,
        [channel]: { requestId: raw.requestId, text: raw.text, cueType },
      },
      ackRequestId: raw.requestId,
    };
  }

  if (kind === "stage_cancel") {
    const requestId = (message as { requestId?: unknown }).requestId;
    if (typeof requestId !== "string" || requestId.length === 0) return { state, ackRequestId: null };
    let prompt = state.prompt;
    let ifb = state.ifb;
    if (prompt?.requestId === requestId) prompt = null;
    if (ifb?.requestId === requestId) ifb = null;
    if (prompt === state.prompt && ifb === state.ifb) return { state, ackRequestId: null };
    return { state: { prompt, ifb }, ackRequestId: null };
  }

  return { state, ackRequestId: null };
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
