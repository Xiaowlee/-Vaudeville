# Puppet stage visual test

Open `puppet_stage_test.tscn` and press F6 (Run Current Scene). F5 still runs the normal game.

Move the mouse to see depth. Use **Flat / off** for a comparison, or **Slow automatic** to see movement without touching the mouse. Depth controls the strength. **Flip characters** or Space turns every character into its second pose; press again to return. Menu returns to the normal menu. This scene does not run speech or story logic.

## What to edit in Godot

| Select in the scene tree | Edit in Inspector | Result |
|---|---|---|
| PuppetStageTest | Depth Strength / Smoothing / Movement Mode | Overall motion |
| World > a scenery group | Travel X / Y | How far that layer moves; 0 stays still |
| World > Performers > Player (or Actor1 / StageManager) | Flip Seconds | Turn duration |
| Same character | Sheet Frames / File Frames | Two alternative sources of poses |
| Character > Card > Art | Sprite Frames | Open the bottom SpriteFrames panel to inspect the poses |
| Character root | Position | Where the puppet stands |
| Character > Card > Art | Scale | Puppet size, independent of flip width |

Depth order, back to front:

Backdrop → rear wings → middle curtains → front wings → floor + performers → near curtains → audience → fixed decorative frame

The flip is a 2D illusion: width 100% → 1.5% → change SpriteFrames frame → width 100%. It is a half-turn reveal, not a true rotating 3D model; there is no drawn side or back. Both poses share a 1752×1752 canvas. Keep future feet/pivot locations consistent to reduce visible jumps. No automatic cropping is applied.

## Your supplied files

All originals remain untouched. This folder contains local copies for reliable Godot imports.

- Nine stage images: 3840×2160, transparent, aligned on the same canvas. Keep that shared canvas when re-exporting.
- Individual character files 1/2 are byte-identical, as are 3/4 and 5/6. Only one copy of each identical pair is imported; both pose slots deliberately reference it. In Individual files mode the turn happens, but the pose cannot change until you provide a genuinely different second image.
- TestSheet.png: 7008×3504, a 4-column × 2-row grid of 1752×1752 cells.
- Player uses row 1 columns 1–2; Actor 1 uses row 2 columns 3–4; Stage Manager uses row 2 columns 1–2. The two remaining sheet cells are not used in this trial.

## Which format should you use?

Use **individual named PNGs while drawing and revising**: `player_pose_a.png`, `player_pose_b.png`, etc. It is easier to replace one drawing and see what each file means. Both formats work through the same SpriteFrames resource, so the flip code does not change.

For a finished animation sequence, a **sheet per character** can be convenient. In SpriteFrames choose Add frames from a Sprite Sheet; for this test set Horizontal=4 and Vertical=2, then select the relevant cells. For individual images, drag them into the frame list in the intended order.

A sheet is not automatically smaller or faster. This sheet includes eight large cells, including artwork the test does not use; PNG file size is not runtime texture memory. Do not pack every character into a huge sheet just to reduce file count. First settle the art and measure on the target device; reduce export resolution if its screen size allows. Preserve full-resolution source art separately.

Godot reference: https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html

This is an isolated visual experiment, not integrated into the story. Next judge depth with mouse idle, foreground edge coverage, turn readability and whether pose alignment feels deliberate.


## Inspector controls and reliable placement (October 27)

Select **PuppetStageTest**: Stage Frame > Design Size is your composition size (default 1280×720). A green outline and centre line appear in the 2D editor only. Place the artwork inside that frame; the complete composition scales uniformly to fit the running window, reserving room for test controls. It does not stretch to fill a different aspect ratio. Select EditorFrame and press F to find the stage, then zoom out if needed. Keep World scale at 1 in the editor; edit individual layers, not World, because runtime fitting controls World.

Default Depth Strength, Smoothing and Movement Mode are Inspector settings; the runtime controls now start from those saved defaults. Changes using runtime sliders are temporary. Save defaults in the normal Inspector, not Remote.

Select **World > Performers > Player / Actor1 / StageManager**:

