# Write the performance here

Open **Story/StageActs/acts_1_3.tres** in Godot's FileSystem dock.
Or open the current stage scene and select **GameController → Sequence**.

You now have **8 Blocks**. There is no second editable 44-beat list.

```text
Blocks
├─ PRESHOW
│  ├─ Start Events
│  │  ├─ PLAY_AMBIENCE → audience recording
│  │  └─ WAIT → 2.5 seconds
│  ├─ Dialogue Lines [4]
│  │  └─ Speaker / Text / Voice Audio / Wait After
│  ├─ Player Interaction → YES_NO
│  │  └─ Reminder → enabled, 5 seconds, editable words/recording
│  └─ End Events
│     ├─ STOP_AMBIENCE
│     ├─ PLAY_SFX → curtain recording
│     └─ CURTAIN_OPEN
├─ A1_STORYBOOK_INTRO
├─ A1_FORGOTTEN_LINES
├─ A1_WRITER_CONVERSATION
├─ A1_BIRTHDAY_PREPARATION
├─ A1_TO_A2_TRANSITION
├─ A2_DECLARATION_PREP
└─ A3_INTERRUPTION
```

This map uses the actual field names in your new Inspector; it is not a screenshot.

## The order inside a block

**Start Events → Dialogue Lines → Player Interaction → Following Moments → End Events → next block**

Most simple blocks need only Dialogue Lines. Leave the other lists empty.

**Following Moments** is for sections with several turns, such as the forgotten-line sequence. It keeps the existing order: player attempt, Mother's reaction, another attempt, backstage help, then the guided line. Add a DialogueLineData, PlayerInteractionData or StageEvent there only when needed.

A line can hold several paragraphs. Leave a blank line between passages for the current one-at-a-time display. Use another line entry when the speaker, recording or timing needs to change. You do not need another story block for another sentence.

## The ten editing actions

| You want to… | Do this in the Inspector |
|---|---|
| Add dialogue | Block → **Dialogue Lines → Add Element → New DialogueLineData**. Fill **Speaker** and **Text**. |
| Reorder lines | Drag a line's handle on the left up/down inside Dialogue Lines. |
| Add a voice recording | Drag your file into that line's **Voice Audio**. Empty means no recording. |
| Add audience ambience | **Start Events → Add Element → New StageEvent**. Set **Event Type = PLAY_AMBIENCE**, then drag the recording into **Audio**. |
| Add a short sound | Add a StageEvent; choose **PLAY_SFX** and assign **Audio**. |
| Add a pause | Add a StageEvent; choose **WAIT** and set **Duration** in seconds. Put it after the sound if the sound should begin first. |
| Add player input | Expand **Player Interaction → New PlayerInteractionData**. Choose **Input Mode**, then edit the line/accepted words or Responses. |
| Change the pre-show reminder | **PRESHOW → Player Interaction → Reminder**. Set **Reminder Enabled**, **Reminder Delay**, **Reminder Repeat** and **Reminder Interval**. Open **Reminder** to edit its **Text** and optional **Voice Audio**. |
| Open the curtain | **PRESHOW → End Events** already has **PLAY_SFX** then **CURTAIN_OPEN**. Replace the SFX Audio yourself; Animation names the existing curtain animation. |
| Reorder story blocks | Drag a block's handle in **Blocks**. Keep PRESHOW first. Empty **Flow → Next Block** follows the new list order. |

For a new spoken-line task, choose **GUIDED_LINE**, fill **Expected Line**, and enable **Player Hint And Transcript → Show Cue Card**. For named alternatives, choose **CHOICE_INTENT** and fill **Responses** with each option's Accepted Phrases and Npc Response. **ANY_SPEECH** accepts a spoken attempt, such as an improvised name. Keep the migrated settings on existing interactions when only changing words.

## Voice and background sound are separate

PRESHOW's lines use **Advanced → Voice End Mode = STOP_ON_LINE_END**. Their recording stops when that line advances, including permitted Space advancement. **WAIT_FOR_AUDIO** waits for the recording during automatic playback. An explicit second Space press stops the current voice and skips the passage. Wait After is the reading pause after the text reveal; it is not the length of the recording.

Audience ambience keeps playing independently until the STOP_AMBIENCE event. BGM uses **PLAY_BGM / STOP_BGM**. Leaving later blocks' sound events empty keeps the current background sound running.

The four new pre-show voice slots are empty: assign your Stage Manager recordings there. The previous cough is not used as spoken dialogue. Existing story recordings and curtain SFX remain assigned.

## Leave Advanced closed for everyday writing

It preserves existing timing, typewriter overrides, stage actions and phone cues. You do not need to change those to edit a sentence. Stage descriptions are author notes; writing an action does not create an animation.

Changing a line's title does not change its saved destination. Existing special destinations remain intact. For a new jump, use a block's name in Next Block / an interaction's destination. Avoid duplicating an existing interaction with hidden destinations: create a new entry for a new interaction. For a new line, use Add Element → New DialogueLineData instead of copying an old entry with a saved destination.

## Test one small edit

Stop the game, save your story resource, and run **Scene/StageActs/2.3_stage_acts_1_3.tscn** with F6.

Audience → four Stage Manager lines → wait/reminder → X/Speak → YES → curtain sound/open → Act 1.

**Space:** first reveal the current text, then advance where allowed. **Ctrl+Enter:** existing development bypass. **F3:** existing debug panel.

