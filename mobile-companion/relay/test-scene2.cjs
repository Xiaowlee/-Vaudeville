const {spawn} = require('node:child_process');
const fs = require('node:fs');
const root = require('node:path').resolve(__dirname, '../..');
const WebSocket = require(root+'/mobile-companion/relay/node_modules/ws');
const relay = spawn(process.execPath,['server.mjs'],{cwd:root+'/mobile-companion/relay',env:{...process.env,PORT:'18787',HOST:'127.0.0.1'},windowsHide:true});
let phone, game, started=false;
const timeout = setTimeout(()=>finish(1),20000);
function finish(code) {clearTimeout(timeout); phone?.close(); game?.kill(); relay.kill(); process.exitCode=code;}
relay.stderr.on('data',d=>process.stderr.write(d));
relay.stdout.on('data',d=>{
  if(started || !d.toString().includes('[relay] started')) return;
  started=true;
  phone=new WebSocket('wss://localhost:18787',{ca:fs.readFileSync(root+'/mobile-companion/.certs/cert.pem')});
  phone.on('error',e=>{console.error(e);finish(1)});
  phone.on('open',()=>{
    phone.send(JSON.stringify({kind:'hello',role:'phone'}));
    game=spawn(process.env.GODOT_BIN || 'godot',['--headless','--path',root,'--log-file',process.cwd()+'/scene2-test.log','--script','res://Script/scene2_interaction_test.gd'],{windowsHide:true});
    game.stdout.on('data',d=>process.stdout.write(d));
    game.stderr.on('data',d=>process.stderr.write(d));
    game.on('exit',code=>finish(code ?? 1));
  });
  phone.on('message',data=>{
    const m=JSON.parse(data);
    if(m.kind==='face_request') {
      phone.send(JSON.stringify({kind:'face_cue',requestId:'stale',cue:'smile',met:true}));
      setTimeout(()=>phone.send(JSON.stringify({kind:'face_cue',requestId:m.requestId,cue:'smile',met:true})),250);
    }
    if(m.kind==='face_ack') console.log('PASS: phone receives Godot acknowledgement');
  });
});
