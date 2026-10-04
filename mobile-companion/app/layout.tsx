import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "Vaudeville",
  description: "Vaudeville game and phone companion.",
  appleWebApp: {
    capable: true,
    title: "Vaudeville",
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
