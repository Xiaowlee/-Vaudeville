# Scene versions

Open `Scene/00_main_menu.tscn` or press F5 to choose a prototype.

- **2.0:** original onboarding, headphones, key/door and street/bump prototype.
- **2.1:** continuous narration and narrator agency experiments.
- **2.2:** Performer A baseline and C increased agency.
- **2.3:** current Acts 1–3 stage-performance prototype.
- **00_shared:** components used across versions; not standalone games.
- **component:** supporting UI/actor/animation scene.
- **template:** earlier unpopulated stage foundation; use the Acts 1–3 scene for playtesting.

Current playable scene: `Scene/StageActs/2.3_stage_acts_1_3.tscn`.
Edit current stage UI in `Scene/StageActs/2.3_component_stage_ui.tscn`.
Script filenames, story resources and scene node names were not renamed. Development milestone: 2026-09-27 naming pass; version labels are approved organizational groups, not reconstructed original creation dates.

## Rename reference

| Previous scene | Current scene |
|---|---|
| `Scene/Intro.tscn` | `Scene/00_main_menu.tscn` |
| `Scene/previous_prototypes.tscn` | `Scene/00_previous_prototypes_menu.tscn` |
| `Scene/prototype_1.tscn` | `Scene/2.0_00_onboarding.tscn` |
| `Scene/scene_1_headphones.tscn` | `Scene/2.0_01_headphones.tscn` |
| `Scene/scene_2_key.tscn` | `Scene/2.0_02_key_door.tscn` |
| `Scene/scene_3_bumpedIntoSb.tscn` | `Scene/2.0_03_street_bump.tscn` |
| `Scene/continuous_narration.tscn` | `Scene/2.1_continuous_narration.tscn` |
| `Scene/narrator_agency.tscn` | `Scene/2.1_narrator_agency.tscn` |
| `Scene/prototype_a.tscn` | `Scene/2.2_a_performer_baseline.tscn` |
| `Scene/prototype_c.tscn` | `Scene/2.2_c_increased_agency.tscn` |
| `Scene/performer_shared.tscn` | `Scene/2.2_shared_performer_base.tscn` |
| `Scene/StageActs/MainStage.tscn` | `Scene/StageActs/2.3_stage_acts_1_3.tscn` |
| `Scene/StageActs/StageUI.tscn` | `Scene/StageActs/2.3_component_stage_ui.tscn` |
| `Scene/StageActs/Actor.tscn` | `Scene/StageActs/2.3_component_actor.tscn` |
| `Scene/StageActs/DebugPanel.tscn` | `Scene/StageActs/2.3_component_debug.tscn` |
| `Scene/stage_performance.tscn` | `Scene/2.3_template_stage_foundation.tscn` |
| `Scene/dialogue_view.tscn` | `Scene/2.3_template_dialogue_view.tscn` |
| `Scene/stage_debug.tscn` | `Scene/2.3_template_debug.tscn` |
| `Scene/Bumped.tscn` | `Scene/2.0_component_bump_animation.tscn` |
| `Scene/Character standby.tscn` | `Scene/2.0_component_character_standby.tscn` |
| `Scene/DoorOpen.tscn` | `Scene/2.0_component_door_animation.tscn` |
| `Scene/wearHeadPhone.tscn` | `Scene/2.0_component_headphones_animation.tscn` |
| `Scene/SentenceRoot.tscn` | `Scene/2.0_component_sentence_ui.tscn` |
| `Scene/WordCard.tscn` | `Scene/2.0_component_word_card.tscn` |
| `Scene/narration_base.tscn` | `Scene/00_shared_narration_base.tscn` |
| `Scene/stage_view.tscn` | `Scene/00_shared_stage_view.tscn` |
| `Scene/chapter_audio.tscn` | `Scene/00_shared_chapter_audio.tscn` |
| `Scene/ui_audio.tscn` | `Scene/00_shared_ui_audio.tscn` |
| `Scene/speech_monitor.tscn` | `Scene/00_shared_speech_monitor.tscn` |
| `Scene/phone_cue_bridge.tscn` | `Scene/00_shared_phone_cue_bridge.tscn` |
