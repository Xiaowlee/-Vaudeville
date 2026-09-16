# Studio 1 — Folio 2 current design

Updated 6 September 2026 from the latest user instructions. This document is the authoritative current design source, replacing the original setup-only handoff and earlier 2.5-second transition/calibration design.

## Inquiry and minimum hypothesis
A player voluntarily commits attention to a game, but may experience isolation, loneliness or detachment from their surroundings. These are subjective possibilities, not promised outcomes. The making question is how narrating and embodying a story can deepen personal attention. The minimum hypothesis is that constructing, speaking and later physically performing narrative may deepen attentional commitment, allowing peripheral story information to pass outside immediate awareness.

Folio 1 informs gradual background/UI/sound changes, attention points, hints and foreshadowing. These should develop with narrative and repetition rather than become unrelated distraction mechanics. Do not add speculative narrative cues without a concrete design instruction.

## Current desktop scope
Preserve the working Scene 0 and add Scene 1: Headphones, reusing Scene/Intro.tscn, Scene/prototype_1.tscn and Script/. Preserve the user's illustration, sprite-sheet, font, background and animation scenes. Do not invent new illustration. Existing visual-only scenes do not imply complete later gameplay scenes.

Intro: existing logo + Start Game + a clearly labelled QR placeholder. The existing Quit button may remain. No large microphone calibration or diagnostics UI. The QR placeholder is not a live pairing service.

Each reusable gameplay scene has a background panel, replaceable animated story area, floating word choices, sentence below, small Read out loud label, minimal mic/debug indicator and Home. After completion it also has Next. Scene 0 itself teaches the mechanic; no separate tutorial.

## Exact interaction flow
1. Scene 0 starts dark, with legible controls and a grey sentence with one missing word: “She turns on the light.”
2. Floating choices have hover/press feedback. Dragging shows the selected word moving. Wrong drops do not lock: the word visibly returns to its origin. Correct drops snap into the blank and lock permanently.
3. The entire completed sentence becomes outlined ready-to-read. Show Read out loud and start microphone recognition only now, with a small active indicator.
4. Print actual recognised text to Godot Output. Match the target forgivingly for case, punctuation and small recognition differences; do not accept unrelated speech or replace the key word with its opposite.
5. On acceptance, remove the outline, apply the dedicated completed colour, hide Read out loud and stop listening. Emit completion once.
6. Scene 0 transitions from dark to light and plays the configured one-shot sprite-sheet/animation response. Standby loops; a supplied action animation runs once, then holds its final state or returns to standby according to an Inspector setting.
7. After the response finishes, show Next and begin the Inspector-configurable auto-advance timer, default five seconds. Clicking Next or timer expiry loads the configured next scene once. If no later gameplay scene exists/configuration is empty, remain completed; do not invent a destination or misleadingly reload Intro.
8. Home returns to the existing Intro and stops any voice worker/timer.

## Inspector contract
SentenceRoot.tscn contains plain Control nodes: PrefixLabel, WordDropZone (with SnapPoint), SuffixLabel and ReadOutLoudLabel. Edit positions, sizes, spacing, fonts, font sizes and ready outline settings in the 2D editor/Theme Overrides. Scripts must not generate sentence nodes or lay them out. In gameplay, enable Editable Children for sentence instance overrides or edit the reusable scene itself. Match target/correct word remain in the sentence resource; authored prefix/suffix and choice text must match that resource.

WordCard.tscn is a reusable Button, with scene-authored normal/hover/pressed/disabled styles, padding and font. The actual card follows the held mouse smoothly, preserving the click offset. Invalid/wrong drops tween to origin. A valid target gets subtle hover feedback. Correct drops snap to the editable SnapPoint and permanently lock. No detached preview. State colours belong to SentenceRoot; the ready outline comes from each text node's Theme Overrides. No Containers constrain sentence placement.

Edit SpriteFrames and AnimatedSprite2D scale/position directly. Room exposes standby/action names and return-to-standby. Gameplay exposes completion event, AnimationPlayer/name, next scene, five-second delay and Intro destination. Never duplicate logic for each story sentence.

## Story sequence (Scenes 0 and 1 currently required)
- Scene 0: She turns on the light.
- Scene 1: She picks up the headphones and puts them on.
- Scene 2: She picks up the key and opens the door.
- Scene 3: She walks down the street before bumping into someone.

