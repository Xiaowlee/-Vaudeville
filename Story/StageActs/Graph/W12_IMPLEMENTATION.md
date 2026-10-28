# Main-game story script repair — 18 October 2026

The existing Dialogue Nodes framework is retained. The main change is that each passage now contains an ordered sequence of typed content, rather than one unfiltered textbox. Whisper and Qwen are not replaced or retrained.

## 1. Inspected

Main stage and menu references; Graph runtime/base, presentation adapter and UI; shared StageUI/StageBeat; phone bridge; production resource; Twine importer; original W12 source; actual saved graph and old manifest; interpretation meanings/rules; response policy; existing tests and project instructions.

The saved graph and old manifest did not use the same numeric node IDs. Comparison and layout preservation therefore follow actual passage starts. Eight source/runtime differences were recorded: missing entrance offscript branch/two passages, and older Mother labels/IDs. The original graph is backed up outside the project on D.

## 2. Changed files

- `tools/sync_w12_story.py`: explicit semantic import, stable layout recovery, automatic pre-import backup.
- `tools/story_script.py`: small parser/cleanup helper for the existing importer.
- `Script/StageActs/Graph/stage_graph.gd`: ordered presentation, phone-only cues, production events and phase hooks.
- `graph_stage_ui.gd` in the same folder: release listening only after the final display segment.
- `voice_graph.gd`: allowed-intent validation, directional evidence guard, independent recovery categories, phone-only cue repetition, per-interaction silence escalation.
- `response_policy.gd`: independent help/question counters.
- `production_cue.gd`: optional phase-to-StageBeat resource mapping.
- `Story/StageActs/Graph/interpretation_rules.txt`: current authored intents separated from system categories.
- `acts_0_3_cleaned.tres`, `acts_0_3_manifest.json`, `source_sync.json`: rebuilt from the cleaned working copy.
- `tests/story-script.py`, `tests/story-script.gd`, `tests/story-script-ai.gd`: repeatable grammar, main-game and model checks.
- Existing `W12_AUDIT.md`, `W12_IMPLEMENTATION.md`, `EDITING.md`, plus `W12_INTERACTIONS.csv` and project context.
- Cleaned W12 working copy beside the original on D.

No scene layout redesign, new recognizer, new AI service, package installation, website deployment, Yarn changes or unrelated prototype edits.

## 3. Story/parser changes

The importer stores `events` in original order, plus hidden context/task/author metadata and a production map. Only dialogue and narration enter display text. Each dialogue event owns its speaker. Existing link labels, destinations and state setters are retained. All 57 passages and 103 links are represented, including pre-show and all three acts.

Legacy prose is conservatively typed in the working copy. Explicit STAGE/SOUND fields can contain multiple lines/paragraphs until the next heading. The cue-board quotation in A1_3_FirstCue is phone content; explicitly scripted YOU/MC speech remains scripted MC dialogue. Raw player speech never becomes MC dialogue.

## 4. Dialogue presentation

The stage presents one ordered segment at a time using the existing typewriter/voice UI. Narration clears the speaker name. Actual speech shows Actor 1, Actor 2, Stage Manager or MC. Existing typing speed, actor actions, sound and production resources remain available. A passage-level voice clip is not restarted for every paragraph.

The previous transcript behavior remains: processing dots, then plain recognised text in its own panel for five seconds. No “You said” title. Intermediate segments keep normal reading time; the final interactive segment releases the player's turn without the extra final hold.

## 5. Phone cues

Phone events go through the existing bridge, using prompt or IFB channels. Help/repeat requests resend the current cue through that bridge. They do not append cue text or the raw passage to the main dialogue. Optional desktop cue preview says DEBUG · Phone preview and remains off by default.

This was tested at the bridge/presentation level, not on a paired physical phone or hosted relay.

## 6–8. Response policy, global behavior and overrides

| Input | Result |
|---|---|
| Supported authored speech | Validate current allowed intent, then take its authored destination. |
| Deliberate offscript | Use authored node offscript route if present; otherwise character correction/retry. Only this category changes resistance. |
| Silence | Authored silence route if present; otherwise wait, then prompt, then stronger cue. No punishment. |
| Unclear meaning | Stay at the interaction and ask again. Never select the nearest branch. |
| Technical failure | Stay, neutral retry feedback, no narrative route or resistance change. |
| Question | Authored answer override if configured; otherwise brief authored deflection and restore the interaction. |
| Help/repeat | Authored prompt plus phone cue repetition; restore listening. |

