# Mobile companion

Phone-browser prototype for the native Godot desktop game. It uses the front camera and MediaPipe Face Landmarker in the browser. It does not identify a person, and it does not classify complex emotions such as sadness or anger. The first cue is a physical **smile** from MediaPipe blendshapes (`mouthSmileLeft` / `mouthSmileRight`).

This folder is a Next.js App Router + Tailwind CSS site. Face tracking stays on the phone. A separate lightweight WebSocket relay lives in `relay/`. Nothing here is permanently hosted yet, and it does not use a paid service.

Godot gameplay is not wired yet. Desktop still only has `phone_connected`, `face_present`, and `face_cue_met` hooks.

## Install

Requires Node.js 20+.

```bash
cd mobile-companion
npm install
cd relay
npm install
```

Copy the env example and keep the relay URL local:

```bash
cd mobile-companion
copy .env.example .env.local
```

Default `.env.local`:

```
NEXT_PUBLIC_RELAY_URL=wss://10.132.36.229:8787
```

Use the computer's current Wi-Fi IPv4 address, not `localhost`. On a phone, `localhost` is the phone itself. Change the IP in `.env.local` if your computer address changes.

## Run locally

Use two terminals. Keep the computer awake.

**1. Relay**

```bash
cd mobile-companion/relay
npm start
```

**2. Phone page**

```bash
cd mobile-companion
npm run dev
```

Next.js prints a local HTTPS URL and a network URL. HTTPS is required so a phone can grant camera permission. The relay binds to `0.0.0.0:8787` and reuses the existing Next.js files in `mobile-companion/.certs/`. It does not create or install another certificate.

- On the computer: open `https://localhost:3000`.
- On a phone on the same Wi-Fi: open `https://<computer-ip>:3000`.
- The first visit will warn about a self-signed certificate. Continue/accept it for local testing only.
- Also open `https://<computer-ip>:8787` once in the phone browser so that port is allowed. This is the same certificate as the Next.js page, not a new CA.

There is no permanent hosting. This is a local prototype only.

## Camera permissions

The page asks for the **front / user-facing** camera only (`facingMode: "user"`). There is no microphone.

1. Tap **Enable camera**.
2. Allow camera access when the browser prompts.
3. The live preview is shown only during setup, until exactly one face is held and you tap **Continue**.
4. After that the preview is hidden. The camera stream stays running in the background so smile detection can continue on this device.

If permission is denied, reload the page and allow the camera. Browsers block camera access on insecure HTTP except on `localhost`, which is why local HTTPS is used.

If the wrong camera opens, close other apps using the camera and retry. On some phones you may need to choose the front camera in the browser prompt.

## Smile threshold and hold duration

Edit `lib/config.ts`:

| Setting | Meaning |
| --- | --- |
| `SMILE_THRESHOLD` | Average of `mouthSmileLeft` and `mouthSmileRight` that counts as a smile (0–1). |
| `SMILE_HOLD_MS` | How long that smile must be held before success. |
| `CALIBRATION_HOLD_MS` | How long exactly one face must stay visible before **Continue** is enabled. |

The on-screen debug block and the browser console print face count and those blendshape values so you can raise or lower the threshold. A successful smile snapshot is kept in the debug output. Detection still requires **one** face; zero or two faces will not complete the smile cue.

## WebSocket messages

`lib/websocket.ts` is the reusable browser client. `lib/messenger.ts` logs JSON and sends it to the relay when the socket is open.

Example smile payload:

```json
{ "kind": "face_cue", "cue": "smile", "met": true, "requestId": "current-game-request" }
```

`face_present` messages are also emitted when the detected face count changes. Godot now receives these signals through `PhoneInputHook` in Scene 2. The relay routes game/phone roles and retains the current request for late phone connections. Success must match its requestId; the phone retries until Godot acknowledges it.

## Public hosting (Vercel website + separate relay)

Step-by-step instructions are in `SYSTEMS_DESIGNER_GUIDE.md` ("Public hosting: website on Vercel, relay on Render"). In short:

