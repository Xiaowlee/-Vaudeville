# Designer controls — Scenes 0 and 1

Start by opening the scene in Godot and selecting its top node. Scene 0 is `Scene/prototype_1.tscn`; Scene 1 is `Scene/scene_1_headphones.tscn`. Scene 1 inherits the same controller and base layout. Save and rerun after changing gameplay settings.

## 1. Narrative content and required inputs

Expand **Content → Sentence Definition** on the scene's top node, or open the resource directly:

- Scene 0: `prototype_1/scene_0_sentence.tres`
- Scene 1: `prototype_1/scene_1_sentence.tres`

**Sentence Text** is the complete spoken sentence. **Correct Word** is the word that fills the blank. **Missing Word Index** selects its position, counting from zero. For Scene 1, “She picks up the headphones and puts them on.” uses `headphones`, index `4`.

The prefix, suffix, card text and recognition target now come from this resource. You do not need to type the sentence into separate labels. Text changes preview in the editor. If the word/index disagree, the Sentence node shows a configuration warning, and gameplay will not start with that invalid configuration.

**Distractors** supplies the other choices. The first registered card gets Correct Word; the following cards get the distractors in order. Fewer choices hide unused cards. For more than the existing three choices, duplicate a WordCard under Story, position it in the editor, and add its relative path to **Sentence → Word Cards**. No code change is needed. The existing card node names `On`, `Off`, and `Away` are historical; change their wording through the resource.

**Required Inputs → Require Drag / Require Voice / Require Face** controls which actions are needed. Scene 0 and Scene 1 retain drag + voice, with face off. Enabled stages run in the existing order: face, then drag, then voice. Disabling drag fills the word automatically; disabling voice completes after the other requirements. Disabling all three makes the response automatic. Face currently means the existing smile cue, not arbitrary emotions. This refactor does not add a new interaction-order editor or new Scene 2 gameplay.

**Prompts** includes the blank placeholder, Read out loud wording, idle message, phone prompt and accepted message. To create a separate story configuration later, duplicate the resource or use **Make Unique** before editing; otherwise scenes referencing the same resource share its changes.

## 2. UI placement and appearance

Select **Margin → Layout → Story** to move the overall interaction area. Select its **Sentence** child to adjust sentence anchors and offsets. Select the `On`, `Off`, and `Away` cards to change their starting positions. Use **Layout / Transform**, **Custom Minimum Size**, and **Theme Overrides** in the Inspector.

The sentence's **HBoxContainer** arranges PrefixLabel, WordDropZone and SuffixLabel. Containers own their children's positions, so move the row or change its **Theme Overrides → Constants → Separation** rather than entering offsets on those three children. Fonts, font sizes and colours remain editable on their nodes/themes. Right-click an instance and enable **Editable Children** when needed.

The blank reserves enough room for its correct card and placeholder. **WordDropZone → Custom Minimum Size** is your minimum space; **Sentence → Fit Blank To Word** enables automatic content fitting. Keep that enabled for normal use. **SnapPoint** controls the centre of the inserted word. **ReadOutLoudLabel** retains its own anchors and placement.

Edit the base gameplay scene for shared layout changes, or use per-scene overrides for differences. Scene 1's stale positioning overrides were removed so it follows the current base placement. No script moves the sentence to a fixed screen coordinate.

## 3. Timing

Select the scene's top node:

- **Response → Response Delay**: pause after accepted inputs, before the visual response starts.
- **Response → Light Fade Duration**: dark overlay fade time.
- **Response → Face Response Delay**: pause after face feedback, before the next required input.
- **Transition → Transition Delay**: time after the visual response finishes, before advancing.
- **Transition → Auto Advance**: turn automatic progression on/off. Next still works when a destination is assigned.
- **Transition → Next Scene**: destination; empty means remain at the completed scene.

Animation playback speed/duration remains in SpriteFrames or AnimationPlayer. The light-on animation and overlay fade are separate; adjust both if you want matching durations. A card's **Follow Speed** and **Snap Back Seconds** remain on the card's Inspector.

## 4. Animations and scene-specific responses

