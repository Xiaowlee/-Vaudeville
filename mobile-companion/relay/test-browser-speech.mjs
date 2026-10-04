import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const source=readFileSync('../Script/browser_speech.gd','utf8');
const start=source.split('const START = """')[1].split('"""')[0];
let rec;
class MockRecognition { constructor(){rec=this;} start(){this.onstart();} abort(){this.onend();} }
const window={SpeechRecognition:MockRecognition};const context=vm.createContext({window});
assert.equal(vm.runInContext(start,context),'');assert.equal(rec.lang,'en-US');
rec.onresult({resultIndex:0,results:[Object.assign([{transcript:'hel'}],{isFinal:false})]});
rec.onresult({resultIndex:0,results:[Object.assign([{transcript:'hello'}],{isFinal:true})]});
assert.deepEqual(Array.from(window.vaudevilleSpeech.events,x=>x.kind),['ready','partial','final']);
const stop=source.match(/JavaScriptBridge.eval\("(if\(window.vaudevilleSpeech\).*?)", true\)/)[1];
vm.runInContext(stop,context);rec.onresult({resultIndex:0,results:[Object.assign([{transcript:'late'}],{isFinal:true})]});
assert.equal(window.vaudevilleSpeech.events.length,0);
assert.match(vm.runInContext(start,vm.createContext({window:{}})),/does not support/);
console.log('PASS: browser transport partial/final events, stop suppresses late results, unsupported-browser message (mock recognition only)');
