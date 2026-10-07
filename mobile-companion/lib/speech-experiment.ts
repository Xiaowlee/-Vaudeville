export type Config = {session_id:string; language:string; bias_enabled:boolean; phrases:string[]; boost:number};
export type Event = Record<string, unknown>;
// Browser implementations expose prefixed and experimental fields outside TS DOM types.
/* eslint-disable @typescript-eslint/no-explicit-any */
export class SpeechExperiment {
 private rec:any; private armed=false; private generation=0; private retries=0;
 private timer:ReturnType<typeof setTimeout>|undefined; private watchdog:ReturnType<typeof setTimeout>|undefined;
 private config!:Config; private started=0; private bias=false; private disableBias=false;
 constructor(private emit:(event:Event)=>void) {}
 private report(type:string, fields:Event) { this.emit({type,source:'web_speech',session_id:this.config.session_id,timestamp:new Date().toISOString(),language:this.config.language,bias_requested:this.config.bias_enabled,bias_applied:this.bias,...fields}); }
 start(config:Config) { this.stop(); this.config=config; this.armed=true; this.retries=0; this.disableBias=false; this.started=performance.now(); this.launch(this.generation); }
 stop() { this.armed=false; this.generation++; clearTimeout(this.timer); clearTimeout(this.watchdog); if(this.rec){this.rec.onend=this.rec.onerror=this.rec.onresult=this.rec.onstart=null; try{this.rec.abort();}catch{} this.rec=null;} }
 private launch(g:number) {
  if(!this.armed||g!==this.generation)return;
  const w=window as any; const Factory=w.SpeechRecognition||w.webkitSpeechRecognition;
  if(!Factory){this.report('speech_error',{error:'unsupported-browser',recoverable:false});this.stop();return;}
  try {
   const rec=this.rec=new Factory(); rec.lang=this.config.language;rec.continuous=true;rec.interimResults=true;rec.maxAlternatives=3;this.bias=false;
   if(this.config.bias_enabled&&!this.disableBias){
    if(w.SpeechRecognitionPhrase&&'phrases' in rec){try{rec.phrases=this.config.phrases.map(text=>new w.SpeechRecognitionPhrase(text,Math.min(5,Math.max(0,this.config.boost))));this.bias=true;}catch{}}
    if(!this.bias)this.report('speech_status',{status:'Contextual phrase biasing unavailable.'});
   }
   const valid=()=>this.armed&&g===this.generation&&this.rec===rec;
   rec.onstart=()=>{if(valid()){clearTimeout(this.watchdog);this.report('speech_status',{status:'listening'});}};
   rec.onresult=(e:any)=>{if(!valid())return;for(let i=e.resultIndex;i<e.results.length;i++){const r=e.results[i];const alternatives=Array.from({length:Math.min(3,r.length)},(_,n)=>({transcript:String(r[n].transcript),confidence:Number.isFinite(r[n].confidence)?r[n].confidence:null}));this.report('speech_result',{is_final:!!r.isFinal,transcript:alternatives[0]?.transcript||'',alternatives,latency_ms:performance.now()-this.started,latency_definition:'Elapsed since microphone start, including speaking time'});}};
   rec.onerror=(e:any)=>{if(!valid())return;clearTimeout(this.watchdog);const error=String(e.error);const retryBias=error==='phrases-not-supported'&&this.bias;if(retryBias){this.disableBias=true;this.bias=false;this.report('speech_status',{status:'Contextual phrase biasing unavailable.'});}const recoverable=(error==='no-speech'||retryBias)&&this.retries<3;this.report('speech_error',{error,recoverable});if(!recoverable)this.stop();};
   rec.onend=()=>{if(!valid())return;clearTimeout(this.watchdog);if(this.retries++>=3){this.report('speech_error',{error:'restart-limit',recoverable:false});this.stop();return;}this.timer=setTimeout(()=>this.launch(g),600);};
   this.watchdog=setTimeout(()=>{if(valid()){this.report('speech_error',{error:'recognition-start-timeout',recoverable:false});this.stop();}},15000);
   rec.start();
  }catch(error){this.report('speech_error',{error:String(error),recoverable:false});this.stop();}
 }
}
