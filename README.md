# Beneath the Lines — Godot project

Open project.godot and press F5 for the main game.

- Main game: Scene/StageActs/stage_graph_game.tscn
- Main menu and previous-prototypes menu: Scene/
- Earlier prototypes, kept playable: Scene/Prototypes/2_0, 2_1, 2_2, 2_3 and Legacy
- Reused scenes: Scene/Shared and Scene/StageActs/Components
- Current visual trial: Experiments/PuppetStage/dialogue_layout_trial.tscn (F6); its existing Scripts/, Shaders/ and Art/ hold supporting files
- Current visual trial graph: Experiments/PuppetStage/visual_story.tres
- Main story graph: Story/StageActs/Graph/acts_0_3_cleaned.tres
- [Main-game editing guide](Story/StageActs/Graph/EDITING.md)
- [Visual-trial editing guide](Experiments/PuppetStage/README.md)
- [Scene locations](Docs/SCENE_VERSIONS.md)
- Shared current decisions: PROJECT_CONTEXT.md; script/recording handoff: SCRIPT_RECORDING_HANDOFF.md
- Phone website/relay: mobile-companion (kept intact, hidden from Godot's resource importer)

Export presets select the kept scenes/story resources and required dependencies, with runtime story/AI text data included explicitly. Experiments, tests, tools, guides, web sources and build output are excluded. Previous prototypes remain in the export while they are still offered by the menus; remove their menu access and selections together when deliberately preparing the final release. Local speech executables/models still need their existing external deployment setup.

Tests are in tests/; older checks moved from Script/ are in tests/Legacy/. Historical systems/hosting notes are in Docs/.

October 29 cleanup recovery: D:/RMIT/Master/Studio 1/Folio 2/Week 11/trial_recovery/project_cleanup_20261029_004522 contains the exact move map, archived redundant redirects, unused CSV-generated translations and pre-edit copies. No prototype source, original art, canonical Twine, speech model or website code was deleted. Continue work in the existing scenes and resources; create supporting files only where reuse or the tool's resource format requires them.

Current story update: edit/export Story Script/Beneath the Lines - IMPORT THIS.html, then run `python tools/sync_w12_story.py --overwrite` from the project. This replaces imported graph content; recovery copies go outside the project. Check with `python tests/story-script.py` and Godot `--headless --path . --script res://tests/story-script.gd`. Twine is the writing source; save graph-only edits elsewhere before reimporting.
