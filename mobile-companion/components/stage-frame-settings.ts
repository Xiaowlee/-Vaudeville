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
 * character-mobile.png is an unchanged copy of Game Asset/2.5/Character/mobile.png.
 */

export type PixelBounds = { x: number; y: number; right: number; bottom: number };

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
    character: "/stage-frame/character-mobile.png",
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
   * Blank paper on character-mobile.png, in that image's pixels.
   * The top starts below the clip. right and bottom are exclusive.
   */
  characterSourceSize: 1752,
  cardText: { x: 640, y: 470, right: 1680, bottom: 1420 },
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
