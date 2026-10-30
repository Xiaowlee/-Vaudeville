import type { StageChannels, StageRelayStatus } from "../lib/stage-phone";
import type { StampedPresentation } from "./stage-manager-puppet";

export type StagePreviewFixture = {
  relay: StageRelayStatus;
  cues: StageChannels;
  presentation: StampedPresentation;
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

function pose(
  expression: StampedPresentation["expression"],
  extras: Partial<StampedPresentation> = {},
): StampedPresentation {
  return {
    expression,
    talking: false,
    dialogueBoundary: true,
    sequence: 1,
    ...extras,
  };
}

export const stagePreviewFixtures: Record<string, StagePreviewFixture> = {
  connecting: { relay: "connecting", cues: none, presentation: pose("Default", { dialogueBoundary: false }) },
  waiting: { relay: "open", cues: none, presentation: pose("Waiting") },
  disconnected: { relay: "closed", cues: none, presentation: pose("Default") },
  prompt: {
    relay: "open",
    cues: { prompt: { requestId: "preview-prompt", text: shortPrompt, cueType: "PROMPTER" }, ifb: null },
    presentation: pose("Cue"),
  },
  ifb: {
    relay: "open",
    cues: { prompt: null, ifb: { requestId: "preview-ifb", text: shortPrivate, cueType: "PRIVATE" } },
    presentation: pose("Cue"),
  },
  both: {
    relay: "open",
    cues: {
      prompt: { requestId: "preview-prompt", text: shortPrompt, cueType: "PROMPTER" },
      ifb: { requestId: "preview-ifb", text: shortPrivate, cueType: "PRIVATE" },
    },
    presentation: pose("Cue"),
  },
  long: {
    relay: "open",
    cues: { prompt: { requestId: "preview-long", text: longPrompt, cueType: "PROMPTER" }, ifb: null },
    presentation: pose("Cue"),
  },
  "long-both": {
    relay: "open",
    cues: {
      prompt: { requestId: "preview-long", text: longPrompt, cueType: "PROMPTER" },
      ifb: { requestId: "preview-long-ifb", text: longPrivate, cueType: "WARNING" },
    },
    presentation: pose("Cue"),
  },
  accept: { relay: "open", cues: none, presentation: pose("Accept") },
  confused: { relay: "open", cues: none, presentation: pose("Confused") },
  angry: { relay: "open", cues: none, presentation: pose("Angry") },
  menancing: { relay: "open", cues: none, presentation: pose("Menancing") },
  unexpected: { relay: "open", cues: none, presentation: pose("Unexpected") },
  speaking: { relay: "open", cues: none, presentation: pose("Speaking", { talking: true }) },
};

export function stagePreviewFixture(name: string | null): StagePreviewFixture {
  if (name && stagePreviewFixtures[name]) return stagePreviewFixtures[name];
  return stagePreviewFixtures.waiting;
}
