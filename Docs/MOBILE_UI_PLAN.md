# Mobile companion UI — Cursor planning handoff
28 October 2026. Planning only; no phone UI implementation or deployment.

## Confirmed scope
This chat owns mobile UI planning; the other chat owns Godot/desktop. Cursor implements the phone build. Preserve current pairing, QR entry, relay, prompt and private IFB functionality. Read PROJECT_CONTEXT.md before work and append confirmed decisions and completed results afterwards. Do not alter desktop or relay contracts as an incidental UI change.

## Verified entry point and behaviour
- relay/sessions.mjs creates phone URLs at /stage#relay=<encoded room/token WebSocket URL>.
- mobile-companion/app/stage/page.tsx embeds /mobile-display/index.html and forwards both query and fragment. The current phone display is a Godot export, not the old React text page.
- Script/StageActs/mobile_display.gd is the current behavioural reference. It joins as stage_phone, supports ?recipient=, keeps prompt and ifb independently, acknowledges each requestId, and clears only matching cancelled requests. Relay disconnect clears both displayed channels; reconnect receives currently retained cues. Phone sends keepalive every 60 seconds.
- app/stage/text/page.tsx is incomplete for parity: it stores only one cue and uses the environment-based WebSocket helper. Do not copy it wholesale or redirect the QR there.
- lib/websocket.ts does not itself resolve the pairing fragment. A future React display must explicitly resolve the existing fragment correctly, retain its room/token, preserve current local fallback and recipient behaviour, and never log pairing credentials.
- app/page.tsx is the separate face companion; /play and /speech-test serve other workflows. Leave them intact.
- ACK means cue delivery, not that the player performed/read the cue. UI must not send a new gameplay-completion event.

## Figma and assets
Reference: https://www.figma.com/design/HUVJb2ss3V78VhgPTYyfeX/STUDIO?node-id=212-72
Page 3 metadata inspected: 203:4 (402x874), 203:21 (420x932), 203:26 (700x840), 203:31/203:40 (390x912), character-card composition 203:55, curtain composition 212:65. These are composition references, not fixed device canvases. On the 700x840 frame the full-width decorative PNGs extend far beyond the frame vertically; do not reproduce those offsets as responsive rules.
A screenshot URL was returned by Figma, but could not be downloaded in this environment (DNS failure). No fresh full-composition visual verification is claimed. Local character and curtain-trim art was visually inspected.

Originals: D:/RMIT/Master/Studio 1/Folio 2/Game Asset/2.5/
Phone/ contains four 1080x2400 transparent PNGs. Measured alpha bounds, in original pixels, exclusive right/bottom:
- Phone Ui_Layer Comp 1.png: (0,223)-(1080,2192), side rails.
- Phone Ui_Layer Comp 2.png: (54,196)-(1028,643), curtain trim.
- Phone Ui_Layer Comp 3.png: (0,2024)-(1080,2387), bottom ornament.
- Phone Ui_Layer Comp 4.png: (0,0)-(1080,361), top ornament.
Character/mobile.png is the character holding the blank card; Character/mobile 1.png is the curtain-peeking composition. Both are 1752x1752. Figma layer names alone are not reliable asset mappings: verify pixels before assigning.
Keep originals untouched. Any cropped/segmented derivatives must have documented source and crop coordinates. Transparent padding is intentional source data, not visible decorative size.

## Proposed responsive plan — awaiting visual review
Compare two presentations using identical real cue content and states:
1. Plain cue text within the supplied theatre frame.
2. Character holding the card, with selectable live text above the image in a measured inset region. Character and card art scale together with their square aspect ratio preserved. Text stays upright and wraps independently.
Use a solid full-viewport background, dynamic viewport height and notch/home-indicator safe areas. Place ornaments in separate layers, anchored to screen edges; preserve top/bottom artwork proportions. Split/segment side rails if required to span variable height without distorting decorative ends. Cap ornament size on tablets rather than blindly scaling every layer to viewport width. Keep decoration behind text and non-interactive.
Reserve a central reading area based on visible ornament extents, not the padded PNG boxes. Wider screens expand margins and cap reading width; short screens reduce decorative occupation before reducing readable text. Allow vertical scrolling when needed; no clipped text, ellipsis, line clamp, forced full-screen mode or whole-screen letterboxing. Browser zoom must remain available.
Prompt and IFB remain separate readable regions when both are active. Their exact arrangement and labels need visual review; do not silently prioritize one by hiding the other. No invented narrative or waiting dialogue.
For card presentation, use a comfortably readable text floor; if a long cue or simultaneous channels outgrow the painted card, use the plain expandable reading area. This fallback is a recommendation, not approved behaviour. Frame 7 may suit a later entrance/reaction; it must not obscure a required cue. No animation is approved yet.
Keep visual controls together for Cursor: art scale/offset, top/bottom ornament caps, rail width, reading width/insets, card text inset and type size/line height. Avoid scattered magic coordinates.

## Implementation boundary and review checks
A native React /stage would replace the current Godot iframe and is an architecture choice still to confirm. If chosen, preserve the public route and URL contract, keep the Godot export available for rollback, and recreate the full current phone client behaviour before switching. Do not mount old and new clients simultaneously in a comparison preview.
Before visual work, capture a baseline paired session. Check prompt only, IFB only, both together, channel replacement, duplicate delivery, stale cancel after replacement, game disconnect, relay loss/reconnect, recipient targeting, and room expiry/invalid pairing. Never show connected merely because the page loaded; transport-open alone does not prove game presence.
Review the same short and longest actual authored cues at 320x568, 390x844, 402x874, 420x932, 700x840 and landscape; include browser bars, safe areas and enlarged text. Confirm no overlap or distorted art and every cue remains reachable. Include physical iPhone/Android and real paired-device verification before claiming phone readiness.

## Completed in this planning pass
Read shared project history, repository instructions, active route, session URL generation, current Godot phone client, legacy React page and relay protocol. Re-read Figma metadata and measured asset transparency. No source, art, relay, desktop or deployment changes. Final presentation, animation, overflow fallback and replacement renderer remain proposals.
