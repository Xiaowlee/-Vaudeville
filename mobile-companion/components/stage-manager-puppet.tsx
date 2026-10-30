"use client";

import { useEffect, useReducer, useRef, type ReactNode } from "react";
import {
  applyPoseRequest,
  completeFlip,
  createPoseController,
  swapFlipPose,
  type StagePresentationRequest,
} from "../lib/stage-presentation";
import styles from "./stage-frame.module.css";
import { stageFrameSettings } from "./stage-frame-settings";

const motion = stageFrameSettings.managerMotion;

export type StampedPresentation = StagePresentationRequest & { sequence: number };

type Action =
  | { type: "request"; request: StagePresentationRequest }
  | { type: "swap" }
  | { type: "complete" };

function reducePose(state: ReturnType<typeof createPoseController>, action: Action) {
  if (action.type === "request") {
    return applyPoseRequest(state, action.request, { minDialoguesPerPose: motion.minDialoguesPerPose });
  }
  if (action.type === "swap") return swapFlipPose(state);
  return completeFlip(state);
}

function prefersReducedMotion() {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

export function StageManagerPuppet({
  presentation,
  children,
}: {
  presentation: StampedPresentation | null;
  children?: ReactNode;
}) {
  const [pose, dispatch] = useReducer(reducePose, undefined, () =>
    createPoseController("Default", motion.minDialoguesPerPose),
  );
  const flipTimer = useRef(0);
  const swapTimer = useRef(0);

  useEffect(() => {
    if (!presentation) return;
    dispatch({
      type: "request",
      request: {
        expression: presentation.expression,
        talking: presentation.talking,
        dialogueBoundary: presentation.dialogueBoundary,
      },
    });
  }, [presentation?.sequence]);

  useEffect(() => {
    if (!pose.flipping) return;
    if (prefersReducedMotion()) {
      dispatch({ type: "swap" });
      dispatch({ type: "complete" });
      return;
    }
    const half = motion.flipSeconds * 500;
    const full = motion.flipSeconds * 1000;
    swapTimer.current = window.setTimeout(() => dispatch({ type: "swap" }), half);
    flipTimer.current = window.setTimeout(() => dispatch({ type: "complete" }), full);
    return () => {
      window.clearTimeout(swapTimer.current);
      window.clearTimeout(flipTimer.current);
    };
  }, [pose.flipping, pose.flipTo]);

  const src = stageFrameSettings.assets.stageManager[pose.shown];
  const style = {
    ["--sway-degrees" as string]: `${motion.swayDegrees}deg`,
    ["--sway-seconds" as string]: `${motion.swaySeconds}s`,
    ["--bounce-height" as string]: `${motion.bounceHeightPx}px`,
    ["--bounce-seconds" as string]: `${motion.bounceSeconds}s`,
    ["--flip-seconds" as string]: `${motion.flipSeconds}s`,
  };

  return (
    <div
      aria-hidden="true"
      className={styles.characterMotion}
      data-flipping={pose.flipping ? "true" : "false"}
      data-talking={pose.talking ? "true" : "false"}
      style={style}
    >
      <div className={styles.characterSwing}>
        <div className={styles.characterCard}>
          <img alt="" className={styles.characterArt} draggable={false} src={src} />
          {children}
        </div>
      </div>
    </div>
  );
}
