"use client";
import { useEffect, useRef, useState } from "react";
import { createRelayClient, type RelayClient } from "../../../lib/websocket";
type Cue = { requestId: string; text: string; cueType?: string };
export default function StagePhone() {
  const [cue, setCue] = useState<Cue | null>(null);
  const relay = useRef<RelayClient | null>(null);
  useEffect(() => {
    const recipient = new URLSearchParams(window.location.search).get("recipient") || "";
    const client = createRelayClient({
      onStatus: status => {
        if (status === "open") client.send({kind:"hello", role:"stage_phone", recipient});
        if (status === "closed" || status === "error") setCue(null);
      },
      onMessage: raw => {
        try {
          const message = JSON.parse(raw);
          if (message.kind === "stage_cue" && typeof message.requestId === "string" && typeof message.text === "string") setCue(message);
          if (message.kind === "stage_cancel") setCue(current => current?.requestId === message.requestId ? null : current);
        } catch { /* Ignore unrelated messages. */ }
      }
    });
    relay.current = client;
    client.connect();
    return () => { client.disconnect(); relay.current = null; };
  }, []);
  useEffect(() => {
    if (cue) relay.current?.send({kind:"stage_ack", requestId:cue.requestId});
  }, [cue]);
  const title: Record<string, string> = {PRIVATE:"PRIVATE CUE", PROMPTER:"PROMPTER", SCRIPT_UPDATE:"SCRIPT UPDATE", WARNING:"WARNING"};
  return <main style={{minHeight:"100dvh", background:"#0b0b16", color:"#fff", display:"flex", flexDirection:"column", justifyContent:"center", padding:"clamp(24px,6vw,64px)", gap:24}}>
    {cue && <><p style={{fontSize:16, letterSpacing:"0.14em", color:"#ded9f0"}}>{title[cue.cueType ?? "PRIVATE"] ?? "PRIVATE CUE"}</p>
    <p style={{fontSize:"clamp(32px,8vw,80px)", lineHeight:1.2, fontWeight:600, whiteSpace:"pre-wrap", overflowWrap:"anywhere"}}>{cue.text}</p></>}
  </main>;
}
