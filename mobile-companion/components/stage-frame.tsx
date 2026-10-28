import type { CSSProperties } from "react";
import type { StageChannels, StageCue, StageRelayStatus, StageView } from "../lib/stage-phone";
import { stageView } from "../lib/stage-phone";
import styles from "./stage-frame.module.css";
import { artCropStyle, railBounds, stageFrameSettings, type PixelBounds } from "./stage-frame-settings";

const settings = stageFrameSettings;

function cssVars(): CSSProperties {
  const { bounds, sourceWidth } = settings;
  const railSpan = bounds.rails.bottom - bounds.rails.y;
  return {
    ["--stage-background" as string]: settings.background,
    ["--source-width" as string]: String(sourceWidth),
    ["--curtain-bottom" as string]: String(bounds.curtain.bottom),
    ["--bottom-visible-height" as string]: String(bounds.bottom.bottom - bounds.bottom.y),
    ["--top-block-max" as string]: settings.topBlockMax,
    ["--bottom-ornament-max" as string]: settings.bottomOrnamentMax,
    ["--content-margin" as string]: settings.contentMargin,
    ["--region-gap" as string]: settings.regionGap,
    ["--reading-max-width" as string]: settings.readingMaxWidth,
    ["--reading-font-size" as string]: settings.readingFontSize,
    ["--reading-line-height" as string]: settings.readingLineHeight,
    ["--reading-font-family" as string]: settings.readingFontFamily,
    ["--character-size" as string]: settings.characterSize,
    ["--character-gap" as string]: settings.characterGap,
    ["--rail-clearance" as string]: String(settings.railStrips.left.width),
    ["--rail-span" as string]: String(railSpan),
    ["--rail-width-scale" as string]: String(settings.railWidthScale),
    ["--prompt-background" as string]: settings.promptBackground,
    ["--prompt-color" as string]: settings.promptColor,
    ["--prompt-label" as string]: settings.promptLabel,
    ["--ifb-background" as string]: settings.ifbBackground,
    ["--ifb-color" as string]: settings.ifbColor,
    ["--ifb-label" as string]: settings.ifbLabel,
    ["--status-color" as string]: settings.statusColor,
    ["--card-radius" as string]: settings.cardRadius,
  };
}

function AnchoredImage({ src, bound }: { src: string; bound: PixelBounds }) {
  const crop = artCropStyle(bound, settings.sourceWidth, settings.sourceHeight);
  return <img alt="" aria-hidden="true" className={styles.art} draggable={false} src={src} style={crop} />;
}

function cueLabel(channel: "prompt" | "ifb", cue: StageCue): string {
  if (cue.cueType === "WARNING") return "Warning";
  if (cue.cueType === "SCRIPT_UPDATE") return "Script update";
  return channel === "prompt" ? "Prompt" : "Private";
}

function CueRegion({ channel, cue }: { channel: "prompt" | "ifb"; cue: StageCue }) {
  return (
    <section className={`${styles.cue} ${channel === "prompt" ? styles.prompt : styles.ifb}`} data-channel={channel}>
      <p className={styles.cueLabel}>{cueLabel(channel, cue)}</p>
      <p className={styles.cueText}>{cue.text}</p>
    </section>
  );
}

const statusCopy: Record<Exclude<StageView, "cues">, string> = {
  connecting: "Connecting",
  waiting: "Waiting",
  disconnected: "Disconnected",
};

export function StageFrame({ relay, cues }: { relay: StageRelayStatus; cues: StageChannels }) {
  const view = stageView(relay, cues);
  const left = railBounds("left");
  const right = railBounds("right");
  const railScale = settings.railWidthScale === 1 ? undefined : `scaleX(${settings.railWidthScale})`;
  const topHeight = settings.bounds.top.bottom - settings.bounds.top.y;
  const bottomHeight = settings.bounds.bottom.bottom - settings.bounds.bottom.y;
  const curtain = settings.bounds.curtain;
  const curtainWidth = curtain.right - curtain.x;
  const curtainHeight = curtain.bottom - curtain.y;

  return (
    <main aria-label="Stage cues" className={styles.stage} data-stage-view={view} style={cssVars()}>
      <div
        className={`${styles.rail} ${styles.railLeft}`}
        style={{ width: `calc(100cqh * ${left.right - left.x} / ${left.bottom - left.y})`, transform: railScale }}
      >
        <AnchoredImage bound={left} src={settings.assets.rails} />
      </div>
      <div
        className={`${styles.rail} ${styles.railRight}`}
        style={{ width: `calc(100cqh * ${right.right - right.x} / ${right.bottom - right.y})`, transform: railScale }}
      >
        <AnchoredImage bound={right} src={settings.assets.rails} />
      </div>
      <div className={styles.topAnchor}>
        <div className={styles.ornament} style={{ aspectRatio: `${settings.sourceWidth} / ${topHeight}` }}>
          <AnchoredImage bound={settings.bounds.top} src={settings.assets.top} />
        </div>
        <div
          className={styles.curtain}
          style={{
            left: `${(curtain.x / settings.sourceWidth) * 100}%`,
            width: `${(curtainWidth / settings.sourceWidth) * 100}%`,
            top: `${(curtain.y / topHeight) * 100}%`,
            aspectRatio: `${curtainWidth} / ${curtainHeight}`,
          }}
        >
          <AnchoredImage bound={curtain} src={settings.assets.curtain} />
        </div>
      </div>
      <div className={styles.bottomAnchor}>
        <div className={styles.ornament} style={{ aspectRatio: `${settings.sourceWidth} / ${bottomHeight}` }}>
          <AnchoredImage bound={settings.bounds.bottom} src={settings.assets.bottom} />
        </div>
      </div>
      <div aria-hidden="true" className={styles.character}>
        <span>{settings.characterLabel}</span>
      </div>
      <div aria-live="polite" className={styles.reading}>
        {view === "cues" ? (
          <div className={styles.column}>
            {cues.prompt && cues.prompt.text !== "" ? <CueRegion channel="prompt" cue={cues.prompt} /> : null}
            {cues.ifb && cues.ifb.text !== "" ? <CueRegion channel="ifb" cue={cues.ifb} /> : null}
          </div>
        ) : (
          <div className={styles.columnStatus}>
            <p className={styles.status}>{statusCopy[view]}</p>
          </div>
        )}
      </div>
    </main>
  );
}
