import assert from "node:assert/strict";
import test from "node:test";
import {
  applyPoseRequest,
  completeFlip,
  createPoseController,
  swapFlipPose,
  tryBeginFlip,
} from "./stage-presentation.ts";

test("competing expression requests keep only the newest pending pose", () => {
  let state = createPoseController("Default", 2);
  state = applyPoseRequest(state, { expression: "Angry" });
  state = applyPoseRequest(state, { expression: "Accept" });
  assert.equal(state.pending, "Accept");
  assert.equal(state.shown, "Default");
  assert.equal(state.flipping, false);
});

test("expression changes only at a dialogue boundary after the hold", () => {
  let state = createPoseController("Waiting", 2);
  state.dialoguesSinceChange = 0;
  state = applyPoseRequest(state, { expression: "Cue" });
  assert.equal(state.flipping, false);
  state = applyPoseRequest(state, { dialogueBoundary: true });
  assert.equal(state.flipping, false);
  assert.equal(state.dialoguesSinceChange, 1);
  state = applyPoseRequest(state, { dialogueBoundary: true });
  assert.equal(state.flipping, true);
  assert.equal(state.flipTo, "Cue");
  state = swapFlipPose(state);
  assert.equal(state.shown, "Cue");
  state = completeFlip(state);
  assert.equal(state.flipping, false);
  assert.equal(state.shown, "Cue");
});

test("finishing a flip does not chain another flip", () => {
  let state = createPoseController("Waiting", 2);
  state = applyPoseRequest(state, { expression: "Cue", dialogueBoundary: true });
  assert.equal(state.flipping, true);
  state = applyPoseRequest(state, { expression: "Angry" });
  state = swapFlipPose(state);
  state = completeFlip(state);
  assert.equal(state.flipping, false);
  assert.equal(state.shown, "Cue");
  assert.equal(state.pending, "Angry");
  state = tryBeginFlip(state, 2);
  assert.equal(state.flipping, false);
});

test("talking can update without starting a flip", () => {
  let state = createPoseController("Default", 2);
  state = applyPoseRequest(state, { talking: true });
  assert.equal(state.talking, true);
  assert.equal(state.flipping, false);
  assert.equal(state.shown, "Default");
});
