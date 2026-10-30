/** Named Stage Manager poses. Filenames keep the supplied spelling, including Menancing. */
export const STAGE_MANAGER_EXPRESSIONS = [
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

export type StageManagerExpression = (typeof STAGE_MANAGER_EXPRESSIONS)[number];

export type StagePresentation = {
  expression: StageManagerExpression;
  talking: boolean;
};

export type StagePresentationRequest = {
  expression?: StageManagerExpression | null;
  talking?: boolean | null;
  dialogueBoundary?: boolean;
  priority?: boolean;
};

export type StagePoseController = {
  shown: StageManagerExpression;
  pending: StageManagerExpression | null;
  talking: boolean;
  dialoguesSinceChange: number;
  pendingHold: number;
  flipping: boolean;
  flipFrom: StageManagerExpression;
  flipTo: StageManagerExpression | null;
};

export function isStageManagerExpression(value: unknown): value is StageManagerExpression {
  return typeof value === "string" && (STAGE_MANAGER_EXPRESSIONS as readonly string[]).includes(value);
}

export function emptyStagePresentation(): StagePresentation {
  return { expression: "Default", talking: false };
}

export function createPoseController(
  expression: StageManagerExpression = "Default",
  minDialogues = 2,
): StagePoseController {
  return {
    shown: expression,
    pending: null,
    talking: false,
    dialoguesSinceChange: Math.max(minDialogues, 2),
    pendingHold: 2,
    flipping: false,
    flipFrom: expression,
    flipTo: null,
  };
}

/**
 * Coalesce competing pose requests. Expression changes apply only at dialogue
 * boundaries after the current pose has been held long enough. Never chains a
 * second flip from flip completion alone.
 */
export function applyPoseRequest(
  state: StagePoseController,
  request: StagePresentationRequest,
  options: { minDialoguesPerPose: number; holdDialogues?: number } = { minDialoguesPerPose: 2 },
): StagePoseController {
  const minDialogues = Math.max(2, options.minDialoguesPerPose);
  const hold = Math.max(2, options.holdDialogues ?? minDialogues);
  let next: StagePoseController = { ...state };

  if (typeof request.talking === "boolean") next.talking = request.talking;

  if (request.expression && request.expression !== next.shown) {
    next.pending = request.expression;
    next.pendingHold = hold;
  } else if (request.expression && request.expression === next.shown) {
    next.pending = null;
  }

  if (request.priority && request.expression) {
    if (state.flipping && state.flipTo === request.expression) return next;
    if (request.expression === state.shown && !state.flipping) return { ...next, pending: null };
    // Readability and response poses must not wait for two unrelated dialogue events.
    return { ...next, flipping:true, flipFrom:state.shown, flipTo:request.expression, pending:null, dialoguesSinceChange:0 };
  }
  if (request.dialogueBoundary) {
    next.dialoguesSinceChange += 1;
    next = tryBeginFlip(next, minDialogues);
  }

  return next;
}

export function tryBeginFlip(state: StagePoseController, minDialoguesPerPose: number): StagePoseController {
  if (state.flipping) return state;
  const needed = Math.max(minDialoguesPerPose, state.pendingHold);
  if (state.dialoguesSinceChange < needed) return state;
  if (!state.pending || state.pending === state.shown) return state;
  return {
    ...state,
    flipping: true,
    flipFrom: state.shown,
    flipTo: state.pending,
    pending: null,
    dialoguesSinceChange: 0,
    pendingHold: 2,
  };
}

/** Midpoint of a width-collapse flip: swap the visible artwork. */
export function swapFlipPose(state: StagePoseController): StagePoseController {
  if (!state.flipping || !state.flipTo) return state;
  return { ...state, shown: state.flipTo };
}

/** End of flip. Does not start another flip. */
export function completeFlip(state: StagePoseController): StagePoseController {
  if (!state.flipping) return state;
  const shown = state.flipTo ?? state.shown;
  return {
    ...state,
    shown,
    flipping: false,
    flipFrom: shown,
    flipTo: null,
  };
}

export function presentationFromController(state: StagePoseController): StagePresentation {
  return { expression: state.shown, talking: state.talking };
}

/** Functional card pose wins over idle/speaking updates; reactions briefly hide the card. */
export function phoneDisplayPresentation(
  hasCue: boolean,
  latest: StagePresentationRequest,
  reaction: StagePresentationRequest | null,
): StagePresentationRequest {
  if (reaction) return { ...reaction, priority:true };
  if (hasCue) return { expression:"Cue", talking:false, dialogueBoundary:true, priority:true };
  if (latest.expression && (PHONE_REACTIONS as readonly string[]).includes(latest.expression)) return { expression:"Waiting", talking:false, priority:true };
  return { ...latest, priority:true };
}
export const PHONE_REACTIONS = ["Accept","Confused","Angry","Menancing","Unexpected","Disappointed"] as const;