| Inspector setting | Meaning |
|---|---|
| Flip Seconds | Time for one turn; lower = faster |
| Character Size | Overall artwork size, keeping the feet pivot fixed |
| Drawing Offset | Align the illustrated feet with the green cross; initial Y=-190 |
| Talking | Bounce while enabled; turn off to stop bouncing |
| Bounce Height | Jump height in stage pixels |
| Bounce Speed | Bounces per second |
| Sway Degrees | Maximum idle lean; 0 disables it |
| Sway Speed | Sway cycles per second |
| Preview Motion In Editor | Animate this puppet while arranging the scene |

Move the **character root** to position its feet on the floor. Use **Character Size** to resize it; do not resize Card, whose X scale belongs to the flip. Swing rotates around the character root/feet. Card handles the flip independently. Art retains its existing base scale. Both poses currently share one drawing offset; if future poses have differently positioned feet, align them on the original canvas before export.

In the running test, Talking toggles all three characters. In normal Inspector, Talking and editor preview allow testing a single character. Future dialogue integration calls `set_talking(true)` at the line start and `set_talking(false)` at its end. This trial does not yet listen to the story or microphone.


## Option A framing — current rule

The stage is always fitted proportionally inside the available screen. Extra space uses Border Color, and artwork beyond the design frame is masked. Oversized layers remain useful for parallax but cannot leak into the surrounding border.

Select PuppetStageTest > Stage Frame > Editor Screen to preview 16:9, 16:10, Ultrawide or Custom. These all use the same artwork and the same layout function as gameplay. They do NOT create separate versions. The green outline is the exact visible stage boundary. Keep important art inside it; move/resize child artwork, not World (World is controlled by automatic fitting). Character Size and feet-root placement still work normally.

Design Size remains 1280×720. Controls Height reserves space for the test toolbar; the same space is reserved in the editor. Toolbar buttons wrap when needed. Change Border Color to style the spare space. No main-game scaling settings were changed.


## Updated individual poses
Individual files are now the default. Source mapping: Player = Layer 4 Copy / Layer 4 Copz; Actor 1 = Layer 3 Copy / Layer 3 Copz; Stage Manager = Layer 3 / Layer 4. Mobile files are excluded. Existing TestSheet is unchanged.
Select World > Performers > Player (or Actor1 / StageManager), then Artwork > File Frames or Sheet Frames to edit the poses. The Art child uses AnimatedSprite2D. The sheet is 4 columns by 2 rows, 1752 pixels per cell. Player uses top row columns 1-2; Stage Manager bottom row columns 1-2; Actor1 bottom row columns 3-4. Flip narrows the Card, swaps pose at its thinnest point, then opens it.

## Current responsive rule (supersedes Option A borders)
No letterbox masks. Characters and floor scale together proportionally. Surrounding curtains, background, audience and decorative frame follow width and height independently. Backdrop Color fills any transparency behind the art. Test controls reserve the bottom area. Editor Screen previews the same layout calculation used at runtime.

Puppet viewport now uses the entire window height. Testing controls overlay the bottom with a transparent panel instead of reserving a dark strip. Their Controls Height sets overlay height only. Editor and runtime share this full-window layout.

Hand-drawn motion trial: select World/Performers/Player, Actor1 or StageManager > Motion Style > Hand Drawn Motion; Motion FPS defaults to 8. Off preserves smooth motion. Flip, talking bounce and idle sway sample held poses, without lowering game frame rate. Preview Motion In Editor enables sway/bounce in editor; Talking enables bounce. Existing Flip Seconds controls total turn duration. This simulates stepped cutout movement, not newly drawn in-between artwork.

October 28 desktop lighting trial: World/Lighting in puppet_stage_test provides Enabled, Focus Character, Scenery Tint, Inactive Tint, Light Color, Beam Opacity/Width, Pool Opacity/Size, Edge Softness, Light Offset, optional Feet Shadow/Shadow Opacity (OFF by default). Beam/pool drawn behind original-colour active actor; inactive actors separately tinted. No global blur, new image assets or real shadow renderer. User intentionally omitted feet shadow and aesthetically prefers second masked approach; beam first is an experiment, not a final aesthetic decision. Second masked technique remains pending. Main game/mobile untouched.

