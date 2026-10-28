import { Suspense } from "react";
import { StagePreview } from "../../../components/stage-preview";
import { stageFrameSettings } from "../../../components/stage-frame-settings";

export default function StagePreviewPage() {
  return (
    <Suspense
      fallback={<div style={{ position: "fixed", inset: 0, background: stageFrameSettings.background }} />}
    >
      <StagePreview />
    </Suspense>
  );
}
