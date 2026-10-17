# Main-game story
Run the project normally and choose the main gameplay option. It opens Scene/StageActs/stage_graph_game.tscn.

## Where to edit
Open acts_0_3_cleaned.tres in this folder with Dialogue Nodes. This is the active main-game graph, including pre-show and Acts 1–3. Its Find passage or words toolbar searches passages. Restart the editor after enabling the copied Dialogue Nodes plugin if needed.
Do not edit the separate Week 11 trial expecting the main game to update.
Twine remains a separate writing source. No automatic import runs; coordinate an explicit import after story revisions so graph edits are not lost.

## Play
Read/hear the NPC, then press X or the existing Speak button. Speak, then press X again to finish. Whisper transcribes; local Qwen selects an authored route. NPC text and curtains lock speaking. Space skips the displayed passage. Automatic story passages continue when finished. The existing Menu button leaves the game.
Prompts and IFB use the phone companion. For a desktop-only test, select StageUI and enable Desktop Cue Card. Restore it off for phone testing.
Transcripts are hidden by default; GameController > Show Player Transcript enables them for testing. AI route diagnostics are not shown to players.

## Connect an action or sound
Select GameController > Presentation. Add a passage ID as the key and a StageBeat resource as the value. Use its Actor Actions, Audio, NPC Voice, speaker and timing settings. The graph still owns words and destinations; this resource supplies presentation.
The curtain opening section IDs and speed, pre-show audience sound/delay/voice, and response delay are also on GameController.
Preserved defaults include the existing audience and Stage Manager sound assets. Specific line-by-line voice assignments need matching to the revised story. Written STAGE/SOUND notes remain notes until mapped.

## Current limits
Windows local prototype: installed portable Whisper/Qwen files live in .local-speech. Exporting a game does not automatically distribute those engines/models. Web/Android packaging and installer setup are separate work.
Fallback text is in interpretation_meanings.json. It stays voice-only. Missing story branches still need writing; no click-choice workaround is used.
The old stage scene remains because earlier debug tools reference it. Main menu uses the new integrated scene. Trial files and Twine drafts were not modified.
Verification: all 96 graph routes; fallback and refusal checks; 14 real-Qwen cases; Whisper JFK audio fixture; rendered stage screenshot. Live microphone and paired-phone playtests still required.