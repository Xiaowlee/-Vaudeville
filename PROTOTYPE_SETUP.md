> Updated presentation: see NARRATION_PACING_GUIDE.md. Narration and consequences now show one blank-line-delimited beat at a time, waiting for reading or fallback; the earlier append-only feed description below is superseded.

# Prototype 1: Continuous Narration

Run project.godot from folio-2-test-2, press F5, then Prototype 1. Or open Scene/continuous_narration.tscn and press F6.
Wait for Listening. Read the placeholder passage and say ready, open, then continue at their respective prompts. Each answer adds a response and the next passage to the same scrolling feed. The microphone remains active between gaps. There is no gameplay timer, dragging, or sentence verification.

## Edit content without code
Select Story/continuous_narration.tres in FileSystem, expand Moments, then each numbered resource in the Inspector:
- Narration Text: passage to read.
- Prompt Text: visible instruction at its gap.
- Answer Category: designer label grouping the accepted phrases (also appears in debug logs).
- Accepted Answers: spoken words/phrases for that category; add synonyms explicitly.
- Response Text: immediate placeholder reaction, also appended to the feed.
- Default Response Text: optional different text when Use default is pressed; blank uses Response Text.
The story also contains Ending Text and editable status messages. Save before rerunning. The scene root's Story field assigns this resource. StoryText's editor preview is replaced by this resource during play.

## Edit appearance
Open Scene/continuous_narration.tscn. Select StoryText, VisualPlaceholder/Label, Title, Status, DefaultResponse, RetryMicrophone or Back to change layout/anchors and Theme Overrides. Scene/continuous_narration.tscn retains mode-specific layout overrides. UI/prototype_theme.tres is shared: make it unique before changing it only for Prototype 1. No new artwork is required.

## Recovery and limits
Wrong/unclear recognition keeps the same prompt available. Use default advances without voice. Retry microphone restarts listening after an unavailable/stopped microphone. Back stops the listener when the scene exits.
This uses the existing Windows en-US recognizer and default recording device. Categories are authored phrase groups, not open-ended semantic interpretation. Speak an accepted phrase alone, or the narration followed by the phrase; allow a short natural pause for a final recognition result. Narration is not scored. The feed follows appended content rather than scrolling at a timed speed; previous text remains available by scrolling up. New content requires rerunning to reload the vocabulary.

## Code responsibilities
Script/continuous_narration.gd handles progression, fallback and feed updates. Script/narration_story.gd and narration_moment.gd define Inspector fields and matching. Normally edit the resource and scene, not these scripts. The existing speech_transcriber.gd and windows_speech.ps1 are reused; continuous mode is opt-in and legacy calls retain their behavior. Prototype 2 now reuses this controller with editable options and reconnects; see NARRATOR_AGENCY_SETUP.md.
Logs: [Narration] identifies the current moment/category; [Narration voice] records accepted input; [Narration response] shows the category and whether default was used; [Speech bridge] reports recognizer events; [Speech error] explains microphone/worker problems.

## Validation
Passed logic checks for retries, aliases, combined narration+answer, default completion and late results; menu/Back checks; rendered feed inspection; all three moments using synthesized audio through Windows recognition without restarting the worker; legacy default microphone startup. Human microphone playtesting remains necessary.
