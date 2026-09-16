# Readable narration: designer guide

Run F5 and choose either prototype. Wait for READING, then read the visible passage aloud. A natural pause lets the recognizer finish the result. The next passage appears in the same place. Only after the preceding passages are read does the prompt appear with LISTENING. Speak an accepted answer, see the actual recognised words, then read the consequence. The recognizer stays active throughout.

## Edit beats and responses
Open Story/continuous_narration.tres or Story/narrator_agency.tres. In Moments, edit Narration Text. ONE BLANK LINE separates beats; a single newline just wraps content within a beat. Aim for 1-3 sentences per beat. There is no new story format or duplicated chapter. The same blank-line convention applies to Response Text, Default Response Text and Ending Text. Existing prompt text, aliases, option categories and reconnect IDs remain in their original Inspector fields. Save and rerun to refresh speech vocabulary.

## Edit presentation
Open Scene/continuous_narration.tscn. Both modes share this screen; narrator_agency.tscn inherits it. StoryText is the active reading/response area. Prompt is separate and visible only when answering. Recognition shows actual final speech text; Status provides the state/instruction. Select nodes to edit anchors, offsets, fonts, sizes and spacing. The visual placeholder and background remain scene-authored. The shared root exports active/inactive colours including alpha. UI/prototype_theme.tres retains the existing font and button style.

## Edit pacing and feedback
On the scene root: Recognition Display Duration controls the acknowledgement pause. Transition Delay is the pause AFTER reading completion. Prompt Delay delays the prompt after the last narrative beat. None of these advances unread text. Response completion also waits for speech/fallback, rather than forcing a fixed response reading duration. Player Messages contains editable status wording. Reading Coverage is an internal recognition tolerance; it is not shown as a score.

## Recovery
Read the passage again if it stalls. Reading fallback skips the current reading/response beat and is explicitly manual. Use default appears at prompts and selects the existing default outcome, with no fake transcript. Retry microphone is shown if the listener fails. Back exits either mode. Starting/unavailable microphone messages remain distinct from a ready listener.

## What to test
Read at a comfortable speed, pause naturally, and check that only the current beat is dominant. Confirm the first prompt waits for its narration. Try synonyms and an unaccepted response. Confirm the displayed transcript reflects what was recognised. Read each consequence before the next passage. Test Reading fallback, Use default, all three Prototype 2 endings, and Back during a transition. Adjust blank lines and layout in the editor, save/reload, and rerun.

## Limits and validation
The existing Windows phrase recognizer is retained; it is not free dictation or word-timed tracking. Speech is matched at beat/sentence level with tolerant ordered-word coverage, and may still need repetition or manual fallback. No confidence numbers are player-facing. Text entered as an unusually long beat remains scrollable; split it with blank lines for comfortable reading.
Both full flows and all 36 branch routes passed automated state checks. Rendered scenes were inspected. A paced synthesized-audio test passed through Windows recognition; this does not establish human microphone accuracy. Full story vocabulary microphone initialization and editor-mode answer saving were checked. No new phone, artwork, branching or chapter content was added.
