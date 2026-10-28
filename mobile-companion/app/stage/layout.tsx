import type { ReactNode } from "react";
import type { Viewport } from "next";
import { stageFrameSettings } from "../../components/stage-frame-settings";

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
  userScalable: true,
  viewportFit: "cover",
  themeColor: stageFrameSettings.background,
};

export default function StageLayout({ children }: { children: ReactNode }) {
  return children;
}
