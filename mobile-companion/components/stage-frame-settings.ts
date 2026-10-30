/**
 * Phone stage frame. Change the appearance here; the layout reads this file.
 *
 * The PNG copies in public/stage-frame are unchanged bytes of the originals in
 * D:/RMIT/Master/Studio 1/Folio 2/Game Asset/2.5/Phone. All four are the same
 * 1080×2400 canvas. They are stacked at one size so the side rails (Comp 1,
 * named Line in Figma) stay registered with the curtain and the ornaments.
 * `bounds` names the visible pixels. `right` and `bottom` are exclusive.
 *
 * Fonts are copies of Font/InstrumentSerif-Regular.ttf and Font/LavishlyYours-Regular.ttf.
 * Stage Manager poses are unchanged copies of Game Asset/2.5/CharSpriteSheet/StageManager.
 */

import type { StageManagerExpression } from "../lib/stage-presentation";

export type PixelBounds = { x: number; y: number; right: number; bottom: number };

const stageManagerPoses: Record<StageManagerExpression, string> = {
  Default: "/stage-frame/stage-manager/StageManager_Default.png",
  Waiting: "/stage-frame/stage-manager/StageManager_Waiting.png",
  Cue: "/stage-frame/stage-manager/StageManager_Cue.png",
  Accept: "/stage-frame/stage-manager/StageManager_Accept.png",
  Confused: "/stage-frame/stage-manager/StageManager_Confused.png",
  Angry: "/stage-frame/stage-manager/StageManager_Angry.png",
  Menancing: "/stage-frame/stage-manager/StageManager_Menancing.png",
  Unexpected: "/stage-frame/stage-manager/StageManager_Unexpected.png",
  Disappointed: "/stage-frame/stage-manager/StageManager_Disappointed.png",
  Speaking: "/stage-frame/stage-manager/StageManager_Speaking.png",
  Speech: "/stage-frame/stage-manager/StageManager_Speech.png",
};

export const stageFrameSettings = {
  background: "#0e1430",
  textColor: "#f3e6f8",
  sourceWidth: 1080,
  sourceHeight: 2400,
  assets: {
    rails: "/stage-frame/phone-ui-comp-1-rails.png",
    curtain: "/stage-frame/phone-ui-comp-2-curtain.png",
    bottom: "/stage-frame/phone-ui-comp-3-bottom.png",
    top: "/stage-frame/phone-ui-comp-4-top.png",
    stageManager: stageManagerPoses,
  },
  bounds: {
    rails: { x: 0, y: 223, right: 1080, bottom: 2192 },
    curtain: { x: 54, y: 196, right: 1028, bottom: 643 },
    bottom: { x: 0, y: 2024, right: 1080, bottom: 2387 },
    top: { x: 0, y: 0, right: 1080, bottom: 361 },
  } satisfies Record<string, PixelBounds>,
  railStrips: {
    left: { x: 0, width: 75 },
    right: { x: 1006, width: 74 },
  },
  bodyLineHeight: "1.15",
  /** Lavishly Yours, as a fraction of the fitted body size. */
  headingScale: "0.9",
  headingLineHeight: "1.05",
  regionGap: "0.35em",
  /**
   * Blank paper on StageManager_Cue.png, in that image's pixels.
   * The top starts below the gripping fingers. right and bottom are exclusive.
   */
  characterSourceSize: 1752,
  cardText: { x: 580, y: 420, right: 1620, bottom: 1480 },
  cardTextColor: "#2a3480",
  /** Largest body size as a fraction of the card width. Text shrinks to fit the card. */
  cardFontScale: 0.2,
  cardFontMin: 11,
  /**
   * How much of each cue is drawn on the card. The phone still receives and
   * acknowledges the full cue; only the visible text is shortened.
   */
  cueDisplayLimit: {
    maxWords: 20,
    maxSentences: 2,
  },
  /**
   * Held wobble on cue words only. Offsets stay inside ±offsetPx and ±rotationDeg.
   * cyclePoses matches the eight held poses in stage-frame.module.css.
   * posesPerSecond is how often a word changes pose (about 6–8).
   */
  cueWiggle: {
    enabled: true,
    offsetPx: 0.4,
    rotationDeg: 0.2,
    posesPerSecond: 7,
    cyclePoses: 8,
  },
  /**
   * Stage Manager puppet motion. Matches the desktop puppet defaults closely.
   * Reduced-motion users get still art and instant pose swaps.
   */
  managerMotion: {
    swayDegrees: 1.5,
    swaySeconds: 2.85,
    bounceHeightPx: 7,
    bounceSeconds: 0.4,
    flipSeconds: 0.65,
    minDialoguesPerPose: 2,
    handDrawnMotion: true,
    motionFps: 8,
  },
};

export function railBounds(side: "left" | "right"): PixelBounds {
  const strip = stageFrameSettings.railStrips[side];
  const rails = stageFrameSettings.bounds.rails;
  return {
    x: strip.x,
    y: rails.y,
    right: strip.x + strip.width,
    bottom: rails.bottom,
  };
}

/** Map one visible rectangle of a padded PNG onto a crop box of the same shape. */
export function artCropStyle(bound: PixelBounds, sourceWidth: number, sourceHeight: number) {
  const visibleW = bound.right - bound.x;
  const visibleH = bound.bottom - bound.y;
  return {
    width: `${(sourceWidth / visibleW) * 100}%`,
    height: `${(sourceHeight / visibleH) * 100}%`,
    left: `${(-bound.x / visibleW) * 100}%`,
    top: `${(-bound.y / visibleH) * 100}%`,
  };
}
