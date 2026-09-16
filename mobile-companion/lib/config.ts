/** Smile detection thresholds. Tune these while watching the on-screen debug values. */
export const SMILE_THRESHOLD = 0.35;
export const SMILE_HOLD_MS = 700;

/** How long exactly one face must stay visible before Continue is allowed. */
export const CALIBRATION_HOLD_MS = 500;

/**
 * MediaPipe WASM files. Pin the version to the installed @mediapipe/tasks-vision package.
 * Face processing still runs on this device; the CDN only serves the WASM runtime.
 */
export const MEDIAPIPE_WASM_URL =
  "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21/wasm";

/** Official Face Landmarker model (float16). Loaded once, then runs in the browser. */
export const FACE_LANDMARKER_MODEL_URL =
  "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task";
