# Actor voice integration — 30 October 2026

76 named takes are copied unchanged into Actor1/Actor2 here. The original VoiceOver folders are untouched. Matching uses BOTH the speaker and exact wording (ignoring punctuation/case/spacing); repeated story branches share one recording. Story words and routes were not rewritten. Catalogue: Story/StageActs/Graph/voice_recordings.json. Main game GameController exposes Voice Catalog Path. Audio finishes before the normal three-second automatic hold; Space still skips.

## Needs author review

- Copied with filename spacing corrected (original untouched): A1_1_ACTOR 1'sQuestion__ACTOR1_01 .mp3
- Missing ID: A1_3_FirstCue__ACTOR1_01 — A writer?
- Not assigned: VoiceOver\Mother\A2_7_Agree__ACTOR1_01.mp3
- Copied with filename spacing corrected (original untouched): A3_4_FollowPlay__ACTOR2_01 .mp3
- Missing ID: A3_4_FollowPlay__ACTOR2_02 — But the script won't answer everything.



The one who keeps pulling the string...
- Not assigned: VoiceOver\Actor2\untitled.mp3

- Actor2/untitled.mp3: existing local Whisper transcribes “But the script won't answer everything.” This appears to be the missing FollowPlay_02, but its script also includes “The one who keeps pulling the string...”. Left unassigned until you confirm the take and whether that trailing thought belongs in it.
- A2_7_Agree__ACTOR1_01 is marked HOLD (“No?” does not match the agreement branch). The supplied recording is left unassigned, not silently used.
- A1_1_ACTOR 1'sQuestion__ACTOR1_02 remains HOLD: “declare the path you roles” needs your wording correction. No recording expected yet.
- The script still notes a possible character-name call with no exact spoken line. No invented call or recording.
- Provisional takeover recordings are linked where the current story uses their exact words; their writing remains marked provisional in your source recording scripts.
- Unrecorded dialogue remains readable and uses existing pacing; no synthetic replacement voice is generated. Stage Manager/MC/narration were not included in this delivery.

Validation details will be reported in chat. Filename matching does not establish that every recording contains its labelled words; automated spot transcription is a check, not a full human listening review.

## Verified integration

- All 76 streams import/load and have nonzero duration; combined duration about 6 minutes 3 seconds. All game copies match source files byte for byte.
- 87 current actor dialogue events across branches resolve to these recordings. Case/punctuation/spacing are ignored; different wording does not receive an unrelated take.
- Playback checks pass: completed text does not stop actor audio; automatic hold starts after audio ends; manual skip stops audio; moving to an unvoiced line clears old audio; exact recorded fallback lines also play.
- Existing 109 graph-link / 69-passage tests pass. Headless shutdown still reports ObjectDB/resource-in-use cleanup warnings, including in the existing story test; no script/assertion failures.
- Seven local Whisper spot checks completed. Some transcripts suggest minor delivery differences (“Hey, say it again” vs “Say it again”; contractions/plurals in the entrance and birthday speech). The very short Actor2 “A princess” was transcribed “A brain says...”, so recognition alone cannot confirm that take. Review these recordings by ear before changing subtitles; no source wording was changed based on automatic transcription.