## Voice
The inspected active scene uses Script/speech_transcriber.gd and the installed Windows en-US System.Speech engine. No Vosk/gdvosk wrapper or English Vosk model was found in this repo. The legacy AudioEffectCapture amplitude monitor is not the active recognition path. The helper captures the Windows default recording device directly; Godot AudioServer device selection does not choose this microphone. There is no PCM handoff to Vosk or hard-coded Vosk sample rate to fix here.

Use the current sentence plus explicit distractor-word variants as a System.Speech phrase grammar with continuous recognition. A target-only grammar was tested and could force “off” into “on”; explicit alternatives let the matcher reject that opposite phrase. This API does not use Vosk's [unk] token: out-of-grammar recognition raises rejected events. Log engine/culture/input format plus partial/final/rejected speech and audio problems to Output. Only sufficiently confident final results reach the existing case/punctuation-normalized matcher. Do not loosen matching to accept nonsense. Verify live mic with the user; generated audio is a separate test. No new dependency/account/paid service without approval. Ctrl+Enter remains a development-only fallback, with no extra UI button. No amplitude-only acceptance.

## Mobile architecture
Godot owns Windows desktop narrative, microphone, UI, input and animation. The phone site is `mobile-companion`: Next.js App Router + Tailwind CSS, front camera only, MediaPipe Face Landmarker in the browser, first cue smile. A lightweight local WebSocket relay lives in `mobile-companion/relay` and carries small JSON states such as `{ "kind": "face_cue", "cue": "smile", "met": true }`. Desktop still only exposes phone_connected, face_present and face_cue_met hooks; Godot is not wired to the relay yet. No identity recognition, no sadness/anger classification, no live QR pairing, and no permanent hosting. Extra phone hints/notifications remain potential future experiments, not current features.

## Current asset and verification limits
Scene 0 has the supplied two-frame standby sprite sheet and existing light_on AnimationPlayer. Standby must loop and is initially obscured. No separately identified light-on action sprite sheet is assigned; use the existing light-on animation until supplied, without pretending the standby sheet is an action. Other supplied action scenes retain their one-shot SpriteFrames.

Run and test Scene 0 after changes. Record synthetic recognition separately from a human microphone test. Do not claim the latter without evidence. Next remains unavailable when no next gameplay destination has been configured; do not invent later scenes.

## Verification after the latest correction
- Godot 4.7.1 imports and runs the rebuilt Scene 0 without parser/runtime errors.
- Actual mouse-event tests pass for held-card movement, click offset, invalid/wrong return, correct locked snap, outlines/prompt, nonsense rejection, completed colour flow and dark-to-light reveal. A visible editor-run drag also reached ready state and initialized speech.
- Temporary in-memory action frames verify one-shot hold and optional standby return. The actual five-second timer loaded a temporary valid Intro destination; no production next-scene setting was changed.
- Generated target audio produced partials and a correct final transcript. Generated unrelated audio was rejected; “she turns off the light” was recognized as “off” with explicit alternatives and is rejected by the matcher. Target-only grammar was insufficient and must not be restored.
- Live microphone initialization reports Microsoft Speech Recognizer 8.0, en-US, mono 16-bit / 16 kHz. Godot separately reports 48 kHz; these are not connected capture pipelines. The Windows default device was used, but its specific endpoint and suitability for the user's intended microphone are not confirmed. Available inputs include Realtek Microphone Array, Steam Streaming, Oculus and JBL. Live input reported NoSignal/TooSoft during the check; That was the earlier check; the user subsequently confirmed Scene 0 voice interaction is working.

## Scene 1: Headphones — latest approved scope
The user confirms Scene 0 voice interaction now works. Preserve the working core drag, sentence and voice implementation; do not retune recognition.

Scene/scene_1_headphones.tscn inherits the existing gameplay scene and uses the same scripts, SentenceRoot and WordCard instances. Target: “She picks up the headphones and puts them on.” Missing word: headphones (index 4). Distractors: book, phone. Text remains Inspector editable on cards/labels and the sentence resource; keep authored text consistent with that resource.

