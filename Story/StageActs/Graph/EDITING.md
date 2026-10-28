# Editing the current story

Edit the cleaned `2.4 StoryLine_Preproduct_W12_working.twee` beside the original in Week 11. The original was not changed.

Use explicit headings. NARRATOR clears the speaker; ACTOR 1 / ACTOR 2 / MC / STAGE MANAGER name scripted speech. STAGE and SOUND are hidden production events. CUE / PHONE goes to the phone. CONTEXT and PLAYER TASK inform the interpreter; AUTHOR NOTE stays hidden. PLAYER RESPONSE contains normal Twine links such as `[[Left->A2_1_Left]]`, so Twine draws arrows.

A field lasts until the next heading. Put NARRATOR before returning from a stage/sound note to visible prose. Put the actor heading before speech. Do not place production instructions inside quoted speech.

Run `python tools/sync_w12_story.py --overwrite` from the main project to import the working copy. It backs up the previous graph on D, then updates content/routes and preserves matching passage positions. `--clean-source` explicitly recreates the working copy from the original: do not use it after writing new material in the working copy unless that replacement is intended.

The existing Godot GameController Presentation dictionary maps passage IDs to StageBeat/production_cue resources. Optional phase_cues hold arrays of those resources under ON ENTER, ON LISTEN, ON ACCEPT, ON UNCLEAR, ON SILENCE, ON QUESTION or ON OFFSCRIPT. Unbound production prose is logged as a placeholder; it does not magically create effects.

Fallback wording/counters remain in response_policy.json. Authored silence/offscript links are imported as node overrides. See W12_INTERACTIONS.csv and W12_AUDIT.md before changing response meaning. There are three older forced-continuation exceptions awaiting author decision.

Run tests/story-script.py, tests/story-script.gd and tests/story-script-ai.gd for grammar, runtime and existing local Qwen checks. The last requires the already installed local model. No website deployment is needed for these desktop main-game changes; restart the running Godot game to load the new graph.
