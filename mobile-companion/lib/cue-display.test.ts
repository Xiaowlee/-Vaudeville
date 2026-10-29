import assert from "node:assert/strict";
import test from "node:test";
import { limitCueDisplay } from "./cue-display.ts";

const limit = { maxWords: 20, maxSentences: 2 };

test("short cues stay whole", () => {
  assert.equal(limitCueDisplay("Halo\nevery\nnyan", limit), "Halo\nevery\nnyan");
  assert.equal(
    limitCueDisplay("Pause, then look across the stage.", limit),
    "Pause, then look across the stage.",
  );
});

test("stops after two sentences even when under the word cap", () => {
  const text = "Look left. Hold. Then keep walking toward the curtain without rushing.";
  assert.equal(limitCueDisplay(text, limit), "Look left. Hold.");
});

test("stops near twenty words when sentences keep going", () => {
  const text =
    "This preview line is only for layout and it is not a live cue yet it keeps adding words past the card so the player cannot reread it easily";
  const shown = limitCueDisplay(text, limit);
  assert.equal(shown.split(/\s+/).filter(Boolean).length, 20);
  assert.equal(
    shown,
    "This preview line is only for layout and it is not a live cue yet it keeps adding words past",
  );
});

test("empty text is unchanged", () => {
  assert.equal(limitCueDisplay("", limit), "");
});
