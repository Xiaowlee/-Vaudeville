# Actor voice integration — 30 October 2026

77 named takes are copied unchanged into Actor1/Actor2 here. The original VoiceOver folders are untouched. Matching uses BOTH the speaker and exact wording (ignoring punctuation/case/spacing); repeated story branches share one recording. Story words and routes were not rewritten. Catalogue: Story/StageActs/Graph/voice_recordings.json. Main game GameController exposes Voice Catalog Path. Audio finishes before the normal three-second automatic hold; Space still skips.

## Needs author review

- Copied with filename spacing corrected (original untouched): A1_1_ACTOR 1'sQuestion__ACTOR1_01 .mp3
- Missing ID: A1_3_FirstCue__ACTOR1_01 — A writer?
- Not assigned: VoiceOver\Mother\A2_7_Agree__ACTOR1_01.mp3
- Copied with filename spacing corrected (original untouched): A3_4_FollowPlay__ACTOR2_01 .mp3

- Not assigned: VoiceOver\Actor2\untitled.mp3

- Actor2/untitled.mp3 remains unassigned; the named FollowPlay_02 take supplied later is now linked (see below).
- A2_7_Agree__ACTOR1_01 is marked HOLD (“No?” does not match the agreement branch). The supplied recording is left unassigned, not silently used.
- A1_1_ACTOR 1'sQuestion__ACTOR1_02 remains HOLD: “declare the path you roles” needs your wording correction. No recording expected yet.
- The script still notes a possible character-name call with no exact spoken line. No invented call or recording.
- Provisional takeover recordings are linked where the current story uses their exact words; their writing remains marked provisional in your source recording scripts.
- Unrecorded dialogue remains readable and uses existing pacing; no synthetic replacement voice is generated. Stage Manager/MC/narration were not included in this delivery.

Validation details will be reported in chat. Filename matching does not establish that every recording contains its labelled words; automated spot transcription is a check, not a full human listening review.

## Verified integration

- All 77 streams import/load and have nonzero duration; combined duration about 6 minutes 3 seconds. All game copies match source files byte for byte.
- 88 current actor dialogue events across branches resolve to these recordings. Case/punctuation/spacing are ignored; different wording does not receive an unrelated take.
- Playback checks pass: completed text does not stop actor audio; automatic hold starts after audio ends; manual skip stops audio; moving to an unvoiced line clears old audio; exact recorded fallback lines also play.
- Existing 109 graph-link / 69-passage tests pass. Headless shutdown still reports ObjectDB/resource-in-use cleanup warnings, including in the existing story test; no script/assertion failures.
- Seven local Whisper spot checks completed. Some transcripts suggest minor delivery differences (“Hey, say it again” vs “Say it again”; contractions/plurals in the entrance and birthday speech). The very short Actor2 “A princess” was transcribed “A brain says...”, so recognition alone cannot confirm that take. Review these recordings by ear before changing subtitles; no source wording was changed based on automatic transcription.

## Confirmed follow-up recording

Xiaow supplied the named A3_4_FollowPlay__ACTOR2_02.mp3. It is now copied unchanged into Actor2 and linked to the existing combined spoken unit. This resolves the earlier missing Actor2 ID; the old untitled source remains untouched and is not imported. Actor1 “A writer?” and held wording decisions still remain outstanding. Current total:77 takes covering88 authored actor events.

## Stage Manager delivery

All 19 speech entries in the Stage Manager recording script are now linked using 22 selected WAV files in StageManager. The fairy-tale introduction uses the supplied P1/P2/P3 clips in order. Act1 ending narration uses BOTH45 and46: they are consecutive parts, not alternate takes. The Act2 narration uses48. Narration keeps its existing unlabelled narrator presentation.

71 WAV exports were reviewed locally (53 distinct audio payloads;18 repeated exports). Only selected speech takes are in the game; alternate takes, wordless reserves and the230MB BeneathTheLines.aup4 remain outside it. Selected-take/source mapping is in the existing external audio review folder. Existing Actor1/2 assets are unchanged.

- Misnamed: 01.A1_0_Begin__SM01.wav transcribes as the forced-start line (“Whatever. Staff, roll the curtains”). Used02 forSilence,07 forforcedstart instead.
- Several filenames say NIVERSAL instead of UNIVERSAL, have inconsistent trailing underscores, duplicate numbering or unusual nested names. Corrected only the game-copy names.
- SM_SOUND_04 quiet backstage grumble is absent; it is explicitly an optional reserve in the recording script. Wordless SM_SOUND01/02/03/05 remain in the supplied zip, not injected into speech or imported as unused game assets.
- Alternate wording/contractions are audible in automatic transcripts (e.g. “We're waiting” / “We'll take it from here”; slight phrasing differences inSTH). Story/subtitle words were not silently rewritten. Automatic transcription is identification support, not a complete human listening review.
- Unrecorded narrative stage directions and fallback wording not present in the19-entry pack remain text; no synthetic voice was invented.
