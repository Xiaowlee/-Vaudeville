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
If the relay service restarts, return to a freshly opened game and scan its new QR.

### Public hosting: website on Vercel, relay on Render

Two free services, two addresses:
- Vercel hosts the website: the browser game (/play), the phone page (/stage) and the exported Godot files. Vercel cannot keep phone connections open, so it does no pairing.
- Render hosts the small relay (mobile-companion/relay/public-relay.mjs). It creates each private session and its QR, and passes prompts/IFB between that game and its phone.
The QR opens the Vercel /stage page; the relay address travels inside the link, so the phone then connects to the relay.

1. Push the reviewed files to GitHub (see "What to commit" below). Nothing has been pushed or published automatically.
2. Vercel (https://vercel.com, sign in with GitHub, Hobby/free): Add New > Project > import the repository. Set Root Directory to mobile-companion. Leave Framework (Next.js), Build Command and Install Command on their defaults. Deploy once to learn the address, e.g. https://YOUR-SITE.vercel.app.
3. Render (https://render.com, free): New > Blueprint > select the same repository. The root render.yaml creates one free relay service. When asked, set WEBSITE_ORIGIN to your Vercel address (https://YOUR-SITE.vercel.app, no slash or path). Check it says Free. Render gives an address such as https://YOUR-RELAY.onrender.com.
4. Back in Vercel: Settings > Environment Variables > add NEXT_PUBLIC_RELAY_ORIGIN = https://YOUR-RELAY.onrender.com (Production). Then Deployments > Redeploy, because this value is built into the page.
5. Players open https://YOUR-SITE.vercel.app/play.
6. Downloadable Windows build: open Story/phone_connection.tres > Relay Server and enter https://YOUR-RELAY.onrender.com (the relay, not the Vercel site). Export Windows again.
7. Test: computer on Wi-Fi, phone on mobile data (Wi-Fi off). Open /play, press Connect phone, scan the QR, then Play. Check prompts and IFB appear and clear; test a second game in another browser to confirm it gets its own QR.

Environment values:
- Render: WEBSITE_ORIGIN (required, your Vercel address) and NODE_ENV=production (already in render.yaml). Optional EXTRA_ALLOWED_ORIGINS: comma-separated extra website addresses, e.g. a custom domain. RENDER_EXTERNAL_URL is supplied by Render automatically; RELAY_PUBLIC_ORIGIN overrides it if you give the relay a custom domain.
- Vercel: NEXT_PUBLIC_RELAY_ORIGIN only. No secrets are needed anywhere.

Free relay limits (Render free web service): it sleeps after about 15 minutes without traffic and takes up to about a minute to wake, so the first Connect phone after a quiet period may be slow (the game waits up to 90 seconds). While a game or phone is connected, both send a tiny keep-alive message every 60 seconds (PhoneCueBridge / MobileDisplay > Keepalive Seconds) so it stays awake during play. Sleeping, restarting or redeploying clears all sessions: reopen the game for a new QR. Keep it as one instance; sessions live in its memory. 750 free hours per month covers one always-on service.
Vercel limits: each playthrough downloads about 52 MB (computer) and 38 MB (phone); the Hobby plan's monthly transfer is ample for playtests. Deploy through GitHub rather than the Vercel CLI, which limits static uploads to 100 MB.
Security: the relay only accepts pairing and connections from your website addresses (plus desktop builds, which carry the private session token). HTTPS/WSS certificates are supplied by Vercel and Render and are verified normally; no home IP, router setup or certificate acceptance is involved.

### Updating the exported files

In Godot's Export window, export Game (Web) and Mobile Display (Web).
The output belongs in mobile-companion/public/game and mobile-companion/public/mobile-display respectively.
Commit and push those files with the code; Vercel redeploys automatically after each push. The relay only needs redeploying when files in mobile-companion/relay change.
What to commit: Scene, Script, Story, UI, addons, assets, project files, mobile-companion (including public/game and public/mobile-display), render.yaml and the guides. Never commit .env.local, .certs, node_modules, .next, .next-hosted, .godot, .task-backups, .task-checks or Builds. The .gitignore files already exclude these; still read the list of changed files before committing.
The old local commands (npm run dev and npm run relay) still work unchanged on the same Wi-Fi.
Local test of the two-address setup: in mobile-companion/relay run PORT=3100, WEBSITE_ORIGIN=http://localhost:3000 and RELAY_PUBLIC_ORIGIN=http://localhost:3100 with npm run public; in mobile-companion build with NEXT_PUBLIC_RELAY_ORIGIN=http://localhost:3100 (npm run build, then npx next start). Then RELAY_BASE=http://localhost:3100 WEBSITE=http://localhost:3000 node relay/test-public.mjs.
The older single-address option (npm run build:hosted, then npm run host with PUBLIC_ORIGIN) remains for local testing; it is no longer the recommended public setup.
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
Vercel + separate relay (local check only): website and relay on different addresses passed pairing, phone links on the website address, relay addresses, cross-origin and rejected-origin checks, keep-alive, and all isolation/reconnect checks above; actual Godot pairing + Mobile scene passed against the relay-only server. Public Vercel/Render deployment has not been performed.
Production npm audit: no reported vulnerabilities at this check. Legacy local-certificate development dependencies still report two high advisories; they are omitted from the hosted runtime.


## Optional speech comparison — 5 October 2026

Your normal game still uses Windows System.Speech. The new experiment lives separately in `Scene/Debug/speech_comparison.tscn`; open that scene and press F6.

1. For browser testing, deploy the updated **mobile-companion website to Vercel AND relay to its existing host** first. This change has not been deployed automatically. Restart the test scene after deployment so it gets a fresh pairing link.
2. Click **Connect / open DEBUG browser**. Use that private session link on the computer with your microphone. If your default browser is not Brave, copy the opened address to Brave. Keep only one test browser tab connected.
3. Choose a sentence and A, B or C. A is your current Windows recognizer (en-US). B is browser recognition without keyword hints. C requests keyword hints where supported. Select en-US for a fair A/B comparison; en-AU is also available for separate browser tests.
4. Click **Start attempt** in Godot. For B/C, also click **Start microphone** on the browser page. Read the sentence, wait for final words, then click **Finish attempt** in Godot. Repeat twice per sentence/condition. Finish before starting a different condition.
5. Results save to `user://speech-comparison.json`; the DEBUG status displays its full Windows location. Browser **Export JSON** saves its received results separately.

The page works by checking the browser's speech API, rather than restricting the browser name. This does not guarantee Brave provides a working recognition service. Unsupported APIs, permission failures and service errors are shown; no alternate provider is silently selected. Capture only begins after you click Start microphone. Audio may be processed by the browser's provider; only recognized text travels through the game relay. No audio recording is saved by this tool.

Edit the eight test sentences/keywords in `mobile-companion/public/speech-tests.json`. These are test copies, not story edits. Scoring uses final top-choice words only, whole keywords/phrases, and counts empty attempts as zero. Errors are recorded separately. Alternatives are retained but do not inflate keyword recall. Unsupported phrase hints are marked as not applied. Confidence values come from different providers and are not directly comparable. Timing includes setup and speaking, not just recognition processing.

The ordinary game UI and story matching are unchanged. The developer-only SpeechMonitor Recognition Backend property also exposes the experimental relay backend; native gameplay requires an enabled, paired PhoneCueBridge and browser tab. Keep Automatic for ordinary playtesting until the experiment has been evaluated. Only one backend is started at a time.


## Android microphone (October 5)

The APK now selects Android's installed speech service automatically. Windows keeps its existing recognizer; browser exports keep their browser recognizer. No story responses or matching rules were changed.

On Android, open **Microphone** in the main menu:
1. Tap **Enable microphone** and allow access.
2. Choose English (Australia) or English (United States).
3. Tap **Test microphone**, speak one short sentence and wait for the final words.
4. Close the panel and start the game. Tap the existing speaking control when it is your turn.

If permission was denied, **Open app permissions** opens this app's Android settings. If no speech service is installed/enabled, the panel reports it; this is different from a broken microphone. Android manages the input microphone (including headset routing); this panel does not pretend to offer an independently selectable input device. The installed provider may process speech online. No audio recording is saved by our adapter. Leaving the app, closing the test or ending the turn cancels capture; late results are discarded.

Export requirements: keep **Use Gradle Build** and **Record Audio** enabled in the Android preset, and the **Android Speech** editor plugin enabled. The new native library must be included in a newly exported APK. Old APKs cannot gain this feature by changing settings. If exporting from another checkout, install Godot's Android build template using Project > Install Android Build Template. The local android/ template folder is ignored by Git. Gradle may need to download build dependencies on the first export.

Files: `addons/android_speech/` contains the native adapter, compiled AAR and export plugin. `Scene/UI/android_microphone_settings.tscn` holds the editable settings layout; `Script/android_microphone_settings.gd` handles its buttons. `Script/speech_transcriber.gd` connects Android events to the existing game signals. Language is stored in `user://android_microphone.cfg`. The AAR can be rebuilt using the included build_plugin.py with the existing JDK, Android platform jar and matching Godot android_source.zip.

Android microphone test APK: `Builds/android-microphone-test.apk`. Native plugin registration, permission declarations, bytecode inclusion and signing verified. Install it on the phone, then use main menu > Microphone > Enable microphone > Test microphone. Actual on-device recognition still requires playtesting. The required SDK platform 36/build-tools 36.1 and Gradle 8.11.1 are now available on this machine.


## Desktop game with a browser microphone (7 October)

Open `Scene/Debug/web_speech_game.tscn` and press F6. This is a separate test launcher; F5 still uses the normal game.

1. Click **Connect session**.
2. Click **Open browser microphone**. Allow microphone access when your browser asks.
3. Click **Play existing story** in Godot.
4. On each player turn, click the game's existing **Speak** control, then **Start microphone** on the browser page. Keep that page open on the computer whose microphone you want to use.
5. Speak the requested response. The DEBUG panel shows recognized words; the existing story decides what happens next. Repeat step 4 for each turn.

The browser hears you, sends the words through the existing relay, and Godot receives them. The normal Windows recognition option remains available through the ordinary game. This test does not fix or replace Android recognition. Brave may lack a working recognition service even when it has microphone permission; use a supported browser if it reports service unavailable.

**Deployment still required:** on 7 October the public website's `/speech-test` page returned 404. Deploy the existing local `mobile-companion` website changes to Vercel and its relay changes to the relay host before testing this public connection. The relay must return a `speech_url` when pairing. No deployment was performed in this pass.

Editable test settings: select the root of `web_speech_game.tscn` to choose language or the existing game scene. No story text or accepted responses were changed. Checks cover scene loading and backend selection, not real microphone accuracy.
