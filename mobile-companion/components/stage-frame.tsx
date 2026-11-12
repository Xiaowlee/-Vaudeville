"use client";

import { useLayoutEffect, useRef, type CSSProperties } from "react";
import { limitCueDisplay } from "../lib/cue-display";
import type { StageChannels, StageCue, StageRelayStatus } from "../lib/stage-phone";
import { stageView } from "../lib/stage-phone";
import styles from "./stage-frame.module.css";
import { stageFrameSettings } from "./stage-frame-settings";
import { StageManagerPuppet, type StampedPresentation } from "./stage-manager-puppet";

const settings = stageFrameSettings;

export type PhoneReminder = {
  text: string;
  background: string;
  color: string;
  x: number;
  y: number;
  width: number;
  fontSize: number;
  lineHeight: number;
  layers: [number, number, number, number, number][];
};

function cssVars(): CSSProperties {
  const { bounds, sourceWidth, sourceHeight, railStrips, cardText, characterSourceSize } = settings;
  const opening = (bounds.bottom.y - bounds.curtain.bottom) / sourceHeight;
  return {
    ["--stage-background" as string]: settings.background,
    ["--text-color" as string]: settings.textColor,
    ["--card-text-color" as string]: settings.cardTextColor,
    ["--source-width" as string]: String(sourceWidth),
    ["--source-height" as string]: String(sourceHeight),
    ["--curtain-fraction" as string]: String(bounds.curtain.bottom / sourceHeight),
    ["--opening-fraction" as string]: String(opening),
    ["--opening-width-fraction" as string]: String((sourceWidth - railStrips.left.width * 2) / sourceWidth),
    ["--body-line-height" as string]: settings.bodyLineHeight,
    ["--heading-scale" as string]: settings.headingScale,
    ["--heading-line-height" as string]: settings.headingLineHeight,
    ["--region-gap" as string]: settings.regionGap,
    ["--card-left" as string]: `${(cardText.x / characterSourceSize) * 100}%`,
    ["--card-top" as string]: `${(cardText.y / characterSourceSize) * 100}%`,
    ["--card-width" as string]: `${((cardText.right - cardText.x) / characterSourceSize) * 100}%`,
    ["--card-height" as string]: `${((cardText.bottom - cardText.y) / characterSourceSize) * 100}%`,
    ["--wiggle-shift" as string]: `${settings.cueWiggle.offsetPx}px`,
    ["--wiggle-turn" as string]: `${settings.cueWiggle.rotationDeg}deg`,
    ["--wiggle-duration" as string]: `${settings.cueWiggle.cyclePoses / settings.cueWiggle.posesPerSecond}s`,
    ["--wiggle-step" as string]: `${1 / settings.cueWiggle.posesPerSecond}s`,
  };
}

type CuePiece = { kind: "word" | "space"; value: string };

/** Keep spaces and authored line breaks between words. Punctuation stays on its word. */
function splitCuePieces(text: string): CuePiece[] {
  const pieces: CuePiece[] = [];
  const breaks = /\s+/g;
  let last = 0;
  for (const match of text.matchAll(breaks)) {
    const at = match.index ?? 0;
    if (at > last) pieces.push({ kind: "word", value: text.slice(last, at) });
    pieces.push({ kind: "space", value: match[0] });
    last = at + match[0].length;
  }
  if (last < text.length) pieces.push({ kind: "word", value: text.slice(last) });
  return pieces;
}

function WiggleCue({ text }: { text: string }) {
  if (!settings.cueWiggle.enabled) return text;
  return splitCuePieces(text).map((piece, step) => piece.kind === "space" ? piece.value : (
    <span key={step} className={styles.wiggleMotion} data-wiggle={String(step % 4)}
      style={{ ["--wiggle-index" as string]: String(step) }}>{piece.value}</span>
  ));
}

function cueLabel(channel: "prompt" | "ifb", cue: StageCue): string | null {
  if (cue.cueType === "WARNING") return "Warning";
  if (cue.cueType === "SCRIPT_UPDATE") return "Script update";
  if (channel === "ifb") return "Private";
  return null;
}

