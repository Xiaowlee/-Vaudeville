"use client";
// NEXT_PUBLIC_RELAY_ORIGIN (set on Vercel) tells the browser game where to create its phone session.
const relayOrigin = process.env.NEXT_PUBLIC_RELAY_ORIGIN || "";
export default function Game() {
 const src = relayOrigin ? `/game/index.html#relay_origin=${encodeURIComponent(relayOrigin)}` : "/game/index.html";
 return <main style={{position:"fixed",inset:0,background:"#000",display:"flex",alignItems:"center",justifyContent:"center"}}>
  <iframe src={src} title="Vaudeville" allow="microphone; autoplay; fullscreen" style={{width:"min(100vw, 144vh)",height:"min(100vh, 69.444vw)",border:0,display:"block"}} />
 </main>;
}