Priority is imported node-specific override, configured node response, act response, global response. A model-provided intent cannot carry QUESTION/HELP/OFFSCRIPT into an arbitrary ordinary route; those categories use policy-owned routes. Technical failure and unclear interpretation always stay. Route IDs outside the current allowed set are rejected.

For left/right interactions, both the current intent and explicit directional evidence must agree. Banana, stairs complaints, flying suggestions, uncertainty and questions cannot select a direction. This guard is intentionally conservative; contradictory/negated direction phrases may require another attempt.

Temporary thresholds remain editable at 1/3/5. Total, streak and last category remain separate from silence, unclear, technical, help and question counts. Actual speech resets silence escalation. F3 remains hidden by default; no player-facing click-choice menu was added.

## 9. Production map

Each frame has ID, input mode, allowed intents, task, context, ordered dialogue/narration/stage/sound/phone events, author notes, optional purpose/behavior/assets/state metadata and the seven phase hooks. Empty optional entries mean not authored.

The adapter emits `production_event(passage, phase, event)` and keeps a bounded production log. Unbound stage/sound prose is a placeholder, not visible dialogue and not a claim of an implemented animation.

Existing `production_cue.gd` extends StageBeat. Its optional `phase_cues` dictionary maps ON ENTER, ON LISTEN, ON ACCEPT, ON UNCLEAR, ON SILENCE, ON QUESTION and ON OFFSCRIPT to arrays of existing StageBeat/production resources. Those can run actor actions, audio, phone cues, state changes, tint or configured animation. The existing Act 1 production slice is retained. Final assets and scene-specific audiovisual direction are still authoring work.

## 10. Working-copy grammar/spelling

Original W12 source remains unchanged. The `_working.twee` copy has explicit fields and speaker labels; links and passage IDs are preserved. Conservative fixes include traditional, stage, eyes, nudging, waiting, handwritten, obvious duplicate words and verb agreement. Expressive spellings/personality remain. Ambiguous phrases are flagged rather than rewritten.

## 11. Story inconsistencies

See the audit for all affected passages. Main decisions:

- A2_7_Agree replies “No?” after agreement.
- Some unrelated branches start music or end the story because that is their authored destination.
- A2_1_OffscriptAgain and A2_2_SecondMisleading can end the story before global resistance reaches five.
- The final Act 1 cue differs from the following scripted MC line.
- The Chief cue conflicts with prose saying no person is specified.
- Some old author notes no longer describe current links.
- The proposed prior-answer-dependent Act 3 dialogue exists only in notes, not executable branches.
- Three existing forced-continuation overrides remain: A1_0_NoAgain, A1_3_Offscript and A1_3_ThirdFailure. They reflect prior requested forced progression but differ from Twine's extra choices. Their links are present; their normal listening flow still needs your narrative decision. Full runtime/Twine behavioral parity is therefore not claimed.

## 12–13. Verification and results

The mixed-content Python and Godot presentation fixture passed BEFORE the bulk import. It checked narration → Actor 1 → narration, hidden context/author/task, stage/sound placeholders, phone-only cue and separate transcript.

Final checks:

- Grammar regression: passed; original/working story links unchanged.
- 103 authored link transitions: passed.
- 57 passage presentation/hidden-field checks: passed.
- Real local Qwen regression: 25/25 route/recovery expectations passed in the final run. These are typed-input development tests, not a general accuracy score. Some semantically equivalent accepted categories vary between VALID_INTENT and SCRIPTED_RESPONSE/SELECTION.
- Injected malformed choice, unclear, technical, silence, help, question and consequence safety checks: passed.
- Rendered narrator/actor/phone/transcript inspection: passed.
- Existing production phase resource state-change check: passed.

An initial multiline fixture assertion expected one stage event across two paragraphs; the parser correctly retained two ordered hidden stage events. The test expectation was corrected; the final suite passes. No failed check is being presented as a success.

## 14. What still needs your decision/testing

Choose whether the three forced beats should remain forced or expose their authored spoken alternatives. Resolve contradictory NPC replies and consequence destinations in Twine. Author the final visual/sound bindings. Then play through on a real microphone and paired phone; this task did not claim a fresh human speech-recognition test or physical-phone delivery test.

