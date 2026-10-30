"use client";

import { useLayoutEffect, useRef, type CSSProperties } from "react";
import { limitCueDisplay } from "../lib/cue-display";
import type { StageChannels, StageCue, StageRelayStatus, StageView } from "../lib/stage-phone";
import { stageView } from "../lib/stage-phone";
import styles from "./stage-frame.module.css";
import { stageFrameSettings } from "./stage-frame-settings";
import { StageManagerPuppet, type StampedPresentation } from "./stage-manager-puppet";

const settings = stageFrameSettings;

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
  const words = splitCuePieces(text).filter((piece) => piece.kind === "word");
  return (
    <>
      <span className={styles.cueLayout}>{text}</span>
      <span aria-hidden="true" className={styles.cueMotionLayer}>
        {words.map((word, step) => (
          <span
            key={step}
            className={styles.wiggleMotion}
            data-wiggle={String(step % 4)}
            style={{ ["--wiggle-index" as string]: String(step) }}
          >
            {word.value}
          </span>
        ))}
      </span>
    </>
  );
}

/** Park each held copy on the already-wrapped word. Runs when the cue or card size changes, not every frame. */
function placeCueMotions(root: HTMLElement) {
  if (!settings.cueWiggle.enabled) return;
  const paragraphs = root.querySelectorAll(`.${styles.cueText}`);
  paragraphs.forEach((paragraph) => {
    const layout = paragraph.querySelector(`.${styles.cueLayout}`);
    const layer = paragraph.querySelector(`.${styles.cueMotionLayer}`);
    const textNode = layout?.firstChild;
    if (!layer || !textNode || textNode.nodeType !== Node.TEXT_NODE) return;
    const origin = (layer as HTMLElement).getBoundingClientRect();
    const motions = layer.querySelectorAll(`.${styles.wiggleMotion}`);
    const source = textNode.textContent ?? "";
    const words = /\S+/g;
    let wordIndex = 0;
    for (const match of source.matchAll(words)) {
      const motion = motions[wordIndex] as HTMLElement | undefined;
      if (!motion) break;
      const range = document.createRange();
      range.setStart(textNode, match.index ?? 0);
      range.setEnd(textNode, (match.index ?? 0) + match[0].length);
      const rect = range.getClientRects()[0];
      if (rect) {
        motion.style.left = `${rect.left - origin.left}px`;
        motion.style.top = `${rect.top - origin.top}px`;
      }
      wordIndex += 1;
    }
  });
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

const statusCopy: Record<Exclude<StageView, "cues">, string> = {
  connecting: "Connecting",
  waiting: "Waiting",
  disconnected: "Disconnected",
};

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
}: {
  relay: StageRelayStatus;
  cues: StageChannels;
  presentation?: StampedPresentation | null;
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
      placeCueMotions(box);
    };
    fit();
    const observer = new ResizeObserver(fit);
    observer.observe(box);
    return () => observer.disconnect();
  }, [copy]);

  return (
    <main aria-label="Stage cues" className={styles.stage} data-stage-view={view} style={cssVars()}>
      <div className={styles.stack}>
        <img alt="" className={styles.layer} draggable={false} src={settings.assets.curtain} />
        <img alt="" className={styles.layer} draggable={false} src={settings.assets.rails} />
        <img alt="" className={styles.layer} draggable={false} src={settings.assets.bottom} />
        <img alt="" className={styles.layer} draggable={false} src={settings.assets.top} />
        <div className={styles.character}>
          <StageManagerPuppet presentation={presentation}>
            <div aria-live="polite" className={styles.cardText} ref={cardRef}>
              {view === "cues" ? (
                <div className={styles.column}>
                  {prompt ? <CueRegion channel="prompt" cue={prompt} showHeading={both} /> : null}
                  {ifb ? <CueRegion channel="ifb" cue={ifb} showHeading /> : null}
                </div>
              ) : view === "connecting" || view === "disconnected" ? (
                <p className={styles.status}>{statusCopy[view]}</p>
              ) : null}
            </div>
          </StageManagerPuppet>
        </div>
      </div>
    </main>
  );
}
