# Scene 0 editing and testing

Read ../PROJECT_CONTEXT.md before changing gameplay.

F5: preserved Intro → Start Game → Scene 0. Drag **on** into the blank and read when Mic listening appears. Ctrl+Enter is a development fallback only.

- Edit Scene/2.0_component_word_card.tscn for Button font, padding, normal/hover/pressed/disabled styles.
- Edit Scene/2.0_component_sentence_ui.tscn for manually placed prefix/suffix, blank, SnapPoint, prompt and typography. Enable Editable Children on its gameplay instance for local overrides. State colours are on SentenceRoot. Ready outline size/colour are Theme Overrides on labels/card.
- Edit the sentence resource for target and correct/distractor words. Keep authored label/card text consistent with that target; no script rebuilds layout.
- Room/AnimatedSprite2D holds editable SpriteFrames and transform. Room exposes standby/action names and return-to-standby. Standby loops; action runs once. Scene 0 currently uses the existing light_on AnimationPlayer because no light-on action sheet is identified.
- Gameplay root exposes next_scene, transition_delay (5 seconds), Intro and completion animation/signal. No later destination is invented.

Voice uses Windows default recording input directly, not Godot's legacy amplitude bus or Vosk. The helper loads an en-US phrase grammar including target and distractor alternatives so opposite words can be rejected by the matcher. Partial/final/rejected results, confidence, engine and audio format print in Output. No new install. Human microphone accuracy still needs a live check. Include *.ps1 in export's non-resource filters.

Run: Godot --headless --path <project> --script res://Script/scene0_interaction_test.gd
The test uses actual mouse input events and separately injected transcripts; it does not assert live microphone recognition.

## Scene 1: Headphones
Scene/2.0_01_headphones.tscn inherits Scene/2.0_00_onboarding.tscn. Scene 0's Next and auto-next now lead here. Open Scene 1 and press F6 to test it directly.

Edit On/Off/Away Button text (headphones/book/phone) under Margin/Layout/Story and the matching scene_1_sentence.tres resource. Sentence's Editable Children expose prefix, suffix, blank and snap point. No layout is generated in scripts.

Room/AnimatedSprite2D uses the supplied standby and wear sprite sheets. HeadphoneObject is the supplied synchronized object layer. Room action_animation is headphones; return_to_standby is off to hold the last frame. All transforms and SpriteFrames remain editable. Root starts_dark is false and animation_name is empty so Scene 0's light-on animation is not replayed.

Next appears after the animation. Assign next_scene when Scene 2 exists; until then it stays completed with Next disabled. Five-second auto-next is already supported and tested with a temporary destination.

Run Scene 1 tests with --script res://Script/scene1_interaction_test.gd; Scene 0 regression tests remain res://Script/scene0_interaction_test.gd. The user confirms Scene 0 voice works; the working recognition implementation was preserved.
