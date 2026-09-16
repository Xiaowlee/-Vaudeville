"use client";

import { FaceLandmarker, FilesetResolver, type Category } from "@mediapipe/tasks-vision";
import { useEffect, useRef } from "react";
import {
  CALIBRATION_HOLD_MS,
  FACE_LANDMARKER_MODEL_URL,
  MEDIAPIPE_WASM_URL,
  SMILE_HOLD_MS,
  SMILE_THRESHOLD,
} from "@/lib/config";
import { connectCompanionRelay, sendCompanionMessage } from "@/lib/messenger";
import { getRelayClient, relayStatusLabel, subscribeRelayStatus, subscribeRelayMessages } from "@/lib/websocket";

type Phase = "idle" | "setup" | "waiting" | "cue" | "success";

function blendScore(categories: Category[] | undefined, name: string): number {
  return categories?.find((item) => item.categoryName === name)?.score ?? 0;
}

export default function FaceCompanion() {
  const previewRef = useRef<HTMLVideoElement>(null);
  const cueRef = useRef<HTMLParagraphElement>(null);
  const statusRef = useRef<HTMLParagraphElement>(null);
  const actionRef = useRef<HTMLButtonElement>(null);
  const debugRef = useRef<HTMLPreElement>(null);

  useEffect(() => {
    if (!previewRef.current || !cueRef.current || !statusRef.current || !actionRef.current || !debugRef.current) {
      return;
    }
    const preview: HTMLVideoElement = previewRef.current;
    const cueEl: HTMLParagraphElement = cueRef.current;
    const statusEl: HTMLParagraphElement = statusRef.current;
    const actionButton: HTMLButtonElement = actionRef.current;
    const debugEl: HTMLPreElement = debugRef.current;

    let phase: Phase = "idle";
    let landmarker: FaceLandmarker | null = null;
    let stream: MediaStream | null = null;
    let rafId = 0;
    let lastVideoTime = -1;
    let lastDebugLog = 0;
    let lastFaceCount = -1;
    let oneFaceSince = 0;
    let smileSince = 0;
    let lastCueMet: boolean | null = null;
    let lastSuccessDebug: string[] = [];
    let cancelled = false;
    let requestId = "";
    let acknowledged = false;
    let calibrated = false;

    connectCompanionRelay();
    const relay = getRelayClient();

    function relayDebugLine(): string {
      return `relay: ${relayStatusLabel(relay.getStatus())}  ${relay.getUrl() || "not configured"}`;
    }

    function setPhase(next: Phase): void {
      phase = next;
      preview.classList.toggle("preview-hidden", next !== "setup");

      if (next === "idle") {
        cueEl.textContent = "";
        statusEl.textContent = "Front camera, then smile.";
        actionButton.textContent = "Enable camera";
        actionButton.disabled = false;
        actionButton.classList.remove("hidden");
        return;
      }

      if (next === "setup") {
        cueEl.textContent = "Look here";
        statusEl.textContent = "Need one face";
        actionButton.textContent = "Continue";
        actionButton.disabled = true;
        actionButton.classList.remove("hidden");
        return;
      }

      if (next === "waiting") {
        cueEl.textContent = "Ready";
        statusEl.textContent = "Waiting for the game";
        actionButton.classList.add("hidden");
        return;
      }
      if (next === "cue") {
        cueEl.textContent = "Smile";
        statusEl.textContent = "Hold it";
        actionButton.classList.add("hidden");
        smileSince = 0;
        lastCueMet = null;
        return;
      }

      cueEl.textContent = "OK";
      statusEl.textContent = "Smile held — sending to game…";
      actionButton.textContent = "Again";
      actionButton.disabled = false;
      actionButton.classList.add("hidden");
    }

    function writeDebug(lines: string[], forceLog = false): void {
      const withSuccess =
        lastSuccessDebug.length > 0 ? [...lines, "", "last successful cue:", ...lastSuccessDebug] : lines;
      debugEl.textContent = withSuccess.join("\n");
      const now = performance.now();
      if (forceLog || now - lastDebugLog > 250) {
        lastDebugLog = now;
        console.log(withSuccess.join(" | "));
      }
    }

    async function createLandmarker(): Promise<FaceLandmarker> {
      const fileset = await FilesetResolver.forVisionTasks(MEDIAPIPE_WASM_URL);
      const options = {
        baseOptions: {
          modelAssetPath: FACE_LANDMARKER_MODEL_URL,
          delegate: "GPU" as const,
        },
        runningMode: "VIDEO" as const,
        numFaces: 2,
        outputFaceBlendshapes: true,
      };

      try {
        return await FaceLandmarker.createFromOptions(fileset, options);
      } catch (error) {
        console.warn("GPU Face Landmarker failed, using CPU", error);
        return FaceLandmarker.createFromOptions(fileset, {
          ...options,
          baseOptions: { ...options.baseOptions, delegate: "CPU" },
        });
      }
    }

    async function startCamera(): Promise<void> {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: {
          facingMode: { ideal: "user" },
          width: { ideal: 640 },
          height: { ideal: 480 },
        },
      });
      preview.srcObject = stream;
      await preview.play();
    }

    function stopLoop(): void {
      if (rafId) {
        cancelAnimationFrame(rafId);
        rafId = 0;
      }
    }

    function emitFacePresent(faceCount: number): void {
      if (faceCount === lastFaceCount) {
        return;
      }
      lastFaceCount = faceCount;
      sendCompanionMessage({
        kind: "face_present",
        present: faceCount === 1,
        faceCount,
      });
    }

    function emitSmileMet(met: boolean): void {
      if (lastCueMet === met) {
        return;
      }
      lastCueMet = met;
      sendCompanionMessage({
        kind: "face_cue",
        cue: "smile",
        met,
        requestId,
      });
    }

    function detectFrame(): void {
      rafId = requestAnimationFrame(detectFrame);
      if (!landmarker || preview.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) {
        return;
      }
      if (preview.currentTime === lastVideoTime) {
        return;
      }

      lastVideoTime = preview.currentTime;
      const now = performance.now();
      const result = landmarker.detectForVideo(preview, now);
      const faceCount = result.faceLandmarks.length;
      const categories = result.faceBlendshapes[0]?.categories;
      const smileLeft = blendScore(categories, "mouthSmileLeft");
      const smileRight = blendScore(categories, "mouthSmileRight");
      const smile = (smileLeft + smileRight) / 2;
      const oneFace = faceCount === 1;
      const smiling = oneFace && smile >= SMILE_THRESHOLD;

      emitFacePresent(faceCount);

      if (phase === "setup") {
        if (oneFace) {
          if (!oneFaceSince) {
            oneFaceSince = now;
          }
          const held = now - oneFaceSince;
          const ready = held >= CALIBRATION_HOLD_MS;
          statusEl.textContent = ready ? "One face" : "Hold still";
          actionButton.disabled = !ready;
        } else {
          oneFaceSince = 0;
          actionButton.disabled = true;
          statusEl.textContent = faceCount === 0 ? "Need one face" : "Too many faces";
        }
      }

      if (phase === "cue") {
        if (smiling) {
          if (!smileSince) {
            smileSince = now;
          }
          const held = now - smileSince;
          statusEl.textContent = `Hold ${Math.min(held, SMILE_HOLD_MS).toFixed(0)} / ${SMILE_HOLD_MS} ms`;
          if (held >= SMILE_HOLD_MS) {
            lastSuccessDebug = [
              `kind: face_cue  cue: smile  met: true`,
              `mouthSmileLeft:  ${smileLeft.toFixed(3)}`,
              `mouthSmileRight: ${smileRight.toFixed(3)}`,
              `smileAverage:    ${smile.toFixed(3)}  threshold: ${SMILE_THRESHOLD}`,
              `heldMs: ${held.toFixed(0)} / ${SMILE_HOLD_MS}`,
            ];
            emitSmileMet(true);
            setPhase("success");
          }
        } else {
          smileSince = 0;
          statusEl.textContent = oneFace ? "Smile" : faceCount === 0 ? "Need one face" : "Too many faces";
        }
      }

      writeDebug([
        `phase: ${phase}`,
        `faces: ${faceCount}  oneFace: ${oneFace}`,
        `mouthSmileLeft:  ${smileLeft.toFixed(3)}`,
        `mouthSmileRight: ${smileRight.toFixed(3)}`,
        `smileAverage:    ${smile.toFixed(3)}  threshold: ${SMILE_THRESHOLD}`,
        `smiling: ${smiling}  holdMs: ${SMILE_HOLD_MS}`,
        `cueMet: ${lastCueMet === true}`,
        relayDebugLine(),
      ]);
    }

    async function enableCamera(): Promise<void> {
      actionButton.disabled = true;
      statusEl.textContent = "Starting camera…";
      try {
        if (!landmarker) {
          landmarker = await createLandmarker();
        }
        if (cancelled) {
          return;
        }
        await startCamera();
        if (cancelled) {
          return;
        }
        oneFaceSince = 0;
        lastFaceCount = -1;
        lastVideoTime = -1;
        setPhase("setup");
        stopLoop();
        detectFrame();
      } catch (error) {
        console.error(error);
        statusEl.textContent =
          error instanceof DOMException && error.name === "NotAllowedError"
            ? "Camera permission denied"
            : "Camera failed";
        actionButton.disabled = false;
        writeDebug([`error: ${error instanceof Error ? error.message : String(error)}`], true);
      }
    }

    function onActionClick(): void {
      if (phase === "idle") {
        void enableCamera();
        return;
      }
      if (phase === "setup" && !actionButton.disabled) {
        calibrated = true;
        setPhase(requestId ? "cue" : "waiting");
        return;
      }
      if (phase === "success") {
        setPhase("cue");
      }
    }

    actionButton.addEventListener("click", onActionClick);
    setPhase("idle");
    function writeIdleDebug(): void {
      writeDebug([
        "Waiting for camera.",
        `smile threshold: ${SMILE_THRESHOLD}`,
        `hold duration: ${SMILE_HOLD_MS} ms`,
        relayDebugLine(),
      ]);
    }
    writeIdleDebug();
    const unsubscribeMessages = subscribeRelayMessages((raw) => {
      let message;
      try { message = JSON.parse(raw); } catch { return; }
      if (!message || typeof message !== "object") return;
      if (message.kind === "face_request" && typeof message.requestId === "string" && message.cue === "smile") {
        if (message.requestId === requestId) return;
        requestId = message.requestId;
        acknowledged = false;
        if (calibrated) setPhase("cue");
      } else if (message.kind === "face_ack" && message.requestId === requestId) {
        acknowledged = true;
        statusEl.textContent = "Look at the laptop. Read when prompted.";
      } else if (message.kind === "face_cancel" && message.requestId === requestId) {
        requestId = "";
        if (calibrated) setPhase("waiting");
      }
    });
    const resend = window.setInterval(() => {
      if (phase === "success" && requestId && !acknowledged) {
        relay.send({kind: "face_cue", cue: "smile", met: true, requestId});
      }
    }, 1000);
    const unsubscribeRelay = subscribeRelayStatus((status) => {
      if (status === "open") relay.send({kind: "hello", role: "phone"});
      if (phase === "idle") {
        writeIdleDebug();
      }
    });

    return () => {
      cancelled = true;
      unsubscribeRelay();
      unsubscribeMessages();
      window.clearInterval(resend);
      relay.disconnect();
      actionButton.removeEventListener("click", onActionClick);
      stopLoop();
      stream?.getTracks().forEach((track) => track.stop());
      landmarker?.close();
    };
  }, []);

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-[430px] flex-col items-center justify-center gap-4 px-5 pb-[calc(1.5rem+env(safe-area-inset-bottom))] pt-6 text-center">
      <video
        ref={previewRef}
        className="preview-hidden aspect-[3/4] w-full max-h-[46vh] rounded-xl bg-black object-cover [transform:scaleX(-1)]"
        autoPlay
        muted
        playsInline
      />
      <p ref={cueRef} className="m-0 min-h-[2.6rem] text-[2.4rem] font-semibold leading-tight" />
      <p ref={statusRef} className="m-0 min-h-[1.4rem] text-base text-[#bbb]" />
      <button
        ref={actionRef}
        type="button"
        className="appearance-none rounded-full border-0 bg-[#eee] px-7 py-3.5 text-[1.05rem] text-[#111] disabled:opacity-35"
      >
        Enable camera
      </button>
      <pre
        ref={debugRef}
        className="mt-3 w-full overflow-x-auto rounded-lg bg-[#1c1c1c] p-3 text-left text-xs leading-snug text-[#9d9]"
      />
    </main>
  );
}
