import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "Face companion",
  description: "Phone front-camera smile cue for the desktop story game.",
  appleWebApp: {
    capable: true,
    title: "Face companion",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-dvh bg-[#111] font-sans text-[#eee] antialiased">
        {children}
      </body>
    </html>
  );
}