- **Vercel**: Root Directory `mobile-companion`, default Next.js build. Environment variable `NEXT_PUBLIC_RELAY_ORIGIN=https://<relay>.onrender.com`. Every route is static; no Vercel Functions are used.
- **Relay** (`relay/public-relay.mjs`, `npm run public`, configured by the root `render.yaml`): `POST /api/pair` creates a private session and its QR; `/relay` carries WebSockets; `/health` for the host. Environment: `WEBSITE_ORIGIN` (required), `NODE_ENV=production`, optional `EXTRA_ALLOWED_ORIGINS`, `RELAY_PUBLIC_ORIGIN` (defaults to Render's `RENDER_EXTERNAL_URL`).

Do **not** deploy the WebSocket relay as a Vercel Function; it needs a persistent process because sessions live in memory.

## Stack

- Next.js App Router
- Tailwind CSS
- Client-only camera, MediaPipe, and WebSocket code (`"use client"`)
- Local `relay/` WebSocket server

## Scene 2 playtest

1. Restart the web app with `npm run dev` in mobile-companion, and restart the relay with `npm start` in mobile-companion/relay so both load the updated code.
2. On the same Wi-Fi, visit https://192.168.0.61:8787 to accept the existing local certificate if needed, then open https://192.168.0.61:3000. Desktop preview stays https://localhost:3000. The existing .env.local is unchanged.
3. Enable the phone camera, hold one face and tap Continue. It waits until Scene 2 requests a smile. Scenes 0 and 1 do not request facial input.
4. In Godot, run Scene/2.0_02_key_door.tscn directly (F6), or play through Scenes 0 and 1.
5. Smile and hold on the phone. Its existing hold feedback ends in OK. The laptop inserts the key word, waits 0.6 seconds, then shows Read out loud.
6. Say “She picks the key and opens the door.” The existing recognizer accepts the narration and the supplied door animation plays once, holding open. No Scene 3 destination is assigned yet.

Godot uses wss://127.0.0.1:8787 with the existing .certs/cert.pem as its trusted certificate. This avoids localhost resolving to IPv6 while the relay listens on IPv4. PhoneInputHook exposes the URL and certificate in the Inspector. Certificate verification remains enabled.

If the relay disconnects before success, the browser and Godot retry. Each new Scene 2 instance requests a fresh smile; a prior scene's success cannot unlock it. Ctrl+Enter is the existing development-only voice fallback, available after face success. It does not verify real speech.

Automated validation passed for Scenes 0, 1 and 2. Scene 2 used a synthetic phone over real secure WebSockets and synthetic transcripts. Actual phone camera and human voice remain to be playtested.

## Stage phone display (Godot web export)

The QR on the main menu opens `https://192.168.0.61:3000/stage`. That page now shows the Godot web export of `Scene/StageActs/Mobile.tscn`, served from `public/mobile-display/`. The older text-only stage page is still available at `/stage/text`. The face companion stays at `/`.

- **CueCard** (existing) shows the player's line prompt when the stage reveals it.
- **IFB** (new panel in the same scene) shows private instructions from each beat's Phone / IFB cue, after that cue's delay.
- The two areas are separate relay channels (`prompt` and `ifb`), so one never erases the other. Both clear when the player responds, when the story moves to the next beat, or when the game disconnects. A phone that reconnects only gets the cues that are still active.
- The desktop stage no longer shows the cue card or a local IFB fallback (`StageUI > Desktop Cue Card` is off, and `IFB > Local Fallback` is off, in the 2.3 stage scene).

### Edit the layout

Open `Scene/StageActs/Mobile.tscn` in Godot. Move, resize, recolour or change fonts on `CueCard` and `IFB` (each contains `Margin/Text`). The root node's Inspector has the relay settings, panel paths, **Hide Empty Panels**, and **Phone Design Size** (the reference resolution on the phone, 540�960 by default). You can test the scene directly with F6 while the relay is running.

### Rebuild after editing Mobile.tscn

In Godot, use **Project > Export > Mobile Display (Web) > Export Project** and keep the path `mobile-companion/public/mobile-display/index.html`. Turn **Export With Debug** off. Or, from the project folder:

```powershell
& "C:\Users\Xiaow\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --export-release "Mobile Display (Web)" mobile-companion/public/mobile-display/index.html
```

This needs the Godot 4.7.1 **Web** export templates. The preset exports only `Mobile.tscn` and its script. A `mobile_display` feature tag makes it the start scene, and `addons/mobile_display_export` leaves the desktop autoloads out of this export only. No speech recognition, story controller or stage scene is included. Thread support is off, so no special cross-origin headers are needed.

### Start for a phone test

1. `npm run dev` in `mobile-companion`.
2. `npm start` in `mobile-companion/relay`.
3. On the phone (same Wi-Fi), open `https://192.168.0.61:8787` once and accept the local certificate. Then scan the QR or open `https://192.168.0.61:3000/stage`.
4. Run the stage game in Godot.

`relay/test-stage-channels.cjs` is a synthetic check of the two channels (run it while the relay is running).