Begin lit with the character visible and standby looping. Correct drag → locked snap → whole sentence outlined and Read out loud → existing recognition → completed colour → supplied wear.png and headphone-object SpriteFrames play once in sync. Hold the final headphone pose by default; Room exposes the optional return-to-standby setting. Show Next only after action completion and use the existing five-second timer when next_scene is configured. Scene 0 now leads to Scene 1. No Scene 2 gameplay exists yet, so Scene 1 remains completed with disabled Next until a destination is assigned; do not invent a destination.

All placement remains authored in plain Control scene nodes. No new labels, titles, tutorial, progress UI or face recognition. Intro and existing assets are preserved.

Scene 1 validation: Scene 0 and Scene 1 automated interaction suites both pass with zero failures, including input-event dragging, sentence state changes, synchronized one-shot action, final-frame hold, manual Next and five-second auto-advance with a temporary configured destination. Scene 1 was run and visually inspected in Godot; the existing recognizer initialized successfully with its target and distractors. Scene 1 human speech acceptance has not been separately verified. Core word_tile, sentence_controller, sentence_definition, speech_transcriber and windows_speech.ps1 files are byte-for-byte unchanged.

## September 12: current approved flow and UI repair
Latest user direction supersedes earlier scope limits. Scene 0 onboarding and Scene 1 headphones remain voice-only. Scene 2 introduces face first, immediate phone feedback, laptop response, then voice, then door-open resolution. Scene 3 remains street/bumping and competing attention; no Scene 3 implementation is added here.
Preserve the user's HBoxContainer in SentenceRoot; repair script references and inherited overrides to its children. This supersedes the earlier no-Container layout rule. Cards snap centred on the authored SnapPoint.
Scene 2 inherits prototype_1 and uses scene_2_sentence.tres: “She picks the key and opens the door.” The phone requests a smile; the key word appears in the sentence on success, then after 0.6 seconds the familiar read prompt and microphone activate. No additional drag is required. The existing door.png frames play once after narration, holding the final frame. Scene 1 leads to Scene 2; Scene 2 has no configured next scene.
Only Scene 2 connects to the relay. Godot trusts the existing local cert.pem and connects to wss://127.0.0.1:8787 (Inspector editable). Phone uses the unchanged .env.local LAN address. Messages use hello roles, a fresh face_request requestId, matching face_cue, face_ack and face_cancel. Relay retains only the current request; phone retries unacknowledged success. Repeated/stale success cannot resolve a new scene.

Validation: Scene 0 and Scene 1 automated input-event regression suites pass with zero failures. Scene 2 passes using a synthetic phone over an actual certificate-verified WSS relay, then synthetic transcripts: early voice/stale cue rejection, key response delay, wrong noun rejection, duplicate cue protection and held door resolution. TypeScript and relay syntax checks pass. These checks do not verify live phone camera detection or human microphone recognition.

## September 13 — designer control refactor (latest authority)

The user is designing Scene 2 separately. Do not implement new Scene 2 mechanics. Current work is reusable Inspector control and Scene 1 repair, preserving voice/network infrastructure. Scene 2 scene/resource files and all companion/relay/recognizer source files remain unchanged.

Scene 1 broke because its old Sentence offsets inherited the base's newer centred anchors, shifting the row to the right; its On-card override straddled the sentence; and asymmetric blank offsets extended into the suffix. These overrides were removed. Scene 1 now inherits the designer's current base placement. SentenceRoot keeps the existing HBoxContainer, which centres at its own minimum width; WordDropZone reserves the card/placeholder's content size while respecting Custom Minimum Size. This supersedes older instructions to manually synchronize label text and to avoid the already-existing Container.

Sentence Definition resources are the single source for narrative text, correct word, zero-based missing index, distractors, prompts and independent require_drag / require_voice / require_face flags. They update editor labels/cards and the recognition grammar. Configure the resource on the gameplay root. Existing native nodes own placement, anchors and typography. No narrative content or UI coordinates are embedded in the shared controller. Narrative defaults were moved explicitly into scene_0_sentence.tres. The existing 3 cards can be supplemented with editor-created WordCards registered in Sentence.word_cards. Invalid configuration stops input with a warning.

