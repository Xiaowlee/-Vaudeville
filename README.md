# Beneath the Lines

Open project.godot and press F5. The menu has Play, Settings, Quit, Connect phone and a small Developer mode switch. There is one story game; older prototypes and separate visual test scenes have been retired.

## Current files

- Main menu: Scene/00_main_menu.tscn
- Main game: Scene/StageActs/stage_graph_game.tscn
- Story graph: Story/StageActs/Graph/acts_0_3_cleaned.tres
- Reusable stage: Scene/Stage/stage_base.tscn and stage_visuals.tscn
- Stage art: Visual Asset/Stage/Background, Characters and CutIn
- Main stage/dialogue support: Script/Stage
- Voice, interpretation and story progression: Script/StageActs/Graph
- Mobile website and relay: mobile-companion, unchanged by this consolidation

## Editing without code

In the main scene, World/Performers contains Player (MC), Actor1, Actor2 (Intruder) and StageManager. Move each root to edit its starting position. Its Inspector exposes starting pose, pose bank, size, flip duration, talking bounce, idle sway and hand-drawn frame rate. Current supplied filenames are retained; semantic pose names can be assigned later.

DialogueView controls fonts, text motion, spacing, widths, colors and smart placement. Drag its Layout/PlacementZones guides to edit the authored areas. Instrument Serif is the body font; Lavishly Yours is the heading font.

World/Lighting follows the actual character feet and supports world-to-character and character-to-character transitions. FrameCutInLayer/FrameCutIn exposes placement areas and corner artwork. The main graph contains the migrated Stage Visual text/cut-in nodes. Their Story passage field preserves association on Twine import; At text triggers a cue at a particular line. No separate rehearsal cue array remains.

World/Atmosphere stays disabled and has no pattern assigned. The floor PNG supplied on 30 October was fully transparent and is not used; re-export it before adding it to World. Audience motion and parallax remain subtle and adjustable.

## Writing and recording

Twine source/export: ../Story Script/Beneath the Lines _ corrected 28 Oct.twee and Beneath the Lines - IMPORT THIS.html. Run `python tools/sync_w12_story.py --overwrite` to import the HTML. The importer preserves visual cue nodes associated with current passages and makes recovery copies outside this project. Twine is the writing source; review graph-only changes before importing.

GameController exposes Voice Lines (passage:event-index keys) and per-passage production settings for future recordings, sounds and actions. Recordings, final sound design, final pose assignments and additional cut-in illustrations are still pending. Prose STAGE/SOUND directions are authoring notes until connected to real production cues.

## Playing and checking

X / Speak starts and finishes recording. Space skips the current presented line. After the authored microphone-check warning, X retries and Space continues through the authored takeover. Developer mode reveals the existing transcript/status, typed response, route selection, restart and jump-to-section controls. Ctrl+Enter / Shift+Enter bypass is developer-only.

Checks: `python tests/story-script.py`; Godot `--headless --path . --script res://tests/story-script.gd`.

Desktop speech uses the existing local Whisper and Qwen engines/models in .local-speech. Keep this folder: it is ignored by Git, not included in the small game resource pack, and must be supplied beside a standalone Windows executable. Android build files, Android speech plugin/settings and the Android export preset have been removed while Android is out of scope. Local desktop engines are not established for iOS/browser. Phone pairing and the separately hosted mobile website are retained.

## Cleanup and builds

GitHub checkpoint before consolidation: 680eac7 (Update 2.5 + Old Prototype Before major Build). Retired files, obsolete exports and recovery copies are outside this project in ../Week 11/trial_recovery/main-consolidation-20261030-015740. The manifest records the exact moved files. No source artwork or writing outside the project was modified.

Windows export target: Builds/Beneath the Lines.exe. Builds is ignored and excluded from Godot import. Export includes only the current game/phone display and dependencies; retired prototypes, editor-only graph tooling, tests and mobile website source are excluded. A resource-pack check is not a complete installer or a live microphone playtest.

Act entrances/exits: select GameController → Act transitions for the temporary curtain texture, enable switch and travel time. Act Titles allows full text overrides. Blank overrides use DialogueView’s Act One/Two/Three Name; its Backdrop act title controls slide/hold and camera reveal timing. Pre-show starts with the curtain closed and Stage Manager in front. Each act boundary closes, prepares the next cast, opens, plays the title/reveal, then resumes dialogue. Ending closes the curtain.

In-game: the top-right gear opens microphone settings, Scan phone QR, Return to main menu and Resume game. QR reuses the current session. Floor art is World/Floor/Art in stage_base.tscn; use the corrected BG_Main_Floor.png. Hidden/offstage Stage Manager uses world lighting; his onstage puppet retains its spotlight. Title camera focus is constrained within the stage to avoid exposed edges.