function CueRegion({ channel, cue, showHeading }: { channel: "prompt" | "ifb"; cue: StageCue; showHeading: boolean }) {
  const label = showHeading ? cueLabel(channel, cue) ?? (channel === "prompt" ? "Prompt" : "Private") : cueLabel(channel, cue);
  const shown = limitCueDisplay(cue.text, settings.cueDisplayLimit);
  return (
    <section className={styles.cue} data-channel={channel}>
      {label ? <p className={styles.cueLabel}>{label}</p> : null}
      <p className={styles.cueText}>
        <WiggleCue text={shown} />
      </p>
    </section>
  );
}

function fits(box: HTMLElement) {
  return box.scrollHeight <= box.clientHeight + 1 && box.scrollWidth <= box.clientWidth + 1;
}

function fitCardText(box: HTMLElement) {
  const max = Math.max(settings.cardFontMin, box.clientWidth * settings.cardFontScale);
  let size = max;
  box.style.fontSize = `${size}px`;
  box.style.justifyContent = "center";
  while (size > settings.cardFontMin && !fits(box)) {
    size = Math.max(settings.cardFontMin, size - 1);
    box.style.fontSize = `${size}px`;
    if (size === settings.cardFontMin) break;
  }
  box.style.justifyContent = fits(box) ? "center" : "flex-start";
}

export function StageFrame({
  relay,
  cues,
  presentation = null,
  reminder = null,
}: {
  relay: StageRelayStatus;
  cues: StageChannels;
  presentation?: StampedPresentation | null;
  reminder?: PhoneReminder | null;
}) {
  const view = stageView(relay, cues);
  const prompt = cues.prompt && cues.prompt.text !== "" ? cues.prompt : null;
  const ifb = cues.ifb && cues.ifb.text !== "" ? cues.ifb : null;
  const both = Boolean(prompt && ifb);
  const cardRef = useRef<HTMLDivElement>(null);
  const shownPrompt = prompt ? limitCueDisplay(prompt.text, settings.cueDisplayLimit) : "";
  const shownIfb = ifb ? limitCueDisplay(ifb.text, settings.cueDisplayLimit) : "";
  const copy = view === "cues" ? `${shownPrompt}\n${shownIfb}` : view;

  useLayoutEffect(() => {
    const box = cardRef.current;
    if (!box) return;
    const fit = () => {
      fitCardText(box);

    };
    fit();
    const observer = new ResizeObserver(fit);
    observer.observe(box);
    let alive = true;
    void document.fonts.ready.then(() => { if (alive) fit(); });
    return () => { alive = false; observer.disconnect(); };
  }, [copy, reminder]);

  return (
    <main aria-label="Stage cues" className={styles.stage} data-stage-view={view} style={{ ...cssVars(), ...(reminder ? { background: reminder.background } : {}) }}>
      <div className={styles.stack}>
        {(["curtain", "rails", "bottom", "top"] as const).map((name, index) => {
          const art = reminder?.layers[index];
          return <img key={name} alt="" className={styles.layer} draggable={false} src={settings.assets[name]} style={art ? {
            inset: "auto",
            left: art[0] * 100 + "%",
            top: art[1] * 100 + "%",
            width: art[2] * 100 + "%",
            height: art[3] * 100 + "%",
            opacity: art[4],
          } : undefined} />;
        })}
        {reminder ? (
          <p role="status" className={styles.reminder} style={{
            left: `${reminder.x * 100}%`,
            top: `${reminder.y * 100}%`,
            width: `${reminder.width}%`,
            fontSize: `${reminder.fontSize}cqw`,
            lineHeight: reminder.lineHeight,
            color: reminder.color,
          }}>{reminder.text}</p>
        ) : view === "disconnected" || view === "connecting" ? null : <div className={styles.character} style={{ visibility: presentation?.managerVisible === false ? "hidden" : "visible", filter: view === "waiting" ? "brightness(0.55)" : undefined }}>
          <StageManagerPuppet presentation={presentation}>
            <div aria-live="polite" className={styles.cardText} ref={cardRef}>
              {view === "cues" ? (
                <div className={styles.column}>
                  {prompt ? <CueRegion channel="prompt" cue={prompt} showHeading={both} /> : null}
                  {ifb ? <CueRegion channel="ifb" cue={ifb} showHeading /> : null}
                </div>
              ) : null}
            </div>
          </StageManagerPuppet>
        </div>}
      </div>
      {(view === "disconnected" || view === "connecting") && <p role="status" className={styles.connectionNotice}>The Stage Manager is nowhere to be found. Please check your connection again.</p>}
    </main>
  );
}
