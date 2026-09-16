> Updated presentation: see NARRATION_PACING_GUIDE.md. Narration and consequences now show one blank-line-delimited beat at a time, waiting for reading or fallback; the earlier append-only feed description below is superseded.

# Prototype 2 designer controls

Run F5 > Prototype 2, or open Scene/narrator_agency.tscn and press F6.

Select Story/narrator_agency.tres in Godot FileSystem. Expand Moments, then a numbered resource:
- Moment Id names this passage (choice_01, choice_02, choice_03).
- Narration Text and Prompt Text hold the passage and visible options. Keep Prompt Text consistent with the options you author.
- Options contains 2-4 option resources. Each has Category, Accepted Answers (words/synonyms), Response Text (enter 1-3 lines), Reconnect Point, Ends Story and Ending Text.
- For choice moments use the fields inside Options; the inherited single-answer fields from Prototype 1 are unused.
- Default Option is a ONE-based option number used when the player presses Use default.

Reconnect Point blank means continue to the next Moments entry. A name such as choice_03 resumes at the entry with that Moment Id, after displaying the selected response. Only existing later points are allowed; errors appear in Output and on screen. This intentionally prevents accidental loops. Both options can reconnect to the same point. The initial first and second choices reconnect to choice_02 and choice_03 respectively.

Check Ends Story to finish after an option's response. Set Ending Text for its short ending; blank uses the story-level ending. Leave Reconnect Point empty on an ending. The final choice has two placeholder endings.

Save edits and rerun so speech vocabulary reloads. Add synonyms explicitly; categories are authored groups, not open-ended AI interpretation. Separate phrases with array entries, not commas inside one phrase. Different options at the same choice cannot share a normalized synonym.

The existing scrolling feed, fallback, Back and microphone system are reused. Scene/narrator_agency.tscn inherits Scene/continuous_narration.tscn; use local node overrides for Prototype 2 visuals. UI/prototype_theme.tres is shared. Branch Response Text appears immediately in the placeholder and text feed; no delay or loading screen is added.

Manual test: speak different options/synonyms across fresh runs, verify their response and shared next passage, compare both endings, retry after unclear input, test Use default and Back. Wait for Listening before speaking. Recognition can require repetition, especially at startup; no recognition threshold was changed.

Automated validation: all 16 authored paths, synonym selection, invalid input, named reconnect skipping, default ending, invalid routes and duplicate synonyms passed. Prototype 1 regression and both menu routes passed. Rendered starting screen inspected. Synthesized speech passed through Windows recognition for all three choices in a single worker session, after earlier fixtures showed low-confidence initial words. This is not a human microphone playtest.
