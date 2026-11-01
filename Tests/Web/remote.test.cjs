// Node 22+. Isolated headless browser; the real page talks only to a local mocked API.
const assert = require('node:assert/strict'), fs = require('node:fs'), os = require('node:os');
const path = require('node:path'), http = require('node:http'), { spawn } = require('node:child_process');
const browser = [process.env.BROWSER_BIN, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(p => p && fs.existsSync(p));
if (!browser) { console.log('SKIP Sofa Remote browser test: no Chrome or Brave'); process.exit(0); }
if (!globalThis.WebSocket) throw Error('Node 22 or newer required');
const source = fs.readFileSync('Sources/SofaRemote/RemotePage.swift', 'utf8');
const match = source.match(/static let html = #"""\n([\s\S]*?)\n"""#/); assert.ok(match);
const html = match[1], ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]);
assert.equal(new Set(ids).size, ids.length, 'IDs are unique');
assert.doesNotMatch(html, /getDisplayMedia|ScreenCaptureKit|screen recording/i, 'input-only UI requests no screen capture');
const profile = fs.mkdtempSync(path.join(process.env.SOFA_TEST_TMP || os.tmpdir(), 'sofa-web-'));
fs.chmodSync(profile, 0o700);
const server = http.createServer((_req,res) => { res.writeHead(200, {'Content-Type':'text/html'}); res.end(html); });
const wait = ms => new Promise(r => setTimeout(r, ms));
let child, ws, closeBrowser;
async function main() {
  await new Promise(r => server.listen(0,'127.0.0.1',r));
  child = spawn(browser, ['--headless=new','--disable-gpu','--no-first-run','--disable-background-networking',
    '--remote-debugging-address=127.0.0.1','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'], {stdio:['ignore','ignore','pipe']});
  const port = await new Promise((resolve,reject) => {
    let output=''; const timer=setTimeout(()=>reject(Error('Browser start timed out')),15000);
    child.on('error',e=>{clearTimeout(timer);reject(e)}); child.on('exit',c=>{clearTimeout(timer);reject(Error(`Browser exited ${c}`))});
    child.stderr.on('data',part=>{output+=part;const m=output.match(/DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)\//);if(m){clearTimeout(timer);resolve(m[1])}});
  });
  const tab=await (await fetch(`http://127.0.0.1:${port}/json/new?about:blank`,{method:'PUT'})).json();
  ws=new WebSocket(tab.webSocketDebuggerUrl);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j});
  let id=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id&&pending.has(m.id)){pending.get(m.id)(m);pending.delete(m.id)}};
  const cdp=(method,params={})=>new Promise((resolve,reject)=>{const n=++id,t=setTimeout(()=>{pending.delete(n);reject(Error(`${method} timeout`))},5000);pending.set(n,m=>{clearTimeout(t);m.error?reject(Error(m.error.message)):resolve(m.result)});ws.send(JSON.stringify({id:n,method,params}))});
  closeBrowser=()=>cdp('Browser.close');
  const evaluate=async expression=>{const r=await cdp('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value};
  await cdp('Page.enable');await cdp('Runtime.enable');
  await cdp('Page.addScriptToEvaluateOnNewDocument',{source:`
    localStorage.setItem('sofaKey','a'.repeat(64)); Element.prototype.setPointerCapture=function(){};
    window.confirm=()=>true;window.calls=[];window.mockActive=0;window.maxActive=0;window.hang=false;window.commandFailure='';window.stateFailure=false;window.commandLatency=3;window.illegalMotion=[];
    window.testState={name:'Mock Mac',frontApp:'Brave Browser',appVersion:'0.1.0',appBuild:'7',macOSVersion:'15.0.1',accessibility:true,sharing:true,sessionLocked:false,screenSleeping:false,displays:[{id:'d1',name:'Display'}],displayID:'d1',shortcuts:[],keepAwake:false};
    const realTimeout=window.setTimeout;window.setTimeout=(fn,ms,...args)=>realTimeout(fn,ms===9000&&window.hang?30:ms,...args);
    const motionBody=b=>b&&(b.type==='move'||b.type==='scroll'||(b.type==='drag'&&b.phase==='move'));
    const badDelta=(v,limit)=>!Number.isFinite(v)||Math.abs(v)>limit;
    window.fetch=async(path,options={})=>{const body=options.body?JSON.parse(options.body):null;calls.push({path,body,key:options.headers?.['X-Sofa-Key']});
      if(path==='/command'&&motionBody(body)&&(badDelta(body.dx||0,body.type==='scroll'?300:1000)||badDelta(body.dy||0,body.type==='scroll'?300:1000))){window.illegalMotion.push({dx:body.dx,dy:body.dy});return {status:400,ok:false,json:async()=>({error:'Motion delta exceeds command limit'})}}
      if(path==='/command'){window.mockActive++;window.maxActive=Math.max(window.maxActive,window.mockActive);try{await new Promise((resolve,reject)=>{if(!hang)realTimeout(resolve,window.commandLatency);options.signal.addEventListener('abort',()=>reject(Error('aborted')),{once:true})})}finally{window.mockActive--}}
      if(path==='/command'&&commandFailure)return {status:commandFailure==='unauthorized'?401:500,ok:false,json:async()=>({error:'Send failed'})};
      if(path==='/state'&&stateFailure)throw Error('Connection unavailable');
      return {status:200,ok:true,json:async()=>path==='/state'?testState:path==='/devices'?[]:{ok:true,token:'b'.repeat(64)}}};
  `});
  await cdp('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});await wait(300);
  const subtitle=await evaluate(`(async()=>{
    await refresh();const withApp=document.querySelector('#connection').textContent;
    testState.frontApp='';await refresh();const withoutApp=document.querySelector('#connection').textContent;
    testState.frontApp='Brave Browser';await refresh();return {withApp,withoutApp};
  })()`);
  assert.equal(subtitle.withApp,'Connected · Mock Mac · Brave Browser');
  assert.equal(subtitle.withoutApp,'Connected · Mock Mac');
  for(const [width,height] of [[320,568],[375,667],[390,844],[430,932],[568,320],[844,390]]){
    await cdp('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:true});
    const geometry=await evaluate(`(()=>{const r=s=>{const x=document.querySelector(s).getBoundingClientRect();return {w:x.width,h:x.height,b:x.bottom}};return {pad:r('#pad'),keys:[...document.querySelectorAll('main button')].filter(x=>x.getClientRects().length).map(x=>{const q=x.getBoundingClientRect();return [q.width,q.height]}),scroll:document.documentElement.scrollWidth,viewport:innerWidth,height:innerHeight,page:document.documentElement.scrollHeight}})()`);
    assert.ok(geometry.pad.h>=150,`${width}x${height} usable touchpad`);
    assert.ok(geometry.keys.every(([w,h])=>w>=44&&h>=44),`${width}x${height} 44px controls`);
    assert.ok(geometry.scroll<=geometry.viewport+1,`${width}x${height} no horizontal overflow`);
    if(width===390&&height===844&&process.env.SOFA_TEST_SCREENSHOT){const shot=await cdp('Page.captureScreenshot',{format:'png'});fs.writeFileSync(process.env.SOFA_TEST_SCREENSHOT,Buffer.from(shot.data,'base64'))}
    console.log(`PASS responsive ${width}x${height}`);
  }
  const help=await evaluate(`(async()=>{
    const q=s=>document.querySelector(s);
    Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async value=>{window.copiedDiagnostic=value}}});
    const oldUA=navigator.userAgent;
    Object.defineProperty(navigator,'userAgent',{configurable:true,value:'PrivatePhone MySecretName Chrome/123.0.1.2 secret-ua-suffix'});
    testState.name='SECRET_MAC_NAME';testState.frontApp='SECRET_FRONT_APP';testState.displayID='SECRET_DISPLAY_ID';
    testState.shortcuts=[{id:'private-id',name:'SECRET_SHORTCUT',kind:'website',url:'https://private.example'}];
    q('#text').value='SECRET_TYPED_TEXT';q('#url').value='https://private.example/SECRET_URL';
    await refresh();q('#settings-open').click();
    q('#settings-sheet [data-help]').click();
    const initial={open:q('#help-sheet').classList.contains('open'),mainInert:q('main').inert,settingsInert:q('#settings-sheet').inert,summary:q('#diagnostics').value,version:q('#app-version').textContent,focus:q('#help-sheet').contains(document.activeElement)};
    q('#copy-diagnostics').focus();document.dispatchEvent(new KeyboardEvent('keydown',{key:'Tab',bubbles:true,cancelable:true}));
    const wrapped=document.activeElement===q('#help-sheet [data-close]');
    const before=calls.length;await q('#copy-diagnostics').onclick();
    const copied=window.copiedDiagnostic,networkAfterCopy=calls.length-before;
    Object.defineProperty(navigator,'clipboard',{configurable:true,value:undefined});await q('#copy-diagnostics').onclick();
    const fallback={selection:q('#diagnostics').selectionEnd-q('#diagnostics').selectionStart,result:q('#copy-result').textContent};
    testState.appVersion='TOKEN-IN-VERSION';await refresh();const sanitized=q('#diagnostics').value;
    document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));
    const restored={settings:q('#settings-sheet').classList.contains('open'),focus:document.activeElement===q('#settings-sheet [data-help]')};
    q('#settings-sheet [data-close]').click();
    const restoredMain={inert:q('main').inert,focus:document.activeElement===q('#settings-open')};
    Object.defineProperty(navigator,'userAgent',{configurable:true,value:oldUA});
    testState.appVersion='0.1.0';testState.name='Mock Mac';testState.frontApp='Brave Browser';testState.displayID='d1';testState.shortcuts=[];
    q('#text').value='';q('#url').value='';await refresh();
    return {initial,wrapped,copied,networkAfterCopy,fallback,sanitized,restored,restoredMain};
  })()`);
  assert.equal(help.initial.open,true);assert.equal(help.initial.mainInert,true);assert.equal(help.initial.settingsInert,true);assert.equal(help.initial.focus,true);
  assert.match(help.initial.summary,/App version: 0\.1\.0/);assert.match(help.initial.summary,/Build: 7/);assert.match(help.initial.summary,/macOS: 15\.0\.1/);assert.match(help.initial.summary,/Browser: Chrome 123\.0\.1\.2/);assert.match(help.initial.summary,/Accessibility allowed: Yes/);
  assert.doesNotMatch(help.initial.summary,/SECRET|private\.example|PrivatePhone|secret-ua|a{64}|private-id/,'diagnostics exclude personal fields, full UA and tokens');
  assert.equal(help.copied,help.initial.summary);assert.equal(help.networkAfterCopy,0,'diagnostic copy never uploads');
  assert.equal(help.wrapped,true);assert.equal(help.fallback.selection,help.initial.summary.length);assert.match(help.fallback.result,/Automatic copy is unavailable/);
  assert.match(help.sanitized,/App version: Unavailable/);assert.doesNotMatch(help.sanitized,/TOKEN-IN-VERSION/,'untrusted version fields cannot inject data into diagnostics');
  assert.deepEqual(help.restored,{settings:true,focus:true});assert.deepEqual(help.restoredMain,{inert:false,focus:true});
  for(const [width,height] of [[320,568],[390,844],[844,390]]){
    await cdp('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:true});
    const layout=await evaluate(`(()=>{document.querySelector('#settings-open').click();document.querySelector('#settings-sheet [data-help]').click();const modal=document.querySelector('#help-sheet .sheet'),r=modal.getBoundingClientRect();const result={width:r.width,height:r.height,viewport:innerWidth,screen:innerHeight,scroll:document.documentElement.scrollWidth,targets:[...modal.querySelectorAll('button,a')].map(x=>x.getBoundingClientRect().height)};closeSheet();closeSheet();return result})()`);
    assert.ok(layout.scroll<=layout.viewport+1,`help ${width}x${height} no overflow`);assert.ok(layout.height<=layout.screen,`help ${width}x${height} scrolls within screen`);assert.ok(layout.targets.every(h=>h>=44),`help ${width}x${height} touch targets`);
  }
  const recovery=await evaluate(`(async()=>{stateFailure=true;await refresh();const disconnected={title:document.querySelector('#connection').textContent,help:!document.querySelector('#connection-help').hidden};stateFailure=false;document.querySelector('#reconnect').click();await new Promise(r=>setTimeout(r,10));return {disconnected,recovered:document.querySelector('#connection-help').hidden}})()`);
  assert.match(recovery.disconnected.title,/Disconnected/);assert.equal(recovery.disconnected.help,true);assert.equal(recovery.recovered,true);
  await cdp('Emulation.setDeviceMetricsOverride',{width:320,height:568,deviceScaleFactor:1,mobile:true});
  const largeText=await evaluate(`(()=>{document.documentElement.style.fontSize='200%';document.querySelector('#settings-open').click();document.querySelector('#settings-sheet [data-help]').click();const result={scroll:document.documentElement.scrollWidth,viewport:innerWidth,help:document.querySelector('#help-sheet .sheet').getBoundingClientRect().width};closeSheet();closeSheet();document.documentElement.style.fontSize='';return result})()`);
  assert.ok(largeText.scroll<=largeText.viewport+1,'200% text has no horizontal page overflow');assert.ok(largeText.help<=largeText.viewport+1,'200% help remains within viewport');
  const keyboardPointer=await evaluate(`(async()=>{
    const pad=document.querySelector('#pad'),send=(target,key,extra={})=>target.dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true,cancelable:true,...extra}));
    calls.length=0;let bubbled=0;const track=()=>bubbled++;document.addEventListener('keydown',track);pad.focus();
    send(pad,'ArrowRight');send(pad,'ArrowUp',{shiftKey:true});send(pad,'Enter');send(pad,' ');send(pad,'Enter',{repeat:true});
    const consumed=bubbled===0;document.removeEventListener('keydown',track);
    document.querySelector('#text').dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));
    document.querySelector('#settings-open').click();send(pad,'ArrowRight');closeSheet();pad.focus();
    Object.defineProperty(document,'hidden',{configurable:true,value:true});send(pad,'ArrowRight');Object.defineProperty(document,'hidden',{configurable:true,value:false});
    while(queue.length||active)await new Promise(r=>setTimeout(r,10));return {consumed,commands:calls.filter(x=>x.path==='/command').map(x=>x.body)};
  })()`);
  assert.equal(keyboardPointer.consumed,true,'focused pointer keys do not bubble to other controls');
  assert.deepEqual(keyboardPointer.commands,[{type:'move',dx:10,dy:0},{type:'move',dx:0,dy:-40},{type:'click',button:'left',count:1},{type:'click',button:'left',count:1}],'keyboard pointer acts only on focused, visible, unobscured pad');
  console.log('PASS privacy-preserving diagnostic preview/copy, clipboard fallback, accessible help dialogs and connection recovery');
  const result=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms)), pad=document.querySelector('#pad');
    const gesture=(type,id,x,y)=>pad.dispatchEvent(new PointerEvent(type,{pointerId:id,clientX:x,clientY:y,bubbles:true}));
    calls.length=0;gesture('pointerdown',1,0,0);gesture('pointermove',1,12,4);gesture('pointerup',1,12,4);await sleep(45);
    document.querySelector('#right').click();document.querySelector('#double').click();await sleep(15);
    document.querySelector('#drag').click();gesture('pointerdown',2,0,0);gesture('pointermove',2,10,5);gesture('pointercancel',2,10,5);await sleep(100);
    gesture('pointerdown',3,0,0);gesture('pointerdown',4,0,0);gesture('pointermove',3,0,12);gesture('pointerup',3,0,12);gesture('pointerup',4,0,0);await sleep(60);
    return {commands:calls.filter(x=>x.path==='/command').map(x=>x.body),maxActive};
  })()`);
  assert.deepEqual(result.commands.map(x=>x.type),['move','click','click','drag','drag','scroll']);
  assert.equal(result.commands[1].button,'right');assert.equal(result.commands[2].count,2);
  assert.deepEqual(result.commands.slice(3,5).map(x=>x.phase),['start','end'],'pointercancel drops queued drag-move and still releases the button');
  assert.equal(result.maxActive,1,'commands are serialized');
  const heartbeat=await evaluate(`(async()=>{
    calls.length=0;document.querySelector('#drag').click();await new Promise(r=>setTimeout(r,1100));
    Object.defineProperty(document,'visibilityState',{configurable:true,value:'hidden'});document.dispatchEvent(new Event('visibilitychange'));
    await new Promise(r=>setTimeout(r,20));Object.defineProperty(document,'visibilityState',{configurable:true,value:'visible'});
    return calls.filter(x=>x.path==='/command').map(x=>x.body);
  })()`);
  assert.equal(heartbeat[0].phase,'start');
  assert.ok(heartbeat.some(x=>x.phase==='move'&&x.dx===0&&x.dy===0),'stationary drag sends heartbeat');
  assert.equal(heartbeat.at(-1).phase,'end','hidden page ends held drag');
  const websiteEntry=await evaluate(`(()=>{document.querySelector('#shortcuts-open').click();return {visible:document.querySelector('#open-form').getClientRects().length>0,insideShortcuts:!!document.querySelector('#open-form').closest('#shortcuts-sheet'),onMain:!!document.querySelector('#open-form').closest('main')}})()`);
  assert.deepEqual(websiteEntry,{visible:true,insideShortcuts:true,onMain:false},'website entry is available in Shortcuts without crowding the touchpad');
  const features=await evaluate(`(async()=>{
    calls.length=0;const sleep=ms=>new Promise(r=>setTimeout(r,ms));
    document.querySelector('#url').value='https://example.org';document.querySelector('#open-form').requestSubmit();await sleep(10);
    document.querySelector('#shortcut-name').value='Example';document.querySelector('#shortcut-value').value='https://example.org';document.querySelector('#shortcut-form').requestSubmit();await sleep(20);
    closeSheet();document.querySelector('#display').dispatchEvent(new Event('change',{bubbles:true}));await sleep(20);
    document.querySelector('[data-mod="command"]').click();document.querySelector('#key-character').value='a';document.querySelector('#key-form').requestSubmit();await sleep(10);
    document.querySelector('#lock').click();await sleep(10);
    return calls.filter(x=>x.path!=='/state').map(x=>({path:x.path,body:x.body}));
  })()`);
  assert.ok(features.some(x=>x.path==='/open'&&x.body.url==='https://example.org'));
  assert.ok(features.some(x=>x.path==='/shortcuts/add'&&x.body.name==='Example'&&x.body.url==='https://example.org'));
  assert.ok(features.some(x=>x.path==='/display'&&x.body.id==='d1'));
  assert.ok(features.some(x=>x.path==='/command'&&x.body.type==='key'&&x.body.key==='a'&&x.body.modifiers[0]==='command'));
  assert.ok(features.some(x=>x.path==='/command'&&x.body.action==='lock'));
  const locked=await evaluate(`(async()=>{testState.sessionLocked=true;await refresh();calls.length=0;document.querySelector('#wake').click();await new Promise(r=>setTimeout(r,10));return {open:document.querySelector('#locked').classList.contains('open'),inert:document.querySelector('main').inert,commands:calls.filter(x=>x.path==='/command').map(x=>x.body)}})()`);
  assert.equal(locked.open,true);assert.equal(locked.inert,true);assert.deepEqual(locked.commands,[{type:'action',action:'screenOn'}]);
  const pausedHelp=await evaluate(`(()=>{document.querySelector('#locked [data-help]').click();const result={help:document.querySelector('#help-sheet').classList.contains('open'),lockedInert:document.querySelector('#locked').inert,helpInert:document.querySelector('#help-sheet').inert};closeSheet();return result})()`);
  assert.deepEqual(pausedHelp,{help:true,lockedInert:true,helpInert:false},'help remains usable while input is paused');
  const resumedHelpFocus=await evaluate(`(async()=>{document.querySelector('#locked [data-help]').click();testState.sessionLocked=false;await refresh();closeSheet();return document.activeElement.id})()`);
  assert.equal(resumedHelpFocus,'settings-open','closing Help after resume restores focus to a visible main control');
  const timeout=await evaluate(`(async()=>{testState.sessionLocked=false;await refresh();calls.length=0;hang=true;await command({type:'action',action:'playPause'});hang=false;return calls.filter(x=>x.path==='/command').length})()`);
  assert.equal(timeout,1,'timed-out command is never replayed');
  const burst=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms)), pad=document.querySelector('#pad');
    const gesture=(type,id,x,y)=>pad.dispatchEvent(new PointerEvent(type,{pointerId:id,clientX:x,clientY:y,bubbles:true}));
    calls.length=0; window.illegalMotion.length=0; window.maxActive=0; window.commandLatency=10;
    gesture('pointerdown',30,0,0);
    for(let i=1;i<=6;i++) gesture('pointermove',30,i*50,i*50);
    gesture('pointerup',30,300,300);
    await command({type:'click',button:'left',count:1});
    while(queue.length||active) await sleep(10);
    window.commandLatency=3;
    const commands=calls.filter(c=>c.path==='/command').map(c=>c.body);
    const motions=commands.filter(c=>c.type==='move');
    return {commands:commands.map(c=>c.type),motions:motions.length,totalX:motions.reduce((s,c)=>s+c.dx,0),totalY:motions.reduce((s,c)=>s+c.dy,0),illegal:window.illegalMotion.length,maxActive:window.maxActive};
  })()`);
  assert.equal(burst.illegal,0,'every posted motion delta is within its command limit');
  assert.ok(burst.motions>=2&&burst.motions<=3,`burst produced multiple motion posts (got ${burst.motions})`);
  assert.equal(burst.totalX,1380,'motion travel accumulated and preserved on ordinary lift');
  assert.equal(burst.totalY,1380,'motion travel accumulated and preserved on ordinary lift');
  assert.equal(burst.maxActive,1,'commands remain single-flight across the burst');
  assert.equal(burst.commands.at(-1),'click','click posts after the motion queue drains');
  const cancel=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms)), pad=document.querySelector('#pad');
    const gesture=(type,id,x,y)=>pad.dispatchEvent(new PointerEvent(type,{pointerId:id,clientX:x,clientY:y,bubbles:true}));
    calls.length=0; window.illegalMotion.length=0; hang=true;
    gesture('pointerdown',40,0,0);
    for(let i=1;i<=6;i++) gesture('pointermove',40,i*50,0);
    await sleep(5);
    const queuedBefore=queue.length;
    gesture('pointercancel',40,300,0);
    const queuedAfter=queue.filter(x=>x.body.type==='move'||x.body.type==='scroll'||(x.body.type==='drag'&&x.body.phase==='move')).length;
    hang=false; await sleep(50);
    return {queuedBefore,queuedAfter,illegal:window.illegalMotion.length,inflight:calls.filter(c=>c.path==='/command'&&c.body.type==='move').length};
  })()`);
  assert.ok(cancel.queuedBefore>=1,'burst populated the motion queue while transport was hung');
  assert.equal(cancel.queuedAfter,0,'pointercancel discards unsent motion');
  assert.equal(cancel.illegal,0,'cancellation never ships an out-of-range delta');
  const dragOrder=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms)), pad=document.querySelector('#pad');
    const gesture=(type,id,x,y)=>pad.dispatchEvent(new PointerEvent(type,{pointerId:id,clientX:x,clientY:y,bubbles:true}));
    calls.length=0; window.illegalMotion.length=0; window.commandLatency=10;
    document.querySelector('#drag').click();
    gesture('pointerdown',50,0,0);
    for(let i=1;i<=4;i++) gesture('pointermove',50,i*40,0);
    gesture('pointerup',50,160,0);
    document.querySelector('#drag').click();
    while(queue.length||active) await sleep(10);
    window.commandLatency=3;
    return {types:calls.filter(c=>c.path==='/command').map(c=>c.body.type+':'+(c.body.phase||'')),illegal:window.illegalMotion.length};
  })()`);
  assert.equal(dragOrder.illegal,0,'drag motion packets stay within the command limit');
  const dragPhases=dragOrder.types.filter(t=>t.startsWith('drag:')).map(t=>t.slice(5));
  assert.equal(dragPhases[0],'start','drag start posts first');
  assert.equal(dragPhases.at(-1),'end','drag end posts after every queued move');
  const fineMovement=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms)),pad=document.querySelector('#pad');
    const g=(type,x)=>pad.dispatchEvent(new PointerEvent(type,{pointerId:70,clientX:x,clientY:0,bubbles:true}));
    g('pointerdown',0);g('pointercancel',0);calls.length=0;
    g('pointerdown',0);for(let i=1;i<=12;i++)g('pointermove',i/10);g('pointerup',1.2);
    while(queue.length||active)await sleep(10);
    return calls.filter(x=>x.path==='/command'&&x.body.type==='move').reduce((sum,x)=>sum+x.body.dx,0);
  })()`);
  assert.equal(fineMovement,2,'fractional finger movements accumulate instead of disappearing');
  const failedMotion=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms));await sleep(25);
    calls.length=0;hang=true;
    command({type:'move',dx:100,dy:0});command({type:'move',dx:200,dy:0});
    const clicked=await command({type:'click',button:'left',count:1});
    hang=false;await sleep(40);
    return {clicked,posted:calls.filter(x=>x.path==='/command').map(x=>x.body),queued:queue.length};
  })()`);
  assert.equal(failedMotion.clicked,false,'a failed motion send rejects the queued click');
  assert.equal(failedMotion.posted.length,1,'neither motion nor click is replayed after timeout');
  assert.equal(failedMotion.queued,0);
  const staleMotion=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms));await sleep(25);
    calls.length=0;commandLatency=320;
    command({type:'move',dx:100,dy:0});command({type:'move',dx:200,dy:0});
    const clicked=await command({type:'click',button:'left',count:1});
    commandLatency=3;
    return {clicked,posted:calls.filter(x=>x.path==='/command').length,status:document.querySelector('#status').textContent,queued:queue.length};
  })()`);
  assert.equal(staleMotion.clicked,false,'an expired motion backlog cannot trigger a late click');
  assert.equal(staleMotion.posted,1);assert.equal(staleMotion.queued,0);
  assert.match(staleMotion.status,/slow/i,'slow transport explains why old movement stopped');
  console.log('PASS bounded proportional motion, lift/cancel order, failed sends and stale-click prevention');
  const textFailure=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms)), input=document.querySelector('#text'), form=document.querySelector('#text-form');
    calls.length=0;commandFailure='failure';input.value='preserve me';form.requestSubmit();await sleep(20);
    const failed={value:input.value,status:document.querySelector('#status').textContent,count:calls.filter(x=>x.path==='/command').length};
    commandFailure='';await command({type:'key',key:'enter',modifiers:[]});
    const cleared=document.querySelector('#status').textContent;
    testState.accessibility=false;await refresh();commandFailure='failure';form.requestSubmit();await sleep(20);
    commandFailure='';await command({type:'key',key:'enter',modifiers:[]});
    const permission=document.querySelector('#status').textContent;
    testState.accessibility=true;await refresh();hang=true;form.requestSubmit();await sleep(60);hang=false;
    const timed={value:input.value,status:document.querySelector('#status').textContent};
    await refresh();const stateCleared=document.querySelector('#status').textContent;
    commandFailure='unauthorized';form.requestSubmit();await sleep(20);
    return {failed,cleared,permission,timed,stateCleared,unauthorized:{value:input.value,pair:document.querySelector('#pair').classList.contains('open'),status:document.querySelector('#status').textContent}};
  })()`);
  assert.equal(textFailure.failed.value,'preserve me');assert.match(textFailure.failed.status,/Send failed/);assert.equal(textFailure.failed.count,1);
  assert.equal(textFailure.cleared,'','successful command clears a runtime error');
  assert.match(textFailure.permission,/Accessibility/,'success preserves the active permission notice');
  assert.equal(textFailure.timed.value,'preserve me');assert.ok(textFailure.timed.status,'timeout is visible');
  assert.equal(textFailure.stateCleared,'','successful state clears a runtime error');
  assert.equal(textFailure.unauthorized.value,'preserve me');assert.equal(textFailure.unauthorized.pair,true);assert.match(textFailure.unauthorized.status,/Pair/);
  await cdp('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/?test=pair#pair=123456`});await wait(100);
  const pairing=await evaluate(`({hash:location.hash,call:calls.find(x=>x.path==='/pair')})`);
  assert.equal(pairing.hash,'','pairing code removed from address bar');
  assert.equal(pairing.call.body.code,'123456');assert.equal(pairing.call.key,undefined,'pairing uses no device credential');
  const unpairedHelp=await evaluate(`(()=>{key='';storage.set('');showPair();document.querySelector('#pair [data-help]').click();const result={help:document.querySelector('#help-sheet').classList.contains('open'),pairInert:document.querySelector('#pair').inert,summary:document.querySelector('#diagnostics').value};closeSheet();result.pairRestored=!document.querySelector('#pair').inert;return result})()`);
  assert.equal(unpairedHelp.help,true);assert.equal(unpairedHelp.pairInert,true);assert.equal(unpairedHelp.pairRestored,true);assert.match(unpairedHelp.summary,/App version: Unavailable/);assert.match(unpairedHelp.summary,/Connect to the Mac/);
  console.log('PASS gestures, drag release, heartbeat, UI actions, pairing, serial transport and locked-session wake');
}
(async()=>{try{await main()}catch(e){console.error(e);process.exitCode=1}finally{
  if(closeBrowser&&child?.exitCode===null&&child?.signalCode===null){try{await closeBrowser()}catch{};await Promise.race([new Promise(r=>child.once('exit',r)),wait(2000)])}
  if(ws)ws.close();if(child&&child.exitCode===null&&child.signalCode===null){child.kill('SIGTERM');await Promise.race([new Promise(r=>child.once('exit',r)),wait(2000)]);if(child.exitCode===null&&child.signalCode===null){child.kill('SIGKILL');await new Promise(r=>child.once('exit',r))}}
  await new Promise(r=>server.close(r));await fs.promises.rm(profile,{recursive:true,force:true,maxRetries:20,retryDelay:150});
}})();
