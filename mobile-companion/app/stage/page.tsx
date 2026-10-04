"use client";
import { useEffect, useState } from "react";

// Hosts the Godot web export of Scene/StageActs/Mobile.tscn from public/mobile-display.
// The older text-only stage page remains at /stage/text.
export default function StageDisplay() {
  const [src, setSrc] = useState<string | null>(null);
  useEffect(() => { setSrc(`/mobile-display/index.html${window.location.search}${window.location.hash}`); }, []);
  return <main style={{position:"fixed", inset:0, background:"#000"}}>
    {src && <iframe src={src} title="Stage display" allow="autoplay; fullscreen" style={{width:"100%", height:"100%", border:0, display:"block"}} />}
  </main>;
}
