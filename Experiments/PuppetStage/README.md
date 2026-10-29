## Current editing workflow — 29 October

Run `dialogue_layout_trial.tscn` with F6. It reads `visual_story.tres`, a Dialogue Nodes graph containing the two existing Act 1/Act 3 visual excerpts. This is the isolated visual trial, not the main game's story resource. The words and actor labels were copied from the existing imported manifest; the writing chat's subsequent Mom/mother correction has NOT been imported here.

Open `visual_story.tres` in Dialogue Nodes. Right-click the graph (or use Add) > **StageVisual**. Connect its input/output arrows before the affected dialogue. Select its first dropdown:
- **Cut-in illustration:** Show or Hide; NPC right / MC left / Custom; actor close-up or separate image picker; crop; width/height (0 follows image); size; hold seconds. Zero hold means until a Hide node. Add Hide after the desired section, not on a separate timing list.
- **Text effect:** Normal/still, Pop and settle, Gentle wave, Jitter; strength/speed/reveal rate. The setting persists until another Text cue. Graph settings override DialogueTrial's default motion controls.
- **Stage atmosphere:** On/off, replacement pattern image, pattern/background colours, horizontal/vertical scrolling and tile size. Empty image uses the stage's supplied pattern. An Act 3 sample changes the palette/speed at “Why writing?”. No shape animation or border replacement.
Save the graph and restart F6 to load edits. The plugin's generic Run preview uses its stock dialogue box; F6 on the trial is the stage visual preview. Previous/Next reconstruct settings from the graph so revisiting a line restores its effects.

Placement: FrameCutInLayer/FrameCutIn/RightArea, LeftArea, CustomArea are draggable/resizable. The old Cues array has been removed. DialogueTrial/Visual Story picks the graph; Preview Page previews its current page in the editor.
Atmosphere defaults/mask: World/Atmosphere. Pattern.png copied unchanged as Art/surround_pattern.png. The shader scrolls only the texture; an editable normalized stage-opening polygon stays fixed. Optional Outside Mask accepts a registered black-stage/white-outside texture for exact art-directed masking. Current polygon is an initial approximation, not an automatically extracted decorative-border silhouette. Preview Motion enables editor movement. Keep opening points >=3; an invalid polygon hides the pattern instead of covering the stage.
Audience: World/Audience > Audience Motion, Audience Bob Height/Speed, Preview Audience Motion. Uses the existing SINGLE audience strip, not individually separated people. Authored Art placement and smooth parallax are preserved; audience and border render above the surrounding pattern.

Verification: actual DialogueParser traversed both excerpts and emitted Stage Visual signals; actual GraphEdit loaded/saved/reloaded 21 visual cues with links; editor image picker, undo/redo, colour/texture disk persistence passed. All pages forward/back in Act1/3 checked. Rendered stationary shader mask (transparent centre, opaque exterior across phase changes), scrolling, audience movement, palette restoration, and 16:9/16:10/ultrawide/4:3 checked. Runtime test log D:/visual-graph-check.log; editor log D:/visual-graph-editor-check.log. Main game, voice/AI, Twine source and mobile were not changed. The CSV is now kept as a plain authoring file, so the previous accidental translation-import errors are removed.


## Folder layout

The two existing scenes and visual_story.tres remain here. Art/ holds the supplied runtime images, Scripts/ holds the reused support code, and Shaders/ holds the two visual materials. The private cut-in settings script was folded into frame_cut_in.gd. Keep testing in this same trial; do not duplicate scenes or assets for each iteration.