October 30 visual update:
- GameController → Act transitions: Left/Right Curtain PNGs, curtain travel time (1.6s) and circular follow-spot dimming. Scene curtain sits above the stage, with Stage Manager above it. Title zoom/darkening is prepared behind the curtain before opening.
- MainMenu root → Spotlight Speed / Spotlight Radius controls the moving circular pool on the closed-curtain menu.
- StageUI gear → Auto-advance dialogue is on by default and saved locally. StageUI → Current Sentence Seconds is the three-second hold after reveal. Space skips; manual mode waits for Space.
- DialogueView → Narration Backing Color / Opacity edits the fixed narration/Stage Manager reading region; its existing PlacementZones remain draggable. Outer Stage Manager quotation marks are hidden at presentation only, not removed from the source.
- StageUI/Overlay/TranscriptZone is the draggable MC transcript reading area. No Player/MC heading is shown for real speech transcripts; authored MC dialogue retains its nameplate. Transcript still clears after five seconds.
- World/Atmosphere → Pattern / Outside Mask / Scroll Speed / Tile Size uses Pattern_0.png and mask.jpg. White on the registered mask reveals pattern; black hides it. Frame stays above the pattern.
- Story/StageActs/Graph/acts_0_3_cleaned.tres has 57 provisional Character pose / flip Stage Visual cues. Select one to review its character, named pose and At text trigger. These are authored cue guesses, not AI-generated acting decisions. Current Twine import preserves them. Missing illustrations/poses have not been invented.

Designer controls: World/Atmosphere → Scroll Speed / Tile Size / Background Color / Ink Color. Pattern is behind RearBackdrop and frame. FrameCutInLayer/FrameCutIn → Frame → Auto Place Ornaments plus Decoration/Backing Anchor, Offset, Fraction and Flip fields. Disable Auto Place Ornaments to edit Panel/Decoration and Panel/Backing directly; drag RightArea/LeftArea for overall placement. StageUI/Overlay/PreShowTranscriptZone positions the centred pre-show transcript; TranscriptZone positions MC speech during the acts. Both are directly draggable Controls; resize them for wrapping width. Developer mode shows offscript total/local counters. Completion Passages on GameController includes the current A3_5_End endpoint.

Pose pacing: Dialogue Nodes → Stage Visual → Character pose / flip chooses the character, named sprite and Hold at least this many dialogues (minimum2). Cues request a pose; they no longer flip immediately mid-line. All requests are coalesced; only the newest is applied at the next eligible dialogue boundary. Character Inspector → Dialogue pose pacing exposes Minimum Dialogues Per Pose, Automatic Pose Variation and Allowed Variation Poses. Defaults: MC Default/Acting; Stage Manager Default/Speaking/Speech; Actor2 Intruder1/2; Actor1 stays context-driven (no random approval pose). One pose is held for at least two dialogue pages. No chained completion flips. Graph holds longer than2 are supported. GameController → Curtain Light Linger Seconds defaults2; soft return to normal after the hold, and the light stays during a flip. Space skipping is still one boundary per displayed page.
Temporary intro loop guard: StoryRuntime → Temporary progression guard → Intro Refusals Before Takeover defaults2. Third understood no uses the current authored takeover to A1_0_Forced start. It does not turn no into yes, add resistance, rewrite Twine, or override the five-offscript failed ending. Future writing can replace this temporary rule.

Cut-in editor preview: select FrameCutInLayer/FrameCutIn → Editor Preview → Preview In Editor. Choose preview character or illustration, side, crop, aspect and fill; preview needs no story cue and is ignored during play. Frame group: Decoration/Backing Anchor is the attachment point on the panel (0,0 top-left; .5,.5 centre;1,1 bottom-right). Decoration/Backing Pivot is the corresponding point on the artwork. Offset nudges the result; Fraction sets its size relative to the panel. Example Anchor(1,0), Pivot(.5,.5) centres an ornament on the top-right corner. With Auto Place Ornaments OFF you can drag/resize Panel/Decoration and Panel/Backing directly; their manual transforms are preserved. Overall frame placement still comes from RightArea/LeftArea/CustomArea. Preview off hides it only in editor; story graph retains runtime control.

Cut-in decorative artwork is now assigned directly in stage_visuals.tscn. Expand FrameCutInLayer/FrameCutIn/Panel, select Decoration (upper ornament) or Backing (lower ornament), and drag/resize its visible rectangle. Auto Place Ornaments defaults OFF so it will not reset your changes. Use each TextureRect Layout anchors for frame-corner constraints. To use the root numeric Decoration/Backing Anchor and Pivot fields instead, enable Auto Place Ornaments. Runtime still starts hidden until a graph cue.
