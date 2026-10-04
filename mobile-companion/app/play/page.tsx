"use client";
export default function Game() {
 return <main style={{position:"fixed",inset:0,background:"#000",display:"flex",alignItems:"center",justifyContent:"center"}}>
  <iframe src="/game/index.html" title="Vaudeville" allow="microphone; autoplay; fullscreen" style={{width:"min(100vw, 144vh)",height:"min(100vh, 69.444vw)",border:0,display:"block"}} />
 </main>;
}