Lighting transitions: World/Lighting > Lighting Mode switches World versus Character focus; Focus Character switches actor, Transition Seconds sets fade/travel time. Preview Cycle demonstrates World > Player > Actor1 > StageManager > World with Preview Hold Seconds between targets. Interruptions blend from current state. World restores original colours and removes beam; Enabled fades off. Top Softness sharpens upper beam, Edge Softness controls lower edge/pool. Main game unaffected.

October 28 dialogue visual trial: run Experiments/PuppetStage/dialogue_layout_trial.tscn with F6. Reuses puppet scene via instance, with two styles (Beside character / Lower panel), previous/next/restart excerpt and Flip poses. Live-loads authored narration/dialogue from four Act1 manifest passages (Once upon a time, Actor1 question, FirstCue, SecondCue); words preserved with display-only pagination. Phone/sound/stage notes excluded from this desktop visual test. Narrator/manager occupy opposite side in lower mode; one voice visible at a time. Panel backing is below performers, readable text above. Trial actor arrangement adjusted only in this instance to leave reading space; main game, graph, recognition and mobile unmodified. No microphone or AI in this layout rehearsal. Inspector DialogueTrial controls layout style, text size, panel visibility/colour; original decorative script font unavailable, existing Jacques Francois used. All excerpt pages and both layouts exercised at16:9/16:10, rendered comparisons inspected. Backdrop dramatic text and cut-in panels remain pending.

Dialogue placement editing: DialogueTrial Inspector exposes Beside Left/Right, Narrator Bottom, Lower Left/Right as normalized Rect2 values (Position and Size, fractions of viewport), Text Padding, Text Size, Name Extra Size, Text Color and panel appearance. Runtime Remote Inspector previews live; Local scene edits persist on save/re-run. Layout/Text transforms are controlled each frame, so do not advise dragging them as persistent placement.

October28 dialogue alignment/responsive revision: trial is now @tool with Preview Page for local editor layout; removed runtime-only character .8 size and +/-160/120 reposition overrides. Authored transforms retained. Narrator/character Text Alignment independently Left/Center/Right; Block Alignment Top/Center/Bottom; Text Block Width and Block Horizontal Alignment let the reading block be centred inside its zone. Smart Placement (default on) evaluates left/right/above/below against visible puppet rectangles once per page/layout change, holding position through bounce. Preferred Placement biases this selection; disabling Smart Placement uses manual normalized zones. Show Third Character uses existing manager art as occupancy stand-in only, not a completed Act3 scene or new Actor2 artwork. Character Fit Mode preserves authored size by default; Reserve Dialogue Space uniformly reduces performer group by exposed reserve fraction, in both editor/runtime. No player settings added. Same preview screen size must be selected to compare editor composition with a running window. Tested three window shapes, all alignments, 2/3 puppets, stable boxes and size preservation. Geometric placement is an experimental preference scorer, not a guarantee against every pose/content overlap.

October28 readability repair supersedes least-overlap smart ranking: narrator/StageManager use centred narrator zone in BOTH styles. Character positions are not authored by the dialogue script. Smart/protected placement reserves alpha-used rectangles for every current SpriteFrames pose and sway/bounce extremes plus parallax margin; moving roots cause overlap re-evaluation. It subtracts occupied space into free rectangles and accepts only clear, fitting reading areas. When no clear region fits, a foreground caption and soft backing ensure legibility; decorative backing stays behind puppets. This is rectangular paragraph placement, NOT contour-following text layout. Optional Text Outline Enabled/Size/Color and Overlap Soft Backing/Color support comparisons. Protect Reading Area (default on) also checks manual zones, so intentional overlap experiments require disabling it, with optional outline/backing. Body switched to wrapping Label, removing scrollbars; long explicit-newline pages grow upward within the screen. Typography now scales by min(width ratio,height ratio).
Puppet artwork placement is no longer reset every frame. Drawing Offset still deliberately changes it when edited, but moving Art directly now persists. Move World/Performers/Player or Actor1 (Transform > Position, lower Y moves up) for authored starting placement; Swing/Card remain animation pivots, World is the automatic screen-fitting parent. Parallax applies offsets relative to current group placement rather than restoring a captured starting position, allowing subsequent movement. 264 page/layout/crowding cases across 3 window shapes passed viewport/readability checks; root/art movement retention verified. No final Act3 scene or contour-flow typography claimed.
