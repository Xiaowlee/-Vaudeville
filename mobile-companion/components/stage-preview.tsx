"use client";

import { useSearchParams } from "next/navigation";
import { StageFrame } from "./stage-frame";
import { stagePreviewFixture } from "./stage-preview-fixtures";

/** Layout check only. This route never opens a pairing socket. */
export function StagePreview() {
  const params = useSearchParams();
  const fixture = stagePreviewFixture(params.get("fixture"));
  return <StageFrame cues={fixture.cues} relay={fixture.relay} />;
}