There is deliberately no guarantee that every utterance advances the story: uncertainty/technical failure recover on the current beat instead of fabricating consent. Deliberate offscript follows an authored response or the global correction system.

## Explicit confirmations

- Phone cues are not duplicated into main dialogue; debug preview is separate and marked.
- STAGE/SOUND/context/author/task metadata is not shown as dialogue.
- Unsupported speech cannot be forced into an unavailable intent; the entrance has an additional directional-evidence guard.
- Silence is not automatically disobedience.
- Technical failures cannot increment the offscript counter or choose a story route.
- Yarn Trial, unrelated prototypes, original Twine, Whisper and Qwen backends were not edited.

## Evidence and editable files

- [Cleaned Twine working copy](<D:/RMIT/Master/Studio 1/Folio 2/Week 11/2.4 StoryLine_Preproduct_W12_working.twee>)
- [Interaction audit](<D:/RMIT/Master/Studio 1/Folio 2/folio-2-test-2/Story/StageActs/Graph/W12_AUDIT.md>)
- [Copyable interaction table](<D:/RMIT/Master/Studio 1/Folio 2/folio-2-test-2/Story/StageActs/Graph/W12_INTERACTIONS.csv>)
- [Real model results: all requested output fields](<D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/semantic-script-2026-10-18/real-ai-matrix.json>)
- [Policy test results](<D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/semantic-script-2026-10-18/policy-matrix.json>)
- [Saved graph disagreements](<D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/semantic-script-2026-10-18/saved-graph-route-differences.json>)
- [Actor presentation screenshot](<D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/semantic-script-2026-10-18/actor.png>)
- [Narration and transcript screenshot](<D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/semantic-script-2026-10-18/phone-and-narrator.png>)

## A–N test matrix

| Test | Input | Classification / route | State | Main screen | Phone | Production |
|---|---|---|---|---|---|---|
| A Scripted | Exact next writer cue | Accepted → A1_4_SecondCue | act1_cue_reached=true | Authored MC/Actor 1/narration sequence | Next authored cue | Existing Act 1 resource + enter/accept hooks |
| B Equivalent | take the left entrance | VALID_INTENT → A2_1_Left | entrance=left | Authored left response | Prior cue cancelled on entry | Accept/enter hooks |
| C Bounded | right side please; injected banana→left | Right accepted; injected wrong selection becomes UNCLEAR | right only for real right request; banana unchanged | Authored right response / retry | Recovery cue as configured | Accept or unclear hook |
| D Context | There's so many people here | VALID_INTENT → HallCommentAppropriate | No resistance increase | Authored hall acknowledgement | AGREE | Accept/enter + phone event |
| E Offscript | I refuse both entrances (injected deliberate category) | OFFSCRIPT → entrance offscript | total +1 | Authored offscript reaction | Correction / repeated entrance cue | Offscript/correction hooks |
| F Silence | Three consecutive silence events | SILENCE; stay when no authored override | silence_count +3, resistance unchanged | Wait → prompt → stronger cue | Cue on stronger prompt | Silence hooks |
| G Unclear | I don't know at entrance | UNCLEAR; stay | unclear count only | Authored retry | No main-screen cue duplication | Unclear hook |
| H Failure | Injected technical failure | TECHNICAL_FAILURE; stay | technical count only | Neutral retry status | No fabricated narrative choice | No punishment/accept hook |
| I Question | Why is the entrance crowded? | QUESTION; stay | question count only | Brief authored deflection | Current cue repeated | Question hook |
| J Help | What should I do? / repeat variants | HELP_OR_REPEAT; stay | help count only | Authored prompt | Current cue repeated | Phone resend |
| K Repetition | Five deliberate offscript events | OFFSCRIPT → Endgame at threshold | total 5; separate streak | Authored ending | Correction/intervention at thresholds | Consequences 1/3/5 |
| L Phone only | Mixed fixture phone cue | No interpretation | No narrative state change | Cue absent | Bridge receives cue | Ordered phone event |
| M Speakers | Narrator → Actor 1 → narrator | No interpretation | No state change | Empty label → Actor 1 → empty label | None | Ordered display events |
| N Production | Mixed fixture stage/sound fields | No interpretation | No state change unless bound resource | Instructions absent | Separate cue only | Stage/sound placeholder events; bound phase resource separately verified |