The shared prototype.gd still owns sequencing. Required inputs follow face → drag → voice with disabled stages skipped; all eight combinations were tested. Existing requires_face_first remains a legacy compatibility setting for the unchanged existing face scene. Response delay, light fade duration, face response delay, auto-advance toggle, transition delay and animation references are exposed on the scene root; Room and sprite/AnimationPlayer nodes retain their existing animation configuration. No duplicate per-story controller was added. story_completed retains its original accepted-input timing; COMPLETED state occurs after visual response. Debug logs show scene, state, accepted inputs, animation and transitions.

See DESIGNER_GUIDE.md for the editor workflow and meaning of logs. Scene 0 and Scene 1 automated regressions passed; all eight input combinations, two-width layout bounds and editor resource/font preview passed. Rendered Scene 0 and Scene 1 screenshots were inspected. Actual Windows microphone initialization succeeded for both scenes. Generated audio was recognized as both exact target sentences (confidence ~0.877 and ~0.841); the opposite 'off' phrase remained 'off'. This is not a new human speech/camera playtest. The unchanged secure relay's synthetic-phone test passed. A headless editor harness reported shutdown allocation warnings; runtime scene tests had no script errors.

## September 13 — speech worker startup repair
The new designer-authored street scene has no distractors. The speech launcher passed a trailing empty -RejectPhrases value, which Windows omitted; PowerShell failed before JSON logging with "Missing an argument for parameter 'RejectPhrases'". Confirmed in three diagnostic runs. speech_transcriber.gd now omits that optional parameter when there are no alternatives. It uses non-blocking process pipes to expose startup stderr in Godot Output while retaining the existing JSON speech-event bridge, recognizer, grammar and matching thresholds. File/preparation/launch/timeout failures also report a reason rather than only generic unavailable text. The UI now directs failures to Output; Ctrl+Enter remains the existing development-only fallback.
Nine real default-microphone startup checks passed across Scene 0, Scene 1 and scene_3_bumpedIntoSb (three each), with workers remaining alive after initialization. A generated street-sentence audio test passed through the real recognition helper and game bridge: final confidence 0.908, sentence accepted and existing Bumped action resolved. These checks do not establish human speech acceptance. The earlier intermittent Scene 0 exit was not accompanied by a diagnostic; it did not recur in the nine post-fix starts. No scene/resource, networking, animation or recognition threshold was changed. Repeat live initialization with Script/speech_startup_test.gd. Process-pipe API reference: https://docs.godotengine.org/en/4.6/classes/class_os.html#class-os-method-execute-with-pipe


## September 14 — approved menu/shared structure only
Work exclusively in folio-2-test-2. Intro selects Continuous Narration or Narrator Agency, inherited shells from Scene/narration_base.tscn. This step implements navigation, scene-node text/style/layout, shared theme, ColorRect placeholders and Back only. SpeechMonitor reuses the unchanged recognizer but does not start in either shell. No narrative progression, choices, branches or phone expansion. Legacy scenes remain runnable separately. Project name is Folio 2 Test 2 to isolate default runtime files from the old project. See PROTOTYPE_SETUP.md for editor instructions.


## Prototype 1 continuous narration (2026-09-14)
Implemented three editable placeholder voice gaps, one scene and one listening session. Story/continuous_narration.tres controls narration, prompts, accepted aliases/categories, responses and status messages. Scene/continuous_narration.tscn controls layout. No gameplay timer or branches. Prototype 2 unchanged. Shared speech bridge adds opt-in continuous lifetime and a rejected-result signal; legacy callers retain behavior. See PROTOTYPE_SETUP.md for current editing instructions, superseding earlier shell-only notes. Logic, synthesized audio recognition, menu/Back and legacy microphone startup checks passed. Human voice playtest remains manual.


## Prototype 2 Narrator Agency (2026-09-14)
Implemented three placeholder choices (4/2/2 options) in Story/narrator_agency.tres. Scene/narrator_agency.tscn inherits the working Continuous Narration scene and uses the SAME controller and voice node. narration_choice.gd extends narration_moment.gd; narration_option.gd contains category, aliases, multiline response, reconnect point and optional ending. Named reconnects must reference a later Moment Id; blank means next. No large branching framework, timers, phone work or final story. Existing voice scripts unchanged. All 16 paths, synonyms, defaults, invalid routes and ambiguous aliases tested; Prototype 1 logic regression and menu tests passed. Synthesized audio completed all three choices in one Windows recognition session; initial words showed variable recognition, so human playtesting remains required. See NARRATOR_AGENCY_SETUP.md.


