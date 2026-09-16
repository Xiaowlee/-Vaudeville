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

## Future Vercel deployment

The Next.js page can later be imported into Vercel as this `mobile-companion` folder. Vercel would supply public HTTPS for the phone site.

1. Create a Vercel project from this folder (or a repo that contains it).
2. Set the Root Directory to `mobile-companion` if the repo is the whole Folio 2 project.
3. Add `NEXT_PUBLIC_RELAY_URL` in Vercel environment variables, pointing at wherever the relay later runs.
4. Deploy. The phone would then open the Vercel HTTPS URL.

Do **not** deploy the `relay/` folder to Vercel. Vercel serverless hosting cannot keep a WebSocket relay open. The relay stays a small local (or later always-on) Node process. Permanent hosting and a paid relay are out of scope.

## Stack

- Next.js App Router
- Tailwind CSS
- Client-only camera, MediaPipe, and WebSocket code (`"use client"`)
- Local `relay/` WebSocket server

## Scene 2 playtest

1. Restart the web app with `npm run dev` in mobile-companion, and restart the relay with `npm start` in mobile-companion/relay so both load the updated code.
2. On the same Wi-Fi, visit https://192.168.0.61:8787 to accept the existing local certificate if needed, then open https://192.168.0.61:3000. Desktop preview stays https://localhost:3000. The existing .env.local is unchanged.
3. Enable the phone camera, hold one face and tap Continue. It waits until Scene 2 requests a smile. Scenes 0 and 1 do not request facial input.
4. In Godot, run Scene/scene_2_key.tscn directly (F6), or play through Scenes 0 and 1.
5. Smile and hold on the phone. Its existing hold feedback ends in OK. The laptop inserts the key word, waits 0.6 seconds, then shows Read out loud.
6. Say “She picks the key and opens the door.” The existing recognizer accepts the narration and the supplied door animation plays once, holding open. No Scene 3 destination is assigned yet.

Godot uses wss://127.0.0.1:8787 with the existing .certs/cert.pem as its trusted certificate. This avoids localhost resolving to IPv6 while the relay listens on IPv4. PhoneInputHook exposes the URL and certificate in the Inspector. Certificate verification remains enabled.

If the relay disconnects before success, the browser and Godot retry. Each new Scene 2 instance requests a fresh smile; a prior scene's success cannot unlock it. Ctrl+Enter is the existing development-only voice fallback, available after face success. It does not verify real speech.

Automated validation passed for Scenes 0, 1 and 2. Scene 2 used a synthetic phone over real secure WebSockets and synthetic transcripts. Actual phone camera and human voice remain to be playtested.