Select **Room → AnimatedSprite2D** to assign/edit **Sprite Frames** and artwork. Select **Room** to choose **Standby Animation**, **Action Animation**, **Return To Standby**, and optional **Action Layers**. Its **Sprite Path** points at the main animated sprite.

On the scene's top node, **Response → Animation Player Path / Animation Name** selects an additional scene-authored animation, such as Scene 0's light response. Use AnimationPlayer tracks for scene-specific visibility, colour, sound or property changes; you normally do not need a different controller. Leave Animation Name empty if there is no additional AnimationPlayer response. Actions should be non-looping; standby loops.

The existing **story_completed** signal fires when inputs are accepted, before the visual response, as before. **interaction_state_changed** reports the overall stage; `COMPLETED` means the response has finished. Keep Completion Signal Name at its default unless you intentionally need a custom integration.

## 5. What the shared controller does

`Script/prototype.gd` reads the scene configuration, enables the required inputs, starts/stops speech, receives existing phone events, runs the configured response and guards against repeated completion/transition. `Script/sentence_controller.gd` fills the authored labels/cards, checks dragging, applies sentence colours/outlines and passes accepted narration into progression.

The resource script describes editable fields and matching rules. It contains no default story sentence; the story lives in the `.tres` files. The small drop-zone helper provides content sizing without overwriting your anchors.

## 6. Code you normally do not need to edit

For wording, requirements, layout, timing and animation changes, use resources and the Inspector. Normally leave `prototype.gd`, `sentence_controller.gd`, `sentence_definition.gd`, `word_tile.gd`, `word_drop_zone.gd`, and `room.gd` alone.

Also leave the working speech and networking internals alone: `speech_transcriber.gd`, `windows_speech.ps1`, `phone_input_hook.gd`, and the companion/relay code. They were not changed in this refactor. The root's **Legacy Compatibility** field preserves the existing face-first scene; use resource toggles for the designer-configured scenes.

## 7. Reading Output messages

Messages begin with the resource's scene ID, for example `[scene_1_headphones]`.

- **Scene**: which scene file started.
- **State: WAITING_FOR_DRAG / WAITING_FOR_VOICE / WAITING_FOR_FACE**: what the game needs next.
- **Drag success**: the correct card was dropped in the blank.
- **Speech final**: a transcript arrived; it may still be rejected by the sentence matcher.
- **Voice success**: the transcript matched the current sentence.
- **Voice status: Mic listening**: Windows recognition is ready. “Voice unavailable” means it could not start, or the automated test deliberately disabled it.
- **Phone / Face presence / Face success**: connection status, detection status, and accepted smile event.
- **FACE_RESPONSE / RESPONDING**: feedback/animation is running; the game is not yet ready to advance.
- **Animation**: standby, action start, final-frame hold or return to standby.
- **COMPLETED / Scene completion**: the visual response finished.
- **Transition**: the scheduled delay or destination being loaded.
- **Debug manual success**: Ctrl+Enter bypassed voice for development. It is not evidence of recognition.
- **CONFIGURATION_ERROR**: fix the resource/path warning before testing.

Disable **Debug Logging** on the gameplay root and Room to quiet the new progression/animation messages. Existing recognizer transcript diagnostics remain available.

## Verification for this refactor

Scene 0 and Scene 1 input-event regression tests passed, including drag, wrong-word rejection, voice completion, one-shot animations, manual Next and timed transitions. All eight input-toggle combinations passed with temporary test configurations. Scene 1 layout bounds passed at two display widths; rendered before/after insertion screenshots were inspected. Editor-mode resource and font updates passed.

Both scenes initialized the actual Windows default-device microphone recognizer. Generated audio produced correct final transcripts for both target sentences; “off” remained “off” in the opposite-word test. This verifies the engine and matching path, not a fresh human-voice playtest. The unchanged WSS relay passed its existing synthetic-phone integration test. Actual phone-camera detection was not re-performed by a human here.

No Scene 2 scene/resource or network/recognizer source files were changed. The existing shared-controller compatibility test still passes. Scene 1's pre-existing next-scene assignment was retained.
