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
  const cdp=(method,params={})=>new Promise((resolve,reject)=>{const n=++id,t=setTimeout(()=>{pending.delete(n);reject(Error(`${method} timeout`))},15000);pending.set(n,m=>{clearTimeout(t);m.error?reject(Error(m.error.message)):resolve(m.result)});ws.send(JSON.stringify({id:n,method,params}))});
  closeBrowser=()=>cdp('Browser.close');
  const evaluate=async expression=>{const r=await cdp('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value};
  const waitFor=async(expression,label)=>{const deadline=Date.now()+5000;while(Date.now()<deadline){if(await evaluate(expression))return;await wait(20)}throw Error(`Timed out waiting for ${label}`)};
  const waitForInputIdle=()=>waitFor('!active && queue.length === 0 && !gestureTimer','the serialized input queue to drain');
  await cdp('Page.enable');await cdp('Runtime.enable');
  await cdp('Page.addScriptToEvaluateOnNewDocument',{source:`
    localStorage.setItem('sofaKey','a'.repeat(64)); Element.prototype.setPointerCapture=function(){};
    window.confirm=()=>true;window.calls=[];window.mockActive=0;window.maxActive=0;window.hang=false;window.commandFailure='';window.presenterFailure=false;window.stateFailure=false;window.commandLatency=3;window.illegalMotion=[];
    window.testDevices=[];window.testState={name:'Mock Mac',frontApp:'Brave Browser',appVersion:'0.1.0',appBuild:'7',macOSVersion:'15.0.1',signingStatus:'ad-hoc',accessibility:true,sharing:true,sessionLocked:false,screenSleeping:false,displays:[{id:'d1',name:'Display'}],displayID:'d1',shortcuts:[],keepAwake:false};
    const realTimeout=window.setTimeout;window.setTimeout=(fn,ms,...args)=>realTimeout(fn,ms===9000&&window.hang?30:ms,...args);
    const motionBody=b=>b&&(b.type==='move'||b.type==='scroll'||(b.type==='drag'&&b.phase==='move'));
    const badDelta=(v,limit)=>!Number.isFinite(v)||Math.abs(v)>limit;
    window.fetch=async(path,options={})=>{const body=options.body?JSON.parse(options.body):null;calls.push({path,body,key:options.headers?.['X-Sofa-Key']});
      if(path==='/command'&&motionBody(body)&&(badDelta(body.dx||0,body.type==='scroll'?300:1000)||badDelta(body.dy||0,body.type==='scroll'?300:1000))){window.illegalMotion.push({dx:body.dx,dy:body.dy});return {status:400,ok:false,json:async()=>({error:'Motion delta exceeds command limit'})}}
      if(path==='/command'||path==='/presenter'){window.mockActive++;window.maxActive=Math.max(window.maxActive,window.mockActive);try{await new Promise((resolve,reject)=>{if(!hang)realTimeout(resolve,window.commandLatency);options.signal.addEventListener('abort',()=>reject(Error('aborted')),{once:true})})}finally{window.mockActive--}}
      if(path==='/presenter'&&presenterFailure)return {status:500,ok:false,json:async()=>({error:'Presenter unavailable'})};
      if(path==='/command'&&commandFailure)return {status:commandFailure==='unauthorized'?401:500,ok:false,json:async()=>({error:'Send failed'})};
      if(path==='/state'&&stateFailure)throw Error('Connection unavailable');
      return {status:200,ok:true,json:async()=>path==='/state'?testState:path==='/devices'?testDevices:{ok:true,token:'b'.repeat(64)}}};
  `});
  await cdp('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});await wait(300);
  const subtitle=await evaluate(`(async()=>{
    await refresh();const withApp=document.querySelector('#connection').textContent;
    testState.frontApp='';await refresh();const withoutApp=document.querySelector('#connection').textContent;
    testState.frontApp='Brave Browser';await refresh();return {withApp,withoutApp};
  })()`);
  assert.equal(subtitle.withApp,'Connected · Mock Mac · Brave Browser');
  assert.equal(subtitle.withoutApp,'Connected · Mock Mac');
  assert.equal(await evaluate(`document.querySelector('#connection').dataset.connected`),'true','connected indicator follows a successful state request');
  const mainDisplayControls=await evaluate(`(async()=>{
    calls.length=0;
    document.querySelector('#settings-open').click();
    const ids=['screen-off-main','wake-main','brightness-down','brightness-up'];
    const controls=ids.map(id=>{const b=document.getElementById(id);return {id,label:b.getAttribute('aria-label'),title:b.title,icon:b.querySelector('svg use')?.getAttribute('href'),main:!!b.closest('#settings-sheet.open')&&!!b.getClientRects().length}});
    for(const id of ids)await document.getElementById(id).onclick();
    const commands=calls.filter(c=>c.path==='/command').map(c=>c.body);closeSheet();return {controls,commands};
  })()`);
  assert.ok(mainDisplayControls.controls.every(c=>c.main && c.label && c.title && c.icon?.startsWith('#icon-')),'display controls are in Settings, named and use local icons');
  assert.deepEqual(mainDisplayControls.commands.map(c=>c.action),['screenOff','screenOn','brightnessDown','brightnessUp']);
  assert.ok(mainDisplayControls.commands.every(c=>c.type==='action'));
  const localShortcutIcons=await evaluate(`(async()=>{
    calls.length=0;
    testState.shortcuts=[{id:'yt',name:'YouTube',kind:'website',url:'https://private.example/watch'},{id:'app',name:'IINA',kind:'app',bundleID:'private.app'},{id:'downloads',name:'Downloads',kind:'downloads'},{id:'unsafe',name:'<img src=x onerror=alert(1)>',kind:'website'}];
    await refresh();document.querySelector('#shortcuts-open').click();
    const rows=[...document.querySelectorAll('#shortcut-list .shortcut')];
    const icons=rows.map(row=>{const b=row.querySelector('.launch'),icon=b.querySelector('.shortcut-initial');return {label:b.getAttribute('aria-label'),text:b.querySelector('.shortcut-label').textContent,initial:icon.textContent,hidden:icon.getAttribute('aria-hidden'),symbol:icon.querySelector('use')?.getAttribute('href')||null,images:row.querySelectorAll('img').length}});
    await rows[0].querySelector('.launch').onclick();
    const requests=calls.filter(c=>c.path!=='/state').map(c=>({path:c.path,body:c.body}));
    closeSheet();testState.shortcuts=[];await refresh();
    return {icons,requests};
  })()`);
  assert.deepEqual(localShortcutIcons.icons.map(x=>x.label),['YouTube','IINA','Downloads','<img src=x onerror=alert(1)>']);
  assert.deepEqual(localShortcutIcons.icons.map(x=>x.text),['YouTube','IINA','Downloads','<img src=x onerror=alert(1)>']);
  assert.deepEqual(localShortcutIcons.icons.map(x=>x.initial),['Y','','','<']);
  assert.equal(localShortcutIcons.icons[1].symbol,'#icon-play-pause');
  assert.equal(localShortcutIcons.icons[2].symbol,'#icon-folder');
  assert.ok(localShortcutIcons.icons.every(x=>x.hidden==='true' && x.images===0),'icons are decorative local DOM with no favicon fetch');
  assert.deepEqual(localShortcutIcons.requests,[{path:'/launch',body:{id:'yt'}}],'launch sends only the selected shortcut ID');
  const shortcutLayout=await evaluate(`(()=>{testState.shortcuts=[{id:'brave',name:'Brave',kind:'app'},{id:'iina',name:'IINA',kind:'app'},{id:'dl',name:'Downloads',kind:'downloads'}];shortcuts=testState.shortcuts;renderShortcuts();document.querySelector('#shortcuts-open').click();const list=document.querySelector('#shortcut-list'),rows=[...list.querySelectorAll('.shortcut')],edit=document.querySelector('#shortcut-edit'),form=document.querySelector('#open-form');const before={icons:rows.map(r=>r.querySelector('.shortcut-initial use')?.getAttribute('href')),arrows:rows.flatMap(r=>[...r.querySelectorAll('button:not(.launch)')]).every(b=>getComputedStyle(b).display==='none'),formRow:getComputedStyle(form).flexDirection,present:document.querySelector('#present-open use')?.getAttribute('href')};edit.click();const editing=rows[0].querySelector('button:not(.launch)').getClientRects().length>0;edit.click();closeSheet();testState.shortcuts=[];shortcuts=[];renderShortcuts();return {before,editing}})()`);
  assert.deepEqual(shortcutLayout.before.icons,['#icon-brave','#icon-play-pause','#icon-folder']);
  assert.equal(shortcutLayout.before.arrows,true,'shortcut edit arrows are hidden until requested');assert.equal(shortcutLayout.editing,true,'editing retains reordering controls');
  assert.equal(shortcutLayout.before.formRow,'row','address and send arrow share a row');assert.equal(shortcutLayout.before.present,'#icon-present','present and fullscreen have distinct icons');
  console.log('PASS main display controls and private local shortcut icons');
  const deviceRow=await evaluate(`(async()=>{
    testDevices=[{id:'long-device',name:'Paired phone '+ 'x'.repeat(180),current:false}];
    document.querySelector('#settings-open').click();await loadDevices();
    const row=document.querySelector('#devices .shortcut'),label=row.querySelector('span'),style=getComputedStyle(label);
    const result={label:label.className,flex:style.flexGrow,minWidth:style.minWidth,overflow:style.overflow,textOverflow:style.textOverflow,rowWidth:row.clientWidth,rowScroll:row.scrollWidth,remove:row.querySelector('button').getAttribute('aria-label')};
    closeSheet();testDevices=[];return result;
  })()`);
  assert.equal(deviceRow.label,'shortcut-label');assert.equal(deviceRow.flex,'1');assert.equal(deviceRow.minWidth,'0px');
  assert.equal(deviceRow.overflow,'hidden');assert.equal(deviceRow.textOverflow,'ellipsis');
  assert.ok(deviceRow.rowScroll<=deviceRow.rowWidth+1,'long paired-device names cannot widen the dialog');
  assert.match(deviceRow.remove,/^Remove Paired phone /);
  const presenterUI=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms));
    const idle=async()=>{const until=Date.now()+4000;while(active || queue.length || gestureTimer){if(Date.now()>until)throw Error('Timed out draining presenter input');await sleep(20)}};
    calls.length=0;document.querySelector('#present-open').click();
    const display=document.querySelector('#present-display').value,navHeight=document.querySelector('#present-next').getBoundingClientRect().height;
    document.querySelector('#present-undo').click();document.querySelector('#present-clear').click();
    document.querySelector('#present-next').click();document.querySelector('#present-previous').click();document.querySelector('#present-exit').click();await idle();
    const smooth=document.querySelector('#present-smooth'),shapes=document.querySelector('#present-shapes');
    const optionsDefaultOff=!smooth.checked&&!shapes.checked;document.querySelector('#present-options').open=true;
    const colours=['red','blue','green','yellow'];
    const colourStates=colours.map(c=>{const b=document.querySelector('[data-present-colour='+c+']');b.click();return b.getAttribute('aria-pressed')==='true' && document.querySelectorAll('[data-present-colour][aria-pressed=true]').length===1});
    document.querySelector('[data-present-colour=green]').click();document.querySelector('#present-pen').click();smooth.click();
    const penSelected=document.querySelector('#present-pen').getAttribute('aria-pressed')==='true' && document.querySelector('#present-laser').getAttribute('aria-pressed')==='false';
    const pad=document.querySelector('#present-pad'),rect=pad.getBoundingClientRect();
    const initialReticle=(()=>{const d=document.querySelector('#present-dot');return !d.hidden && getComputedStyle(d).display!=='none' && d.getBoundingClientRect().width>=24})() ;
    const emit=(type,x,y)=>pad.dispatchEvent(new PointerEvent(type,{pointerId:42,button:0,clientX:rect.left+rect.width*x,clientY:rect.top+rect.height*y,bubbles:true}));
    emit('pointerdown',0.25,0.25);emit('pointermove',0.75,0.75);emit('pointerup',0.75,0.75);
    await idle();const heartbeat=!!presentHeartbeat;
    const dot=document.querySelector('#present-dot'),reticleAfterLift=!dot.hidden && getComputedStyle(dot).display!=='none' && dot.style.left.includes('75%');
    document.querySelector('#present-highlight').click();document.querySelector('[data-present-colour=yellow]').click();smooth.click();shapes.click();
    const highlightSelected=document.querySelector('#present-highlight').getAttribute('aria-pressed')==='true' && document.querySelector('[data-present-colour=yellow]').getAttribute('aria-pressed')==='true';
    emit('pointerdown',0.2,0.3);emit('pointerup',0.4,0.6);await idle();
    document.querySelector('#present-laser').click();
    emit('pointerdown',0.2,0.3);emit('pointercancel',0.8,0.9);await idle();
    document.querySelector('#present-next').click();await idle();
    document.querySelector('#present-exit').click();await idle();
    document.querySelector('#present-sheet [data-close]').click();await idle();
    return {display,heartbeat,optionsDefaultOff,colourStates,penSelected,highlightSelected,initialReticle,reticleAfterLift,navHeight,cleared:!presentHeartbeat, calls:calls.filter(c=>c.path==='/command'||c.path==='/presenter'),closed:!document.querySelector('#present-sheet').classList.contains('open'),modal:document.querySelector('#present-sheet [role=dialog]').getAttribute('aria-label')};
  })()`);
  assert.equal(presenterUI.display,'d1');assert.equal(presenterUI.modal,'Presenter controls');
  assert.equal(presenterUI.heartbeat,true);assert.equal(presenterUI.optionsDefaultOff,true);assert.ok(presenterUI.colourStates.every(Boolean));assert.equal(presenterUI.penSelected,true);assert.equal(presenterUI.highlightSelected,true);assert.equal(presenterUI.initialReticle,true);assert.equal(presenterUI.reticleAfterLift,true);assert.ok(presenterUI.navHeight>=72,'large slide navigation targets');assert.equal(presenterUI.cleared,true);assert.equal(presenterUI.closed,true);
  const pc=presenterUI.calls.filter(c=>c.path==='/presenter' && c.body.action!=='heartbeat');
  assert.deepEqual(pc.map(c=>c.body.action),['start','move','end','start','move','end','start','end','clear','stop']);
  assert.equal(pc[0].body.mode,'pen');assert.equal(pc[0].body.color,'green');assert.equal(pc[0].body.smooth,true);assert.equal(pc[0].body.shapes,false);assert.equal(pc[0].body.display,'d1');
  assert.equal(pc[3].body.mode,'highlight');assert.equal(pc[3].body.color,'yellow');assert.equal(pc[3].body.smooth,false);assert.equal(pc[3].body.shapes,true);
  assert.ok(Math.abs(pc[4].body.x-0.4)<0.001 && Math.abs(pc[4].body.y-0.6)<0.001,'finger-up coordinate precedes end even without a move event');
  assert.equal(pc[6].body.mode,'laser');assert.equal(pc[7].body.action,'end','pointer cancellation ends without a spurious final move');
  assert.ok(Math.abs(pc[0].body.x-0.25)<0.001 && Math.abs(pc[1].body.x-0.75)<0.001);
  assert.ok(pc.every(c=>c.key==='a'.repeat(64)),'presenter calls are authenticated');
  assert.ok(presenterUI.calls.findIndex(c=>c.body.action==='clear') < presenterUI.calls.findLastIndex(c=>c.body.key==='right'),'clear precedes the next slide');
  assert.ok(presenterUI.calls.findIndex(c=>c.body.action==='stop') < presenterUI.calls.findLastIndex(c=>c.body.key==='escape'),'overlay stops before ending slideshow');
  assert.deepEqual(presenterUI.calls.filter(c=>c.path==='/command').map(c=>c.body.key),['right','left','escape','right','escape']);
  assert.ok(presenterUI.calls.filter(c=>c.path==='/command').every(c=>c.body.modifiers.length===0));
  console.log('PASS presenter slides, authenticated ordered pen gestures, display selection and cleanup');
  const appActions=await evaluate(`(async()=>{
    const pause=ms=>new Promise(r=>setTimeout(r,ms));
    const result=[];
    for(const app of ['keynote','powerpoint','browser','']) {
      testState.presenterApp=app; await refresh(true); calls.length=0;
      const hidden=document.querySelector('#present-app-actions').hidden;
      if(app){document.querySelector('#present-start').click(); document.querySelector('#present-black').click(); await pause(40);}
      result.push({app,hidden,commands:calls.filter(c=>c.path==='/command').map(c=>c.body)});
    }
    testState.presenterApp='';await refresh(true);return result;
  })()`);
  assert.deepEqual(appActions.map(x=>x.hidden),[false,false,false,true]);
  assert.deepEqual(appActions.slice(0,3).map(x=>x.commands[0]),[
    {type:'key',key:'p',modifiers:['option','command'],presenterTarget:'keynote'},
    {type:'key',key:'enter',modifiers:['shift','command'],presenterTarget:'powerpoint'},
    {type:'key',key:'enter',modifiers:['command'],presenterTarget:'browser'}]);
  assert.ok(appActions.slice(0,3).every(x=>x.commands[1].key==='b' && x.commands[1].presenterTarget===x.app));
  const check=await evaluate(`(async()=>{testState.accessibility=false;await refresh(true);const denied=document.querySelector('#present-check').textContent;testState.accessibility=true;await refresh(true);return [denied,document.querySelector('#present-check').textContent]})()`);
  assert.match(check[0],/Accessibility/);assert.match(check[1],/ready/);
  console.log('PASS presentation shortcuts, active-app selection and readiness');

  await evaluate(`document.querySelector('#present-open').click();document.querySelector('#present-options').open=false;document.querySelector('#present-options summary').focus();calls.length=0`);
  await cdp('Input.dispatchKeyEvent',{type:'rawKeyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
  await cdp('Input.dispatchKeyEvent',{type:'keyUp',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
  assert.equal(await evaluate(`document.activeElement.id`),'present-pad','keyboard can tab from stroke options to drawing pad');
  await cdp('Input.dispatchKeyEvent',{type:'rawKeyDown',key:' ',code:'Space',windowsVirtualKeyCode:32});
  await cdp('Input.dispatchKeyEvent',{type:'rawKeyDown',key:'ArrowRight',code:'ArrowRight',windowsVirtualKeyCode:39});
  await cdp('Input.dispatchKeyEvent',{type:'keyUp',key:'ArrowRight',code:'ArrowRight',windowsVirtualKeyCode:39});
  await cdp('Input.dispatchKeyEvent',{type:'keyUp',key:' ',code:'Space',windowsVirtualKeyCode:32});
  await waitForInputIdle();
  const keyboardPresenter=await evaluate(`calls.filter(c=>c.path==='/presenter' && c.body.action!=='heartbeat').map(c=>c.body.action)`);
  assert.deepEqual(keyboardPresenter,['start','move','end'],'keyboard can point and draw');
  const presenterErrors=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms));
    const idle=async()=>{const until=Date.now()+4000;while(active || queue.length || gestureTimer){if(Date.now()>until)throw Error('Timed out draining presenter input');await sleep(20)}};
    presenterFailure=true;await presenter('heartbeat');await idle();
    const failure=document.querySelector('#status').textContent;
    const note=document.querySelector('#present-sheet .sheet-status');
    const sheet=document.querySelector('#present-sheet .sheet');sheet.scrollTop=sheet.scrollHeight;
    const nr=note.getBoundingClientRect(),sr=sheet.getBoundingClientRect();
    const inline=note.previousElementSibling?.classList.contains('sheet-head') && getComputedStyle(note).position==='sticky' && nr.height>0 && nr.top>=sr.top && nr.bottom<=sr.bottom;
    presenterFailure=false;await refresh();const afterRefresh=document.querySelector('#status').textContent;
    await presenter('heartbeat');const afterHeartbeat=document.querySelector('#status').textContent;
    startPresentPoint();await idle();const afterGesture=document.querySelector('#status').textContent;
    return {failure,afterRefresh,afterHeartbeat,afterGesture,inline};
  })()`);
  assert.match(presenterErrors.failure,/Presenter unavailable/);
  assert.equal(presenterErrors.inline,true,'presenter status is visible and sticky immediately below the heading');
  assert.equal(presenterErrors.afterRefresh,presenterErrors.failure,'state refresh preserves presenter error');
  assert.equal(presenterErrors.afterHeartbeat,presenterErrors.failure,'heartbeat preserves presenter error');
  assert.equal(presenterErrors.afterGesture,'','a successful deliberate gesture clears presenter error');
  await evaluate(`document.querySelector('#present-sheet [data-close]').click()`);await waitForInputIdle();
  await evaluate(`localStorage.setItem('sofaTheme','custom');localStorage.setItem('sofaColour','#ff0000')`);
  await cdp('Page.reload',{ignoreCache:true});await wait(150);
  const migrated=await evaluate(`({theme:localStorage.getItem('sofaTheme'),colour:localStorage.getItem('sofaColour'),background:getComputedStyle(document.body).backgroundColor,hasTheme:!!document.querySelector('#theme')})`);
  assert.deepEqual(migrated,{theme:'custom',colour:'#ff0000',background:'rgb(17, 18, 20)',hasTheme:false},'older colour preferences remain intact and the new appearance defaults safely');
  for(const name of ['soft','velvet','paper']){
    await evaluate(`(()=>{const select=document.querySelector('#appearance');select.value='${name}';select.dispatchEvent(new Event('change'))})()`);
    await cdp('Page.reload',{ignoreCache:true});await wait(150);
    const appearance=await evaluate(`(()=>{const s=getComputedStyle(document.documentElement),v=k=>s.getPropertyValue('--'+k).trim();const lum=h=>{const c=[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);return .2126*c[0]+.7152*c[1]+.0722*c[2]};const contrast=(a,b)=>{const x=lum(a),y=lum(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05)};return {name:document.querySelector('#appearance').value,stored:localStorage.getItem('sofaAppearance'),readable:['bg','card','pad','sheet','pressed'].every(k=>contrast(v('ink'),v(k))>=4.5),muted:['bg','pad','sheet'].every(k=>contrast(v('muted'),v(k))>=4.5),selected:contrast(v('selection'),v('selection-ink'))>=4.5,focus:contrast(v('accent'),v('pad'))>=3}})()`);
    assert.deepEqual(appearance,{name,stored:name,readable:true,muted:true,selected:true,focus:true},`${name} persists with readable text, selected state and focus`);
    for(const width of [320,390]){await cdp('Emulation.setDeviceMetricsOverride',{width,height:844,deviceScaleFactor:1,mobile:true});const layout=await evaluate(`(()=>({overflow:document.documentElement.scrollWidth>innerWidth,buttons:[...document.querySelectorAll('main button')].filter(b=>b.getClientRects().length).map(b=>{const r=b.getBoundingClientRect();return {w:r.width,h:r.height,border:getComputedStyle(b).borderTopWidth,name:b.getAttribute('aria-label'),text:b.textContent.trim()}})}))()`);assert.equal(layout.overflow,false,`${name} fits ${width}px`);assert.ok(layout.buttons.every(b=>b.w>=44&&b.h>=44&&b.border==='0px'&&b.name&&!b.text),`${name} main buttons retain accessible names and borderless targets at ${width}px`)}
    assert.match(await evaluate(`getComputedStyle(document.querySelector('header h1')).fontFamily`), /-apple-system/, `${name} uses the system sans font`);
    if(process.env.SOFA_TEST_THEME_DIR){await cdp('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});const shot=await cdp('Page.captureScreenshot',{format:'png'});fs.writeFileSync(path.join(process.env.SOFA_TEST_THEME_DIR,`real-${name}.png`),Buffer.from(shot.data,'base64'))}
  }
  await evaluate(`localStorage.setItem('sofaAppearance','invalid')`);await cdp('Page.reload',{ignoreCache:true});await wait(150);
  assert.equal(await evaluate(`document.querySelector('#appearance').value`),'soft','unknown stored appearance safely falls back');
  const access=await evaluate(`(()=>{document.querySelector('#shortcuts-open').click();const keys=['present-open'].map(id=>{const el=document.getElementById(id);return !!el.getClientRects().length&&!!el.closest('#shortcuts-sheet.open')});document.querySelector('#present-open').click();const present=!!document.querySelector('#present-sheet.open');closeSheet();const back=!!document.querySelector('#shortcuts-sheet.open');closeSheet();return {keys,present,back}})()`);
  assert.deepEqual(access,{keys:[true],present:true,back:true},'presenter is discoverable in Shortcuts and retains navigation');
  const sharedPanel=await evaluate(`(()=>{const panel=document.querySelector('.remote-panel'),pad=document.querySelector('#pad');const keys=[...panel.querySelectorAll('button')];return {count:keys.length,separate:keys.every(b=>!pad.contains(b)),borderless:keys.every(b=>getComputedStyle(b).borderTopWidth==='0px'),inside:panel.contains(pad)&&keys.every(b=>panel.contains(b))}})()`);
  assert.deepEqual(sharedPanel,{count:7,separate:true,borderless:true,inside:true},'button controls share the panel while remaining separate from the touchpad gesture area');
  const touchSurface=await evaluate(`(()=>{const pad=getComputedStyle(document.querySelector('#pad')),panel=getComputedStyle(document.querySelector('.remote-panel'));return {padBorder:pad.borderTopWidth,padBackground:pad.backgroundColor,padShadow:pad.boxShadow,panelBorder:panel.borderTopWidth,panelBackground:panel.backgroundColor}})()`);
  assert.deepEqual(touchSurface,{padBorder:'0px',padBackground:'rgba(0, 0, 0, 0)',padShadow:'none',panelBorder:'0px',panelBackground:'rgba(0, 0, 0, 0)'},'idle touch area and shared panel have no boundary or second background');
  const visual=await evaluate(`(()=>{const volume=document.querySelector('.volume'),track=getComputedStyle(volume,'::before'),drag=document.querySelector('#drag'),right=document.querySelector('#right');return {track:track.content,trackRole:volume.getAttribute('role'),drag:drag.getAttribute('aria-pressed'),right:right.getAttribute('aria-pressed'),play:parseFloat(getComputedStyle(document.querySelector('[data-action="playPause"] svg')).width),prev:parseFloat(getComputedStyle(document.querySelector('[data-action="previous"] svg')).width)}})()`);
  assert.deepEqual({track:visual.track,role:visual.trackRole,drag:visual.drag,right:visual.right},{track:'none',role:null,drag:'false',right:null},'no volume line is shown, and right click remains separate from the drag toggle');assert.ok(visual.play>visual.prev,'play is the visual anchor');
  const navigation=await evaluate(`(()=>{const bar=document.querySelector('.bottom-tools');return {help:bar.contains(document.querySelector('.remote-guide')),keyboard:bar.contains(document.querySelector('#keyboard-open')),shortcuts:bar.contains(document.querySelector('#shortcuts-open')),settings:bar.contains(document.querySelector('#settings-open'))}})()`);
  assert.deepEqual(navigation,{help:true,keyboard:true,shortcuts:true,settings:true},'help, shortcuts and settings share the bottom navigation');
  const keyboardLayout=await evaluate(`(()=>{const sheet=document.querySelector('#keyboard-sheet'),form=sheet.querySelector('#text-form'),grid=sheet.querySelector('.keygrid');return {old:!!sheet.querySelector('#key-form'),textAfter:!!(grid.compareDocumentPosition(form)&Node.DOCUMENT_POSITION_FOLLOWING),last:grid.lastElementChild.dataset.key}})()`);
  assert.deepEqual(keyboardLayout,{old:false,textAfter:true,last:'space'},'typing area and Space are at the bottom without a duplicate key field');
  const keyboardNav=await evaluate(`(()=>{const button=document.querySelector('#keyboard-open');button.click();const open=!!document.querySelector('#keyboard-sheet.open');closeSheet();return {open,focus:document.activeElement===button}})()`);
  assert.deepEqual(keyboardNav,{open:true,focus:true},'bottom keyboard opens and restores focus');
  const remoteGuide=await evaluate(`(()=>{calls.length=0;const details=document.querySelector('.remote-guide'),summary=details.querySelector('summary');const named=summary.getAttribute('aria-label');summary.click();const open=details.open;summary.click();return {named,open,commands:calls.filter(c=>c.path==='/command').length}})()`);
  assert.deepEqual(remoteGuide,{named:'Explain remote icons',open:true,commands:0},'remote icon guide is accessible and never sends commands');
  for(const width of [320,390]){
    await cdp('Emulation.setDeviceMetricsOverride',{width,height:844,deviceScaleFactor:1,mobile:true});
    const guideBounds=await evaluate(`(()=>{const d=document.querySelector('.remote-guide');d.open=true;const r=d.querySelector('.guide-content').getBoundingClientRect();d.open=false;return {left:r.left,right:r.right,width:innerWidth}})()`);
    assert.ok(guideBounds.left>=0&&guideBounds.right<=guideBounds.width,`${width}px help remains within screen`);
    const settings=await evaluate(`(()=>{document.querySelector('#settings-open').click();const sheet=document.querySelector('#settings-sheet .sheet');const buttons=[...sheet.querySelectorAll('button')];return {headings:[...sheet.querySelectorAll('h3')].map(x=>x.textContent),buttons:buttons.map(b=>({name:b.getAttribute('aria-label'),title:b.title,text:b.textContent.trim(),icon:!!b.querySelector('svg[aria-hidden="true"]'),w:b.getBoundingClientRect().width,h:b.getBoundingClientRect().height})),scroll:sheet.scrollWidth,client:sheet.clientWidth,double:!!document.querySelector('#double')}})()`);
    assert.deepEqual(settings.headings,['Display','Mac controls','Sharing','Paired phones']);
    assert.ok(settings.buttons.every(b=>b.name&&b.title&&!b.text&&b.icon&&b.w>=44&&b.h>=44),`${width}px settings action icons have accessible names and touch targets`);
    assert.ok(settings.scroll<=settings.client+1,`${width}px settings have no horizontal overflow`);assert.equal(settings.double,false);
    const guide=await evaluate(`(()=>{calls.length=0;document.querySelector('#settings-sheet .sheet-head [data-help]').click();const details=document.querySelector('#help-sheet .help-disclosure');const collapsed=!details.open;details.querySelector('summary').click();const open=details.open;details.querySelector('summary').click();closeSheet();return {collapsed,open,commands:calls.filter(c=>c.path==='/command').length}})()`);
    assert.deepEqual(guide,{collapsed:true,open:true,commands:0},'settings help explains icons without sending actions');
    if(width===390&&process.env.SOFA_TEST_SETTINGS_SCREENSHOT){const shot=await cdp('Page.captureScreenshot',{format:'png'});fs.writeFileSync(process.env.SOFA_TEST_SETTINGS_SCREENSHOT,Buffer.from(shot.data,'base64'))}
    await evaluate(`closeSheet()`);
  }
  await cdp('DOM.enable');await cdp('CSS.enable');const rootNode=await cdp('DOM.getDocument');const focusNode=await cdp('DOM.querySelector',{nodeId:rootNode.root.nodeId,selector:'#right'});
  await cdp('CSS.forcePseudoState',{nodeId:focusNode.nodeId,forcedPseudoClasses:['focus-visible']});
  assert.notEqual(await evaluate(`getComputedStyle(document.querySelector('#right')).outlineStyle`),'none','keyboard focus is visible');
  await cdp('CSS.forcePseudoState',{nodeId:focusNode.nodeId,forcedPseudoClasses:[]});
  await cdp('Emulation.setEmulatedMedia',{features:[{name:'prefers-reduced-motion',value:'reduce'}]});
  await cdp('CSS.forcePseudoState',{nodeId:focusNode.nodeId,forcedPseudoClasses:['active']});
  const reduced=await evaluate(`(()=>{const s=getComputedStyle(document.querySelector('#right'));return {transform:s.transform,duration:s.transitionDuration}})()`);
  assert.deepEqual(reduced,{transform:'none',duration:'0s'},'reduced motion removes press scaling and transition');
  await cdp('CSS.forcePseudoState',{nodeId:focusNode.nodeId,forcedPseudoClasses:[]});await cdp('Emulation.setEmulatedMedia',{features:[]});
  const padNode=await cdp('DOM.querySelector',{nodeId:rootNode.root.nodeId,selector:'#pad'});
  await cdp('CSS.forcePseudoState',{nodeId:padNode.nodeId,forcedPseudoClasses:['focus-visible']});
  assert.notEqual(await evaluate(`getComputedStyle(document.querySelector('#pad')).outlineStyle`),'none','keyboard-focused touchpad has a visible outline');
  await cdp('CSS.forcePseudoState',{nodeId:padNode.nodeId,forcedPseudoClasses:[]});
  if(process.env.SOFA_TEST_SCREENSHOT){await cdp('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});const shot=await cdp('Page.captureScreenshot',{format:'png'});fs.writeFileSync(process.env.SOFA_TEST_SCREENSHOT,Buffer.from(shot.data,'base64'))}
  const icons=await evaluate(`(()=>{const controls=[...document.querySelectorAll('[data-icon]')];return {count:controls.length,accessible:controls.every(b=>(b.getAttribute('aria-label')||b.textContent.trim())&&b.title&&b.querySelector('svg[aria-hidden="true"] use')),shortcuts:document.querySelector('#shortcuts-open').textContent.trim(),external:controls.some(b=>!b.querySelector('use').getAttribute('href').startsWith('#icon-')),controlTouch:getComputedStyle(document.querySelector('#right')).touchAction,padTouch:getComputedStyle(document.querySelector('#pad')).touchAction,bodyTouch:getComputedStyle(document.body).touchAction}})()`);
  assert.ok(icons.count>=20);assert.equal(icons.accessible,true,'icons retain names and tooltips');assert.equal(icons.shortcuts,'');assert.equal(icons.external,false,'all SVG icons are local');assert.equal(icons.controlTouch,'manipulation');assert.equal(icons.padTouch,'none');assert.equal(icons.bodyTouch,'auto','pinch and text selection remain available elsewhere');
  assert.deepEqual(await evaluate(`Array.from(document.querySelector('.bottom-tools').children).map(x=>x.id || 'help')`),['help','settings-open','keyboard-open','shortcuts-open'],'bottom navigation follows the requested order');
  assert.equal(await evaluate(`document.querySelector('[data-action="spotlight"]')`),null,'Spotlight icon removed');
  const hold=await evaluate(`(async()=>{
    const sleep=ms=>new Promise(r=>setTimeout(r,ms));calls.length=0;
    document.querySelector('#keyboard-open').click();const b=document.querySelector('#right-option-hold');
    b.dispatchEvent(new PointerEvent('pointerdown',{pointerId:17,button:0,bubbles:true}));await sleep(30);
    const pressed=b.getAttribute('aria-pressed');
    b.dispatchEvent(new PointerEvent('pointerup',{pointerId:17,button:0,bubbles:true}));await sleep(60);
    const result={pressed,released:b.getAttribute('aria-pressed'),commands:calls.filter(x=>x.path==='/command').map(x=>x.body)};closeSheet();return result;
  })()`);
  assert.equal(hold.pressed,'true');assert.equal(hold.released,'false');
  assert.deepEqual(hold.commands,[{type:'rightOption',phase:'start'},{type:'rightOption',phase:'end'}]);
  const holdCancel=await evaluate(`(async()=>{
    calls.length=0;document.querySelector('#keyboard-open').click();const b=document.querySelector('#right-option-hold');
    b.dispatchEvent(new PointerEvent('pointerdown',{pointerId:18,button:0,bubbles:true}));await new Promise(r=>setTimeout(r,30));
    b.dispatchEvent(new PointerEvent('pointercancel',{pointerId:18,button:0,bubbles:true}));await new Promise(r=>setTimeout(r,50));
    const result={pressed:b.getAttribute('aria-pressed'),commands:calls.filter(x=>x.path==='/command').map(x=>x.body)};closeSheet();return result;
  })()`);
  assert.equal(holdCancel.pressed,'false');assert.deepEqual(holdCancel.commands,[{type:'rightOption',phase:'start'},{type:'rightOption',phase:'end'}],'touch cancellation releases the key');
  console.log('PASS Right Option press and release');
  console.log('PASS appearance migration and accessible local SVG icons');
  for(const [width,height] of [[320,568],[375,667],[390,844],[430,932],[568,320],[844,390]]){
    await cdp('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:true});
    const geometry=await evaluate(`(()=>{const r=s=>{const x=document.querySelector(s).getBoundingClientRect();return {w:x.width,h:x.height,b:x.bottom}};return {pad:r('#pad'),keys:[...document.querySelectorAll('main button')].filter(x=>x.getClientRects().length).map(x=>{const q=x.getBoundingClientRect();return [q.width,q.height]}),scroll:document.documentElement.scrollWidth,viewport:innerWidth,height:innerHeight,page:document.documentElement.scrollHeight}})()`);
    assert.ok(geometry.pad.h>=150,`${width}x${height} usable touchpad`);
    assert.ok(geometry.keys.every(([w,h])=>w>=44&&h>=44),`${width}x${height} 44px controls`);
    assert.ok(geometry.scroll<=geometry.viewport+1,`${width}x${height} no horizontal overflow`);
    const presentGeometry=await evaluate(`(()=>{document.querySelector('#present-open').click();const sheet=document.querySelector('#present-sheet .sheet');const sizes=[...sheet.querySelectorAll('button,select')].filter(b=>b.getClientRects().length).map(x=>{const q=x.getBoundingClientRect();return [q.width,q.height]});const r={sizes,scroll:sheet.scrollWidth,client:sheet.clientWidth};closeSheet();return r})()`);
    assert.ok(presentGeometry.sizes.every(([w,h])=>w>=44&&h>=44),`${width}x${height} presenter touch targets`);
    assert.ok(presentGeometry.scroll<=presentGeometry.client+1,`${width}x${height} presenter has no horizontal overflow`);
    if(width===390&&height===844&&process.env.SOFA_TEST_SCREENSHOT){const shot=await cdp('Page.captureScreenshot',{format:'png'});fs.writeFileSync(process.env.SOFA_TEST_SCREENSHOT,Buffer.from(shot.data,'base64'))}
    console.log(`PASS responsive ${width}x${height}`);
  }
  await cdp('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
  await cdp('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:2});
  await evaluate(`window.touchDefaults=[];document.addEventListener('touchend',e=>touchDefaults.push({area:e.target.closest('#pad')?'pad':e.target.closest('button')?'control':'outside',prevented:e.defaultPrevented}),{passive:true});calls.length=0;window.scrollTo(0,0)`);
  const point=async selector=>evaluate(`(()=>{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()`);
  const touch=(type,points)=>cdp('Input.dispatchTouchEvent',{type,touchPoints:points.map((p,i)=>({...p,id:i+1,radiusX:2,radiusY:2,force:1}))});
  const tap=async p=>{await touch('touchStart',[p]);await wait(25);await touch('touchEnd',[])};
  const padPoint=await point('#pad');await tap(padPoint);await wait(70);await tap(padPoint);await wait(400);
  const padTaps=await evaluate(`({commands:calls.filter(x=>x.path==='/command').map(x=>x.body),defaults:touchDefaults.slice(),scale:visualViewport.scale})`);
  assert.deepEqual(padTaps.commands,[{type:'tap'},{type:'tap'}],'two actual touch taps send exactly two tap commands, with no fallback duplicates');
  assert.ok(padTaps.defaults.length===2&&padTaps.defaults.every(x=>x.area==='pad'&&x.prevented),'short pad taps suppress only their browser default');assert.equal(padTaps.scale,1,'double pad tap does not zoom');
  await evaluate(`calls.length=0;touchDefaults.length=0`);
  const rightPoint=await point('#right');await tap(rightPoint);await wait(70);await tap(rightPoint);await wait(400);
  const rightTaps=await evaluate(`({commands:calls.filter(x=>x.path==='/command').map(x=>x.body),defaults:touchDefaults.slice(),scale:visualViewport.scale})`);
  assert.deepEqual(rightTaps.commands,[{type:'click',button:'right',count:1},{type:'click',button:'right',count:1}],'repeated control taps are not lost or duplicated');assert.equal(rightTaps.scale,1,'double control tap does not zoom');assert.ok(rightTaps.defaults.every(x=>!x.prevented),'controls rely on CSS rather than global touch cancellation');
  await evaluate(`calls.length=0`);const playPoint=await point('[data-action="playPause"]');await tap(playPoint);await wait(200);
  assert.deepEqual(await evaluate(`calls.filter(x=>x.path==='/command').map(x=>x.body)`),[{type:'action',action:'playPause'}],'a real panel button touch sends only its action, never pad input');
  for (const selector of ['#right', '[data-action="playPause"]', '#keyboard-open', '#shortcuts-open', '#settings-open', '.remote-guide summary']) {
    await evaluate(`calls.length=0`);
    const origin=await point(selector);
    await touch('touchStart',[origin]);
    await touch('touchMove',[{x:origin.x-24,y:origin.y-34}]);
    await touch('touchEnd',[]);await wait(100);
    const swiped=await evaluate(`({commands:calls.filter(x=>x.path==='/command').map(x=>x.body),overlay:!!document.querySelector('.scrim.open'),guide:document.querySelector('.remote-guide').open})`);
    assert.ok(swiped.commands.some(x=>x.type==='move'),`${selector} swipe sends pointer movement`);
    assert.ok(swiped.commands.every(x=>x.type==='move')&&!swiped.overlay&&!swiped.guide,`${selector} swipe does not activate a control`);
  }
  await evaluate(`calls.length=0`);
  const emptyPoint=await evaluate(`(()=>{const r=document.querySelector('.bottom-tools').getBoundingClientRect();return {x:20,y:r.top+r.height/2}})()`);
  await touch('touchStart',[emptyPoint]);await touch('touchMove',[{x:emptyPoint.x+25,y:emptyPoint.y-30}]);await touch('touchEnd',[]);await wait(100);
  assert.ok(await evaluate(`calls.some(x=>x.path==='/command'&&x.body.type==='move')`),'swiping empty space starts pointer movement');
  await evaluate(`calls.length=0;touchDefaults.length=0`);
  await touch('touchStart',[{x:padPoint.x-20,y:padPoint.y},{x:padPoint.x+20,y:padPoint.y}]);
  await touch('touchMove',[{x:padPoint.x-20,y:padPoint.y+24},{x:padPoint.x+20,y:padPoint.y+24}]);
  await touch('touchEnd',[]);await wait(80);
  const scrollTouch=await evaluate(`({commands:calls.filter(x=>x.path==='/command').map(x=>x.body),defaults:touchDefaults.slice()})`);
  assert.ok(scrollTouch.commands.some(x=>x.type==='scroll'),'real two-finger input still scrolls the Mac');assert.ok(scrollTouch.commands.every(x=>x.type!=='click'),'two-finger lift never clicks');assert.ok(scrollTouch.defaults.every(x=>!x.prevented),'two-finger touch defaults are not cancelled by tap fallback');
  await evaluate(`calls.length=0;touchDefaults.length=0;document.querySelector('#settings-open').click();document.querySelector('#settings-sheet [data-help]').click()`);
  const textPoint=await point('#help-sheet p');
  await cdp('Input.synthesizePinchGesture',{x:textPoint.x,y:textPoint.y,scaleFactor:1.4,relativeSpeed:400,gestureSourceType:'touch'});await wait(200);
  const pinch=await evaluate(`({scale:visualViewport.scale,commands:calls.filter(x=>x.path==='/command').length,defaults:touchDefaults.slice()})`);
  assert.ok(pinch.scale>1,'pinch zoom remains available outside the touchpad');assert.equal(pinch.commands,0);assert.ok(pinch.defaults.every(x=>!x.prevented),'help text touch gestures are not globally cancelled');
  await cdp('Emulation.setPageScaleFactor',{pageScaleFactor:1});
  await evaluate(`closeSheet();closeSheet();window.scrollTo(0,0)`);
  console.log('PASS trusted double taps send exactly two clicks without page zoom; two-finger scroll and outside-pad pinch remain available');
  const signingDiagnostics=await evaluate(`(async()=>{
    const samples=[];
    for(const value of ['ad-hoc','certificate-signed','unsigned','unknown','SECRET_CERT_SUBJECT/CDHash/TeamID','__proto__','constructor']) {
      testState.signingStatus=value;await refresh();
      samples.push({summary:document.querySelector('#diagnostics').value,help:document.querySelector('#signing-help').textContent});
    }
    testState.signingStatus='ad-hoc';await refresh();return samples;
  })()`);
  const signingLabels=['Ad hoc','Certificate-signed','Unsigned','Unknown','Unknown','Unknown','Unknown'];
  signingDiagnostics.forEach((sample,index)=>{
    assert.ok(sample.summary.includes('Signing: '+signingLabels[index]),'signing diagnostic uses a fixed public label');
    assert.doesNotMatch(sample.summary,/SECRET_CERT|CDHash|TeamID|Authority=|notari[sz]ed/,'signing diagnostics contain no identity or notarisation claims');
    assert.ok(sample.help.includes('Signing: '+signingLabels[index]));
  });
  assert.match(signingDiagnostics[0].help,/updates may require Accessibility permission again/);
  assert.match(signingDiagnostics[2].help,/updates may require Accessibility permission again/);
  assert.match(signingDiagnostics[1].help,/does not verify Developer ID, notarisation or permission continuity/);
  console.log('PASS fixed signing labels, unknown-value redaction and permission-continuity guidance');
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
    const initial={open:q('#help-sheet').classList.contains('open'),mainInert:q('main').inert,settingsInert:q('#settings-sheet').inert,diagnosticsCollapsed:!q('#diagnostic-details').open,summary:q('#diagnostics').value,version:q('#app-version').textContent,focus:q('#help-sheet').contains(document.activeElement)};
    q('#diagnostic-details summary').focus();document.dispatchEvent(new KeyboardEvent('keydown',{key:'Tab',bubbles:true,cancelable:true}));
    initial.collapsedWrap=document.activeElement===q('#help-sheet [data-close]');
    q('#diagnostic-details summary').click();
    q('#copy-diagnostics').focus();document.dispatchEvent(new KeyboardEvent('keydown',{key:'Tab',bubbles:true,cancelable:true}));
    const wrapped=document.activeElement===q('#help-sheet [data-close]');
    const before=calls.length;await q('#copy-diagnostics').onclick();
    const copied=window.copiedDiagnostic,networkAfterCopy=calls.length-before;
    Object.defineProperty(navigator,'clipboard',{configurable:true,value:undefined});await q('#copy-diagnostics').onclick();
    const fallback={selection:q('#diagnostics').selectionEnd-q('#diagnostics').selectionStart,result:q('#copy-result').textContent};
    testState.appVersion='TOKEN-IN-VERSION';testState.signingStatus='SECRET_CERT_SUBJECT/CDHash/TeamID';await refresh();const sanitized=q('#diagnostics').value;
    document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));
    const restored={settings:q('#settings-sheet').classList.contains('open'),focus:document.activeElement===q('#settings-sheet [data-help]')};
    q('#settings-sheet [data-close]').click();
    const restoredMain={inert:q('main').inert,focus:document.activeElement===q('#settings-open')};
    Object.defineProperty(navigator,'userAgent',{configurable:true,value:oldUA});
    testState.appVersion='0.1.0';testState.signingStatus='ad-hoc';testState.name='Mock Mac';testState.frontApp='Brave Browser';testState.displayID='d1';testState.shortcuts=[];
    q('#text').value='';q('#url').value='';await refresh();
    return {initial,wrapped,copied,networkAfterCopy,fallback,sanitized,restored,restoredMain};
  })()`);
  assert.equal(help.initial.diagnosticsCollapsed,true,'diagnostics start collapsed');assert.equal(help.initial.collapsedWrap,true,'Tab skips hidden disclosure contents and wraps');
  assert.equal(help.initial.open,true);assert.equal(help.initial.mainInert,true);assert.equal(help.initial.settingsInert,true);assert.equal(help.initial.focus,true);
  assert.match(help.initial.summary,/App version: 0\.1\.0/);assert.match(help.initial.summary,/Build: 7/);assert.match(help.initial.summary,/macOS: 15\.0\.1/);assert.match(help.initial.summary,/Browser: Chrome 123\.0\.1\.2/);assert.match(help.initial.summary,/Accessibility allowed: Yes/);assert.match(help.initial.summary,/Signing: Ad hoc/);
  assert.doesNotMatch(help.initial.summary,/SECRET|private\.example|PrivatePhone|secret-ua|a{64}|private-id/,'diagnostics exclude personal fields, full UA and tokens');
  assert.equal(help.copied,help.initial.summary);assert.equal(help.networkAfterCopy,0,'diagnostic copy never uploads');
  assert.equal(help.wrapped,true);assert.equal(help.fallback.selection,help.initial.summary.length);assert.match(help.fallback.result,/Automatic copy is unavailable/);
  assert.match(help.sanitized,/App version: Unavailable/);assert.doesNotMatch(help.sanitized,/TOKEN-IN-VERSION|SECRET_CERT|CDHash|TeamID/,'untrusted version and signing fields cannot inject data into diagnostics');assert.match(help.sanitized,/Signing: Unknown/);
  assert.deepEqual(help.restored,{settings:true,focus:true});assert.deepEqual(help.restoredMain,{inert:false,focus:true});
  for(const [width,height] of [[320,568],[390,844],[844,390]]){
    await cdp('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:true});
    const layout=await evaluate(`(()=>{document.querySelector('#settings-open').click();document.querySelector('#settings-sheet [data-help]').click();const modal=document.querySelector('#help-sheet .sheet'),r=modal.getBoundingClientRect();const result={width:r.width,height:r.height,viewport:innerWidth,screen:innerHeight,scroll:document.documentElement.scrollWidth,targets:[...modal.querySelectorAll('button,a')].map(x=>x.getBoundingClientRect().height)};closeSheet();closeSheet();return result})()`);
    assert.ok(layout.scroll<=layout.viewport+1,`help ${width}x${height} no overflow`);assert.ok(layout.height<=layout.screen,`help ${width}x${height} scrolls within screen`);assert.ok(layout.targets.every(h=>h>=44),`help ${width}x${height} touch targets`);
  }
  if(process.env.SOFA_TEST_HELP_SCREENSHOT){await evaluate(`document.querySelector('#settings-open').click();document.querySelector('#settings-sheet [data-help]').click()`);const shot=await cdp('Page.captureScreenshot',{format:'png'});fs.writeFileSync(process.env.SOFA_TEST_HELP_SCREENSHOT,Buffer.from(shot.data,'base64'));await evaluate(`closeSheet();closeSheet()`)}
  const recovery=await evaluate(`(async()=>{stateFailure=true;await refresh();const disconnected={title:document.querySelector('#connection').textContent,help:!document.querySelector('#connection-help').hidden,indicator:document.querySelector('#connection').dataset.connected};stateFailure=false;document.querySelector('#reconnect').click();await new Promise(r=>setTimeout(r,10));return {disconnected,recovered:document.querySelector('#connection-help').hidden,indicator:document.querySelector('#connection').dataset.connected}})()`);
  assert.match(recovery.disconnected.title,/Disconnected/);assert.equal(recovery.disconnected.help,true);assert.equal(recovery.disconnected.indicator,'false');assert.equal(recovery.recovered,true);assert.equal(recovery.indicator,'true');
  await cdp('Emulation.setDeviceMetricsOverride',{width:320,height:568,deviceScaleFactor:1,mobile:true});
  const largeText=await evaluate(`(()=>{document.documentElement.style.fontSize='200%';document.querySelector('#settings-open').click();document.querySelector('#settings-sheet [data-help]').click();const result={scroll:document.documentElement.scrollWidth,viewport:innerWidth,help:document.querySelector('#help-sheet .sheet').getBoundingClientRect().width};closeSheet();closeSheet();document.documentElement.style.fontSize='';return result})()`);
  assert.ok(largeText.scroll<=largeText.viewport+1,'200% text has no horizontal page overflow');assert.ok(largeText.help<=largeText.viewport+1,'200% help remains within viewport');
  const largePresenter=await evaluate(`(()=>{document.documentElement.style.fontSize='200%';document.querySelector('#present-open').click();const sheet=document.querySelector('#present-sheet .sheet');const r={scroll:sheet.scrollWidth,client:sheet.clientWidth,controls:[...sheet.querySelectorAll('button,select')].filter(b=>b.getClientRects().length).map(b=>{const q=b.getBoundingClientRect();return [q.width,q.height]})};closeSheet();document.documentElement.style.fontSize='';return r})()`);
  assert.ok(largePresenter.scroll<=largePresenter.client+1,'200% presenter text has no horizontal overflow');
  assert.ok(largePresenter.controls.every(([w,h])=>w>=44&&h>=44),'200% presenter controls stay usable');
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
    calls.length=0;gesture('pointerdown',1,0,0);gesture('pointermove',1,12,4);const hidden=document.querySelector('main').classList.contains('is-pointing');gesture('pointerup',1,12,4);const restored=!document.querySelector('main').classList.contains('is-pointing');await sleep(45);
    document.querySelector('#right').click();await sleep(15);
    document.querySelector('#drag').click();gesture('pointerdown',2,0,0);gesture('pointermove',2,10,5);gesture('pointercancel',2,10,5);await sleep(100);
    gesture('pointerdown',3,0,0);gesture('pointerdown',4,0,0);gesture('pointermove',3,0,12);gesture('pointerup',3,0,12);gesture('pointerup',4,0,0);await sleep(60);
    return {commands:calls.filter(x=>x.path==='/command').map(x=>x.body),maxActive,hidden,restored};
  })()`);
  assert.ok(result.hidden && result.restored,'controls recede while moving and return on lift');
  assert.deepEqual(result.commands.map(x=>x.type),['move','click','drag','drag','scroll']);
  assert.equal(result.commands[1].button,'right');
  assert.deepEqual(result.commands.slice(2,4).map(x=>x.phase),['start','end'],'pointercancel drops queued drag-move and still releases the button');
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
  const searchInput=await evaluate(`(async()=>{calls.length=0;const form=document.querySelector('#open-form'),input=document.querySelector('#url');input.value='quiet cats & dogs';form.requestSubmit();await new Promise(r=>setTimeout(r,30));input.value='example.org';form.requestSubmit();await new Promise(r=>setTimeout(r,30));input.value='javascript:alert(1)';form.requestSubmit();await new Promise(r=>setTimeout(r,30));return calls.filter(c=>c.path==='/open').map(c=>c.body.url)})()`);
  assert.deepEqual(searchInput,['https://www.google.com/search?q=quiet%20cats%20%26%20dogs','example.org','javascript:alert(1)'],'searches are encoded for Google while addresses and unsafe schemes go to the Mac URL validator');
  const typingRow=await evaluate(`(()=>{closeSheet();document.querySelector('#keyboard-open').click();const row=document.querySelector('#text-form .typing-row'),input=row.querySelector('#text').getBoundingClientRect(),button=row.querySelector('button').getBoundingClientRect();const result={layout:getComputedStyle(row).display,beside:input.width>0&&button.width>=44&&button.left>=input.right&&Math.abs(button.top-input.top)<8};closeSheet();document.querySelector('#shortcuts-open').click();return result})()`);
  assert.deepEqual(typingRow,{layout:'flex',beside:true},'typing send arrow is beside the field');

  const features=await evaluate(`(async()=>{
    calls.length=0;const sleep=ms=>new Promise(r=>setTimeout(r,ms));
    document.querySelector('#url').value='https://example.org';document.querySelector('#open-form').requestSubmit();await sleep(10);
    document.querySelector('#shortcut-name').value='Example';document.querySelector('#shortcut-value').value='https://example.org';document.querySelector('#shortcut-form').requestSubmit();await sleep(20);
    closeSheet();document.querySelector('#display').dispatchEvent(new Event('change',{bubbles:true}));await sleep(20);
    document.querySelector('[data-mod="command"]').click();document.querySelector('#text').value='a';document.querySelector('#text-form').requestSubmit();await sleep(10);
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
  assert.equal(unpairedHelp.help,true);assert.equal(unpairedHelp.pairInert,true);assert.equal(unpairedHelp.pairRestored,true);assert.match(unpairedHelp.summary,/App version: Unavailable/);assert.match(unpairedHelp.summary,/Connect to the Mac/);assert.match(unpairedHelp.summary,/Signing: Unknown/);
  console.log('PASS gestures, drag release, heartbeat, UI actions, pairing, serial transport and locked-session wake');
}
(async()=>{try{await main()}catch(e){console.error(e);process.exitCode=1}finally{
  if(closeBrowser&&child?.exitCode===null&&child?.signalCode===null){try{await closeBrowser()}catch{};await Promise.race([new Promise(r=>child.once('exit',r)),wait(2000)])}
  if(ws)ws.close();if(child&&child.exitCode===null&&child.signalCode===null){child.kill('SIGTERM');await Promise.race([new Promise(r=>child.once('exit',r)),wait(2000)]);if(child.exitCode===null&&child.signalCode===null){child.kill('SIGKILL');await new Promise(r=>child.once('exit',r))}}
  await new Promise(r=>server.close(r));await fs.promises.rm(profile,{recursive:true,force:true,maxRetries:20,retryDelay:150});
}})();
