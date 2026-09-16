# Folio 2 — agent instructions

## Design authority
PROJECT_CONTEXT.md is the authoritative current design source. Read it before every gameplay change, together with the current scene/script files. Do not invent UI, mechanics, narrative, diagnostic screens, or extra features not described there. New explicit user directions take precedence; update the context when requirements change.

## Fixed implementation priorities
- Minimal UI. Preserve the existing Intro: logo, Start Game, QR placeholder (not a fake working QR connection).
- Reuse the gameplay scene and Inspector configuration; do not hard-code a different implementation per story scene.
- Draggable words need hover, press, drag, correct snap and wrong-drop snap-back feedback.
- Sentence states: grey/inactive → outlined ready-to-read → dedicated completed colour. Only show Read out loud while ready.
- Working voice recognition with actual transcripts/debug output and forgiving matching. Never present amplitude detection or manual success as transcription. Keep an explicitly labelled development fallback when real recognition cannot be verified.
- Scene 0 starts dark; accepted narration turns on the light and triggers the configured visual response.
- Standby sprite animation loops. Story/action sprite animations play once, then hold or return to standby according to an Inspector setting. Use AnimatedSprite2D/SpriteFrames; never manually cycle still textures.
- After the visual response, show Next and auto-advance after five seconds. Manual and timed advance share a one-shot guard.
- Mobile face input belongs to a separate HTTPS phone web companion using its front camera and a relay/WebSocket connection. Desktop only exposes phone_connected, face_present and face_cue_met hooks for now.

## Working rules
Use Godot 4 native Control nodes and readable GDScript on Windows. The user is a designer, not primarily a programmer. Preserve existing Scene/, Script/, assets, fonts and plugins. Inspect before editing; repair moved references instead of recreating old folders. Expose replaceable art, sentence configuration, animation and next-scene settings in the Inspector. Explain material architecture changes. Make small reversible changes autonomously; stop only for destructive decisions, installations, accounts or paid services. Run the game and appropriate tests, fix errors, and report limitations honestly. Do not claim real microphone recognition from synthetic text tests.

## Latest interaction correction
- WordCard.tscn is the actual dragged Control, with smooth mouse following and preserved click offset. No detached drag preview. Invalid/wrong drops tween home; correct drops snap and lock.
- Keep card normal/hover/pressed/disabled appearance in scene Theme Overrides. Keep SentenceRoot, PrefixLabel, WordDropZone, SnapPoint, SuffixLabel and ReadOutLoudLabel manually editable. Never generate sentence layout or impose a Container.
- Scene scripts control interaction state, not typography layout. Ready outlines use scene-authored theme settings; expose state colours.
- Diagnose the actual installed recognizer and audio path before changing matching. Use supported phrase grammar, log partial/final output, reject unrelated speech. Do not invent Vosk APIs or claim live recognition from synthetic tests.
- No extra debugging buttons, progress bars, titles or scene labels. Ctrl+Enter is development-only.
