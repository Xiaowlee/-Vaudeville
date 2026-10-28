"use client";

import { StagePhoneClient } from "../../components/stage-phone-client";

// Live pairing stays on /stage. Appearance is adjusted in components/stage-frame-settings.ts.
// Layout fixtures, which do not connect, are at /stage/preview.
export default function StageDisplay() {
  return <StagePhoneClient />;
}
