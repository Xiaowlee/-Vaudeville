import type { StageChannels, StageRelayStatus } from "../lib/stage-phone";

export type StagePreviewFixture = {
  relay: StageRelayStatus;
  cues: StageChannels;
};

const shortPrompt = "Halo\nevery\nnyan";
const shortPrivate = "Pause, then look across the stage.";
const longPrompt = Array.from({ length: 8 }, () =>
  "This preview line is only for layout. It is not a live cue. It checks that a long prompt wraps inside the reading area and can be scrolled without leaving the screen.",
).join(" ");
const longPrivate = Array.from({ length: 4 }, () =>
  "This preview note is only for layout. It is not a live private cue. Both regions should stay readable together.",
).join(" ");

const none: StageChannels = { prompt: null, ifb: null };

export const stagePreviewFixtures: Record<string, StagePreviewFixture> = {
  connecting: { relay: "connecting", cues: none },
  waiting: { relay: "open", cues: none },
  disconnected: { relay: "closed", cues: none },
  prompt: {
    relay: "open",
    cues: { prompt: { requestId: "preview-prompt", text: shortPrompt, cueType: "PROMPTER" }, ifb: null },
  },
  ifb: {
    relay: "open",
    cues: { prompt: null, ifb: { requestId: "preview-ifb", text: shortPrivate, cueType: "PRIVATE" } },
  },
  both: {
    relay: "open",
    cues: {
      prompt: { requestId: "preview-prompt", text: shortPrompt, cueType: "PROMPTER" },
      ifb: { requestId: "preview-ifb", text: shortPrivate, cueType: "PRIVATE" },
    },
  },
  long: {
    relay: "open",
    cues: { prompt: { requestId: "preview-long", text: longPrompt, cueType: "PROMPTER" }, ifb: null },
  },
  "long-both": {
    relay: "open",
    cues: {
      prompt: { requestId: "preview-long", text: longPrompt, cueType: "PROMPTER" },
      ifb: { requestId: "preview-long-ifb", text: longPrivate, cueType: "WARNING" },
    },
  },
};

export function stagePreviewFixture(name: string | null): StagePreviewFixture {
  if (name && stagePreviewFixtures[name]) return stagePreviewFixtures[name];
  return stagePreviewFixtures.waiting;
}
