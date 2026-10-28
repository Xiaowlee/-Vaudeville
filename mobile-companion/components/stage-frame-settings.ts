/**
 * Phone stage frame. Change the appearance here; the layout reads this file.
 *
 * The PNG copies in public/stage-frame are unchanged bytes of the originals in
 * D:/RMIT/Master/Studio 1/Folio 2/Game Asset/2.5/Phone. They still contain their
 * transparent padding. `bounds` names the visible pixels so that padding is not
 * treated as the size of the artwork. `right` and `bottom` are exclusive.
 *
 *   phone-ui-comp-1-rails.png   Phone Ui_Layer Comp 1.png  side rails
 *   phone-ui-comp-2-curtain.png Phone Ui_Layer Comp 2.png  curtain trim
 *   phone-ui-comp-3-bottom.png  Phone Ui_Layer Comp 3.png  bottom ornament
 *   phone-ui-comp-4-top.png     Phone Ui_Layer Comp 4.png  top ornament
 *
 * Rail columns were measured at alpha above 16: left x 0–74, right x 1006–1079.
 */

export type PixelBounds = { x: number; y: number; right: number; bottom: number };

export const stageFrameSettings = {
  background: "#1a103c",
  sourceWidth: 1080,
  sourceHeight: 2400,
  assets: {
    rails: "/stage-frame/phone-ui-comp-1-rails.png",
    curtain: "/stage-frame/phone-ui-comp-2-curtain.png",
    bottom: "/stage-frame/phone-ui-comp-3-bottom.png",
    top: "/stage-frame/phone-ui-comp-4-top.png",
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
  /** 1 keeps each pole's proportions while it spans the screen height. Other values stretch the stroke sideways. */
  railWidthScale: 1,
  /** Lowest visible curtain pixel stays within this share of the screen. Short screens shrink the header before the text. */
  topBlockMax: "30dvh",
  bottomOrnamentMax: "16dvh",
  contentMargin: "0.75rem",
  regionGap: "0.75rem",
  readingMaxWidth: "34rem",
  readingFontSize: "clamp(1.0625rem, 4.8vw, 1.65rem)",
  readingLineHeight: "1.45",
  readingFontFamily: "inherit",
  characterSize: "min(34vw, 16dvh, 180px)",
  characterGap: "0.5rem",
  characterLabel: "Character illustration",
  promptBackground: "#f7eaf4",
  promptColor: "#1e1a29",
  promptLabel: "#6d5a78",
  ifbBackground: "#121429",
  ifbColor: "#f4f2ff",
  ifbLabel: "#c9c2ea",
  statusColor: "#efeaff",
  cardRadius: "1rem",
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
