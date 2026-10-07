"use client";
import {useEffect,useRef,useState} from 'react';
import {SpeechExperiment,Config,Event} from '../../lib/speech-experiment';
export default function SpeechTest(){
 const [connection,setConnection]=useState('Connecting…'); const [config,setConfig]=useState<Config|null>(null);const [status,setStatus]=useState('Waiting for a Godot test attempt');const [partial,setPartial]=useState('');const [final,setFinal]=useState('');const [details,setDetails]=useState<Event>({});
 const engine=useRef<SpeechExperiment|null>(null);const socket=useRef<WebSocket|null>(null);const events=useRef<Event[]>([]);const attempts=useRef<Event[]>([]);
 useEffect(()=>{
  const relay=new URLSearchParams(location.hash.slice(1)).get('relay');
  if(!relay){setConnection('Open this page using the DEBUG browser button in Godot.');return;}
  let url:URL;try{url=new URL(relay);if(!['wss:','ws:'].includes(url.protocol)||(location.protocol==='https:'&&url.protocol!=='wss:'))throw Error();}catch{setConnection('Invalid relay address');return;}
  const ws=socket.current=new WebSocket(url);const capture=engine.current=new SpeechExperiment(event=>{events.current.push(event);setDetails(event);if(event.type==='speech_result'){if(event.is_final){setFinal(String(event.transcript));setPartial('');}else setPartial(String(event.transcript));}else setStatus(String(event.error||event.status));if(ws.readyState===WebSocket.OPEN)ws.send(JSON.stringify(event));});
  ws.onopen=()=>{setConnection('Relay connected');ws.send(JSON.stringify({kind:'hello',role:'speech_client'}));};
  ws.onmessage=e=>{let m;try{m=JSON.parse(e.data);}catch{return;}if(m.type==='speech_control'){capture.stop();setPartial('');setFinal('');setConfig(m.action==='start'?m:null);setStatus(m.action==='start'?'Ready — click Start microphone':'Attempt stopped');}else if(m.type==='speech_attempt'){attempts.current.push(m.attempt);}else if(m.type==='speech_observation'){events.current.push(m.event);setDetails(m.event);}};
  ws.onerror=()=>setConnection('Relay connection error');ws.onclose=()=>{capture.stop();setConfig(null);setConnection('Disconnected — reopen from Godot');};
  const timer=setInterval(()=>{if(ws.readyState===WebSocket.OPEN)ws.send(JSON.stringify({kind:'ping'}));},30000);
  return()=>{clearInterval(timer);capture.stop();ws.close();};
 },[]);
 function save(){const url=URL.createObjectURL(new Blob([JSON.stringify({attempts:attempts.current,events:events.current},null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='speech-browser-results.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
 return <main style={{maxWidth:850,margin:'auto',padding:24,color:'#eee',background:'#171728',minHeight:'100vh',overflowWrap:'anywhere'}}><h1>DEBUG — Speech comparison</h1><p>{connection}</p><p>Start a speaking turn or test attempt in Godot, then click Start microphone here. Keep this page open on the computer whose microphone you want to use.</p><p>Microphone audio may be processed by your browser’s speech provider. Text passes through your game relay. This tool saves text, not audio.</p><p>Language: {config?.language||'—'} · Phrase bias requested: {config?.bias_enabled?'yes':'no'}</p><button disabled={!config} onClick={()=>{if(config)engine.current?.start(config);}}>Start microphone</button>{' '}<button onClick={()=>{engine.current?.stop();setStatus('Microphone stopped');}}>Stop microphone</button>{' '}<button onClick={save}>Export JSON</button><p role="status">{status}</p><h2>While speaking</h2><p>{partial||'—'}</p><h2>Final words</h2><p>{final||'—'}</p><details open><summary>Alternatives, confidence and errors</summary><pre style={{whiteSpace:'pre-wrap'}}>{JSON.stringify(details,null,2)}</pre></details><p>If recognition is unavailable in this browser, try a supported browser explicitly. No recognition service is switched automatically.</p></main>;
}
