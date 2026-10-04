extends RefCounted
## Browser-only transport. Gameplay still decides whether a transcript is an accepted response.
const START = """
(() => {
 const API = window.SpeechRecognition || window.webkitSpeechRecognition;
 if (!API) return 'This browser does not support speech recognition.';
 const state = {events:[],active:true};
 window.vaudevilleSpeech = state;
 const rec = new API(); state.rec = rec;
 rec.lang = 'en-US'; rec.interimResults = true; rec.continuous = true;
 rec.onstart = () => { if(state.active) state.events.push({kind:'ready'}); };
 rec.onresult = e => {
  if(!state.active) return;
  let partial = '';
  for(let i=e.resultIndex;i<e.results.length;i++) {
   const text=e.results[i][0].transcript;
   if(e.results[i].isFinal) state.events.push({kind:'final',text});
   else partial += text;
  }
  if(partial) state.events.push({kind:'partial',text:partial});
 };
 rec.onerror = e => { if(state.active) state.events.push({kind:'error',text:e.error}); };
 rec.onend = () => { if(state.active) state.events.push({kind:'ended'}); };
 try { rec.start(); return ''; } catch(e) { state.active=false; return e.message; }
})()
"""
static func start() -> String:
 return str(JavaScriptBridge.eval(START, true))
static func stop() -> void:
 JavaScriptBridge.eval("if(window.vaudevilleSpeech){window.vaudevilleSpeech.active=false;window.vaudevilleSpeech.rec.abort();window.vaudevilleSpeech.events=[];}", true)
static func events() -> Array:
 var value = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.vaudevilleSpeech ? window.vaudevilleSpeech.events.splice(0) : [])", true)))
 return value if value is Array else []
