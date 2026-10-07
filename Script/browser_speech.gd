extends RefCounted
## Browser transcription only; the existing story matcher decides what words mean.
const START = """
(() => {
 if (!window.isSecureContext) return 'Microphone needs HTTPS (or localhost).';
 const API = window.SpeechRecognition || window.webkitSpeechRecognition;
 if (!API) return 'Speech recognition is unavailable in this browser.';
 const state = {events:[],active:true,timer:null};
 window.vaudevilleSpeech = state;
 const errors = {
  'not-allowed':'Microphone permission denied. Allow this website to use the microphone.',
  'service-not-allowed':'This browser cannot use its speech service. Try another supported browser.',
  'audio-capture':'Microphone unavailable or busy. Close other recording apps and retry.',
  'network':'The browser speech service could not connect. Check the connection and retry.',
  'no-speech':'No speech heard. Tap to speak again.',
  'language-not-supported':'Speech language unavailable. Try English (US).',
  'aborted':'Microphone stopped. Tap to speak again.'
 };
 const fail = (code) => {
  if (!state.active) return;
  state.events.push({kind:'error',text:errors[code] || code,code,source:'web_speech'});
  state.active=false; clearTimeout(state.timer);
  try {state.rec?.abort();} catch (_) {}
 };
 const deadline = ms => {clearTimeout(state.timer);state.timer=setTimeout(()=>fail('Speech service did not respond. Tap to retry.'),ms);};
 try {
  const rec = new API(); state.rec = rec;
  rec.lang = __LANGUAGE__; rec.interimResults = true; rec.continuous = true; rec.maxAlternatives = 3;
  rec.onstart = () => {if(state.active){state.events.push({kind:'ready',source:'web_speech',language:rec.lang});deadline(30000);}};
  rec.onresult = e => {
   if(!state.active) return;
   deadline(30000);
   for(let i=e.resultIndex;i<e.results.length;i++) {
    const result=e.results[i];
    const alternatives=Array.from({length:Math.min(3,result.length)},(_,n)=>({transcript:result[n].transcript,confidence:result[n].confidence}));
    state.events.push({kind:result.isFinal?'final':'partial',text:result[0].transcript,alternatives,source:'web_speech',language:rec.lang});
   }
  };
  rec.onerror = e => fail(e.error);
  rec.onend = () => {if(state.active)fail('Speech session ended. Tap to speak again.');};
  deadline(15000);rec.start();return '';
 } catch(e) {state.active=false;clearTimeout(state.timer);return e.message || String(e);}
})()
"""
static func start(language := "en-US") -> String:
 return str(JavaScriptBridge.eval(START.replace("__LANGUAGE__", JSON.stringify(language)), true))
static func stop() -> void:
 JavaScriptBridge.eval("if(window.vaudevilleSpeech){const s=window.vaudevilleSpeech;s.active=false;clearTimeout(s.timer);try{s.rec?.abort();}catch(_){}s.events=[];}", true)
static func events() -> Array:
 var value = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.vaudevilleSpeech ? window.vaudevilleSpeech.events.splice(0) : [])", true)))
 return value if value is Array else []