The gameplay layout remains in **Scene/StageActs/2.3_component_stage_ui.tscn**. This change does not redesign that UI.


## Open the phone companion

In the game menu, click **Connect phone**, then scan the QR. Use the same Wi-Fi as the laptop.

Keep these two terminals running:

```powershell
cd "D:\RMIT\Master\Studio 1\Folio 2\folio-2-test-2\mobile-companion"
npm run dev
```

```powershell
cd "D:\RMIT\Master\Studio 1\Folio 2\folio-2-test-2\mobile-companion\relay"
npm start
```

Desktop preview: https://localhost:3000/stage
Phone: https://192.168.0.61:3000/stage
First use on a phone: open https://192.168.0.61:8787 and accept the local certificate if prompted, then return to the companion page. The website may also need its local certificate accepted. Only do this for your own development computer. A blank dark phone screen is normal until a cue arrives. In the stage, F3 shows the phone connection and last cue.

The QR is a locally generated image, not hosting or a connection guarantee. Both services must run. The current QR is specific to 192.168.0.61; it needs regeneration if this computer's address changes. The phone relay setting in mobile-companion/.env.local must match too.

Edit QR panel placement, size and text in **UI/phone_pairing.tscn**. The texture is **UI/phone_companion_qr.svg**. An Adobe-generated QR for the same URL can replace the texture. Changing the printed URL label alone does not change the QR's destination.


## Playing on a website and connecting a phone (October 4)

The main menu now has Play, Previous prototypes and Connect phone (plus Quit in the desktop build).
All the older versions, including Performer A/C, are inside Previous prototypes.
Edit their appearance in Scene/00_main_menu.tscn and UI/phone_pairing.tscn. The rough logo node is preserved but hidden; an editable Vaudeville title is shown instead. Asset files are unchanged.

Each running game asks the website for its own private session. Connect phone displays a QR made for that session.
The phone receives only that game's cue prompts and IFB. Computer and phone need internet, but can use different networks.
Opening the QR again reconnects to the same session. Restarting the game makes a new session. Sessions expire after 12 hours.
The QR package is free, runs inside your own website service, and does not use an external QR website.
Do not share a session QR publicly: anyone with it can view that session's cues.
If the hosting service restarts, return to a freshly opened game and scan its new QR.

### First public hosting setup

1. Create a Render account at https://render.com and connect the GitHub repository containing these updated files. Nothing has been pushed or published automatically.
2. Choose New > Blueprint and select that repository. The root render.yaml prepares ONE free web service: website, game and relay together.
3. Check it still says Free before creating the service. No domain purchase is required. Render supplies an HTTPS address.
4. Share https://YOUR-SERVICE.onrender.com/play with players. The game automatically uses its own website address for pairing.
5. For a downloadable Windows build, edit Story/phone_connection.tres > Public Origin to https://YOUR-SERVICE.onrender.com (without /play). Then export Windows again.
6. Test the computer on Wi-Fi and the phone on mobile data. Scan Connect phone, then Play. Check both prompts and IFB; also test a second independent game.

The service must remain one instance for this prototype; sessions are held in memory. Restarts/deploys clear them.
Free hosting may sleep when idle, so the first connection can take longer. This is a playtest setup, not a high-traffic release service.
A custom domain is optional. If using one, set the hosting environment value PUBLIC_ORIGIN to that HTTPS address.
The public service uses the host's HTTPS certificate; no home IP, router setup or self-signed certificate acceptance is required.

### Updating the exported files

In Godot's Export window, export Game (Web) and Mobile Display (Web).
The output belongs in mobile-companion/public/game and mobile-companion/public/mobile-display respectively.
Commit those files with the code before redeploying. Do not upload .env.local, .certs, node_modules, .task-backups or .task-checks.
The old local commands (npm run dev and npm run relay) still exist. Public hosting builds with npm run build:hosted and starts with npm run host. The hosted build uses .next-hosted so it does not overwrite the old local website build. Stop any hosted development preview before building it.
For a local browser smoke test: set PORT=3100 and PUBLIC_ORIGIN=http://localhost:3100, then npm run host (without NODE_ENV=production).
A localhost QR is only for automated/local testing; it is not a working phone link on another device.

### Speech recognition

The downloaded Windows game keeps the existing Windows recognizer. The browser game uses browser speech recognition.
Developer setting: SpeechMonitor > Recognition Backend (Automatic / Windows / Browser). Players do not see this selector.
The computer microphone is used; the phone remains a cue/IFB display. This pass does not add an in-game microphone-device dropdown.
Windows uses the default Windows recording input; browser users select microphone permission/input through their browser's site controls.
Click/X to speak and all existing story matching remain in place. Browser confidence values are not treated as equivalent to Windows confidence.
Some browsers do not support recognition; a retry/error message appears instead of pretending speech was heard.
Browser recognition may send audio to its provider and require internet. Test actual voices in the target browser before deciding which version to publish.

### Verification and limits

Two simulated games passed isolation, prompt/IFB separation, acknowledgements, invalid token, phone/game role protection, reconnect and disconnect clearing.
Godot exports and website production build were checked. Real phone scanning, mobile-data access and spoken-recognition accuracy still need human playtesting after hosting.
Production npm audit: no reported vulnerabilities at this check. Legacy local-certificate development dependencies still report two high advisories; they are omitted from the hosted runtime.
