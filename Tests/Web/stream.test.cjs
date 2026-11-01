// Exercise the production input adapter with an in-process WebSocket, without a browser profile.
const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const source = fs.readFileSync('Sources/SofaRemote/RemotePage.swift', 'utf8');
const start = source.indexOf('      const queue = [];'), end = source.indexOf('      function action(', start);
assert.ok(start >= 0 && end > start);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const sockets = [], http = [], sent = [];
let shortenTimeout = false;
class FakeSocket {
  constructor(url, protocol) { this.url = url; this.protocol = protocol; sockets.push(this); }
  send(raw) { const message = JSON.parse(raw); sent.push({message, time: Date.now()}); }
  close() { this.closed = true; }
  open() { this.onopen?.(); }
  message(data) { this.onmessage?.({data:JSON.stringify(data)}); }
  fail() { this.onclose?.(); }
}
const el = { textContent:'', classList:{remove(){}}, setAttribute(){} };
const ctx = vm.createContext({WebSocket:FakeSocket, location:{protocol:'http:',host:'example.test:1234'},
  document:{visibilityState:'visible'}, setTimeout:(fn,ms)=>setTimeout(fn,shortenTimeout && ms===9000 ? 30 : ms), clearTimeout, setInterval, clearInterval,
  AbortController, TextEncoder, Promise, Date, Math, Map, Error, JSON,
  $:()=>el, status:(message)=>{ctx.lastStatus=message}, clearRuntimeError:()=>{}, request:async (_path,body)=>{http.push(body);return {}},
});
vm.runInContext(`let key='secret', locked=false, drag=false, dragHeartbeat=0;\n` + source.slice(start,end),ctx);
const run = code => vm.runInContext(code,ctx);
(async()=>{
  run('connectStream()'); let ws = sockets.at(-1);
  assert.equal(ws.url,'ws://example.test:1234/input'); assert.equal(ws.protocol,'sofa.v1');
  ws.open(); assert.deepEqual(sent.shift().message,{type:'auth',token:'secret'});
  ws.message({type:'ready'});
  for(let i=0;i<8;i++) { run('command({type:"move",dx:1,dy:0})'); await sleep(18); }
  let commands=sent.filter(x=>x.message.id);
  assert.equal(commands.length,4,'four commands may be in flight before any acknowledgement');
  assert.ok(commands[3].time-commands[0].time<100,'motion proceeds at roughly 60 Hz despite delayed acknowledgements');
  const click=run('command({type:"click",button:"left",count:1})');
  for(let i=0;i<4;i++) ws.message({id:commands[i].message.id,ok:true});
  await sleep(100); commands=sent.filter(x=>x.message.id);
  assert.equal(commands.at(-1).message.body.type,'click','click follows all accumulated motion');
  assert.equal(commands.slice(0,-1).reduce((n,x)=>n+x.message.body.dx,0),8,'coalescing preserves travel');
  for(const {message} of commands.slice(4)) ws.message({id:message.id,ok:true});
  assert.equal(await click,true);
  const text=run('command({type:"text",value:"keep me"})');
  const textID=sent.at(-1).message.id; ws.fail();
  assert.equal(await text,false,'ambiguous text fails and remains available to caller');
  assert.equal(http.length,0,'sent commands are never replayed over HTTP');
  assert.equal(ws.closed,true);
  assert.equal(await run('command({type:"click",button:"left",count:1})'),false,'ordinary input is blocked until reconnect');
  assert.equal(await run('command({type:"action",action:"screenOn"},true)'),true,'urgent wake uses HTTP while disconnected');
  assert.equal(http.length,1);
  http.length=0;
  run('closeStream(); streamUnavailable=false; everReady=false');
  run('connectStream()'); ws=sockets.at(-1); ws.open();
  const fallback=run('command({type:"click",button:"left",count:1})');
  ws.fail(); assert.equal(await fallback,true,'failure before authentication falls back to HTTP');
  assert.equal(http.length,1);
  run('closeStream(); streamUnavailable=false; everReady=false');
  run('connectStream()'); ws=sockets.at(-1); ws.open(); ws.message({type:'ready'});
  shortenTimeout=true;
  const timed=run('command({type:"text",value:"still here"})');
  assert.equal(await timed,false,'unacknowledged commands time out');
  assert.equal(http.length,1,'timed-out command is not replayed');
  run('closeStream(); streamUnavailable=false; everReady=false');
  shortenTimeout=false;
  run('connectStream()'); ws=sockets.at(-1); ws.open(); ws.message({type:'ready'});
  const before=sent.length;
  const huge=await run('command({type:"text",value:String.fromCharCode(1).repeat(900)})');
  assert.equal(huge,false,'oversized UTF-8 input fails before transmission');
  assert.equal(sent.length,before,'oversized frame is not sent');
  assert.match(ctx.lastStatus,/smaller parts/);
  assert.equal(http.length,1,'oversized text is not replayed over HTTP');
  assert.equal(ws.closed,undefined,'oversized text leaves the stream usable');
  assert.equal(await run('command({type:"action",action:"screenOn"},true)'),true);
  assert.equal(await run('command({type:"click",button:"left",count:1})'),false,'wake closure does not enable ordinary HTTP input');
  assert.equal(http.length,2);
  run('closeStream(); streamUnavailable=false; everReady=false');
  run('connectStream()'); ws=sockets.at(-1); ws.open(); ws.message({type:'ready'});
  run('closeStream()');
  assert.equal(await run('command({type:"click",button:"left",count:1})'),false,'visibility-style closure blocks ordinary HTTP input');
  assert.equal(http.length,2);
  run('closeStream(); streamUnavailable=false; everReady=false');
  run('connectStream()'); ws=sockets.at(-1); ws.open(); ws.message({type:'ready'});
  sent.length=0;
  for(let i=0;i<4;i++) { run('command({type:"move",dx:1,dy:0})'); await sleep(18); }
  const stale=run('command({type:"click",button:"left",count:1})');
  await sleep(270);
  for(const {message} of sent.slice()) ws.message({id:message.id,ok:true});
  assert.equal(await stale,false,'click expires behind delayed acknowledgements');
  assert.equal(sent.filter(x=>x.message.body?.type==='click').length,0);
  sent.length=0;
  for(let i=0;i<4;i++) { run('command({type:"move",dx:1,dy:0})'); await sleep(18); }
  run('queue.push({run:()=>{globalThis.displayRan=true;return true},done:()=>{},queuedAt:Date.now()})');
  const dragEnd=run('command({type:"drag",phase:"end"})');
  run('command({type:"move",dx:1,dy:1})');
  assert.equal(ctx.displayRan,undefined);
  for(const {message} of sent.slice()) ws.message({id:message.id,ok:true});
  await sleep(30);
  assert.equal(ctx.displayRan,true,'display runs after prior acknowledged input');
  const endFrame=sent.find(x=>x.message.body?.phase==='end');
  assert.ok(endFrame,'body-less display entry safely precedes drag end');
  ws.message({id:endFrame.message.id,ok:true});
  assert.equal(await dragEnd,true);
  // HTTP foreground changes wait for every prior ACK and fence subsequent gestures.
  sent.length=0;
  run('command({type:"move",dx:2,dy:0})');
  const prior=run('command({type:"click",button:"left",count:1})');
  ctx.foreground=[];
  const opened=run('orderedHTTP(()=>new Promise(resolve=>{globalThis.foreground.push("open");globalThis.finishOpen=resolve}))');
  assert.deepEqual(ctx.foreground,[]);
  let frames=sent.filter(x=>x.message.id);
  ws.message({id:frames[0].message.id,ok:true});
  await sleep(5);
  assert.deepEqual(ctx.foreground,[],'open waits for the earlier click acknowledgement');
  ws.message({id:frames[1].message.id,ok:true});
  assert.equal(await prior,true);
  await sleep(5);
  assert.deepEqual(ctx.foreground,['open']);
  const beforeFence=sent.length;
  assert.equal(await run('command({type:"move",dx:9,dy:0})'),false,'motion cannot cross an HTTP fence');
  assert.equal(sent.length,beforeFence);
  ctx.finishOpen(false);
  assert.equal(await opened,false,'HTTP fence propagates failure to preserve the URL');
  await sleep(5);
  sent.length=0;
  run('command({type:"move",dx:1,dy:0})');
  const priorLaunch=run('command({type:"click",button:"left",count:1})');
  const launch=run('orderedHTTP(()=>{globalThis.foreground.push("launch");return true})');
  frames=sent.filter(x=>x.message.id);
  ws.message({id:frames[0].message.id,ok:true});
  await sleep(5);
  assert.deepEqual(ctx.foreground,['open']);
  ws.message({id:frames[1].message.id,ok:true});
  assert.equal(await priorLaunch,true);
  assert.equal(await launch,true);
  assert.deepEqual(ctx.foreground,['open','launch']);
  run('closeStream()');
  console.log('PASS WebSocket authentication, four in-flight motion packets, ordered click, failure and fallback');
})().catch(e=>{console.error(e);run('closeStream()');process.exitCode=1});