## Prototype 1 Shadow chapter
Replaced Story/continuous_narration.tres placeholders with the user-supplied linear Shadow chapter, grouped into three paragraph-based passages and their three gaps. Each Response Text is the first line of the shared continuation; the remaining text follows in the next Narration Text or Ending Text. Accepted Answers includes the requested synonyms and completed-prompt phrases so either can be spoken. No branches, scene/controller/voice changes, visual edits or added timing. The existing feed remains manually scrollable and follows appended content.


## Prototype 2 Shadow chapter content
Story/narrator_agency.tres now contains the supplied Shadow chapter: 4 feeling options reconnect at choice_02; 3 spoken-address options reconnect at choice_03; 3 final actions each hold their supplied Ending Text with Ends Story enabled. Options retain all requested synonyms including context-specific leave in choices 2 and 3. Prompts show the available primary options using the existing text field. No controller, voice, scene, visual, font or Prototype 1 changes.


## Accepted Answers editor persistence fix
Reproduced in --editor: exported PackedStringArray initialized with [] loads as empty and is omitted on save, despite runtime tests passing. Changed defaults to PackedStringArray() in narration_moment.gd and narration_option.gd. Editor-mode loading/saving now preserves answers. Restored 3 linear and 10 branch answer lists without changing other story fields or visuals. Prior stale-editor explanation was incomplete.


## September 16 approved shared beat presentation
Both modes now share READING -> PROMPT -> RECOGNISED -> RESPONSE -> transition states in continuous_narration.gd. Existing blank-line paragraphs in narrative/response/ending fields define editable short beats (narration_text.gd); no chapter or branch content changed. Only current text is displayed. Beat completion uses ordered words from final speech results with configurable internal coverage, never a pronunciation score; recognition failure permits repeat or labelled Reading fallback. Response and ending beats also wait for reading/fallback. Existing exact synonym/category mapping applies only in PROMPT. Recognition display duration, prompt pause and transition pause are exported; no read deadline. Scene/continuous_narration.tscn adjusts placeholder size and reading space and adds editable Prompt/Recognition nodes, inherited by Prototype 2. Existing speech_transcriber.gd, Windows recognizer, phone and assets remain unchanged. Story grammar now includes separate beats and sentences, responses and endings. Normalization preserves whitespace between paragraphs. Verified both complete flows, all 36 branches, editor answer persistence, layout captures and actual microphone initialization. Paced synthesized WAV passed reading -> recognised choice -> consequence -> completion using a test-only paced helper copy; production helper unchanged. Human reading reliability/pacing still requires playtesting. See NARRATION_PACING_GUIDE.md.


## Windows export microphone repair
Confirmed Windows export omitted prototype_1/windows_speech.ps1 (non-resource file). Windows preset now explicitly includes it. speech_transcriber validates presence/readability before launch and surfaces concise player-facing error categories. Helper checks installed en-US recognizer and reports microphone setup failure separately. Shared controller displays those messages with existing Retry microphone. No mic selector or recognition threshold changes. Exported release diagnostic ran its actual packed scenes with SOURCE_PROJECT_VISIBLE=false; both modes reached Windows default microphone listening. Missing-helper guard and simulated error UI checks passed. Distributable: Builds/Vaudeville-Windows-mic-fix.zip (ignored by Git). Existing unused Dialogue Manager C# example export errors persist, but both actual prototype scenes load and start speech in the release test. No source changes pushed to GitHub in this task.


## Speech export packaging revision 2
The Windows export include filter was empty again after a user export. Removed dependency on it: speech_transcriber preloads prototype_1/windows_speech_helper.tres and writes its source metadata to the runtime PS1. This native Resource is automatically included via its direct dependency. Canonical helper remains windows_speech.ps1; after editing it, run python tools/sync_speech_helper.py and commit both files. Tested with empty include_filter in a standalone release: LOOSE_PS1_VISIBLE=false, SOURCE_PROJECT_VISIBLE=false, both prototypes reached microphone ready. Updated tester archive Builds/Vaudeville-Windows-mic-fix-v2.zip. No gameplay/UI changes.
