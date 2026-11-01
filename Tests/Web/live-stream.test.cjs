// Real page -> real native fixture. No user browser profile or input APIs are used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const browser = [process.env.BROWSER_BIN, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser', '/usr/bin/google-chrome', '/usr/bin/chromium']
  .find(p => p && fs.existsSync(p));
if (!browser || !globalThis.WebSocket) process.exit(77);
const port = Number(process.env.SOFA_TEST_PORT), token = process.env.SOFA_TEST_TOKEN;
if (!Number.isInteger(port) || port < 1 || port > 65535 || !token) {
  console.error('Native fixture port, token and Node 22+ are required.');
  process.exit(1);
}
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const profile = fs.mkdtempSync(path.join(process.env.SOFA_TEST_TMP || os.tmpdir(), 'sofa-live-web-'));
fs.chmodSync(profile, 0o700);
let child, socket, closeBrowser;
const sent = [], acknowledgements = [], httpCommands = [];
async function main() {
  child = spawn(browser, ['--headless=new', '--disable-gpu', '--no-first-run', '--disable-background-networking',
    '--remote-debugging-address=127.0.0.1', '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'],
    {stdio:['ignore','ignore','pipe']});
  const debugPort = await new Promise((resolve, reject) => {
    let output = '';
    const timer = setTimeout(() => reject(Error('Browser startup timed out')), 15000);
    child.once('error', () => { clearTimeout(timer); reject(Error('Browser startup failed')); });
    child.once('exit', () => { clearTimeout(timer); reject(Error('Browser exited during startup')); });
    child.stderr.on('data', part => {
      output += part;
      const match = output.match(/DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)\//);
      if (match) { clearTimeout(timer); resolve(match[1]); }
    });
  });
  const tab = await (await fetch(`http://127.0.0.1:${debugPort}/json/new?about:blank`, {method:'PUT'})).json();
  socket = new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.onopen=resolve; socket.onerror=()=>reject(Error('DevTools connection failed')); });
  let id = 0;
  const pending = new Map();
  socket.onmessage = event => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); return; }
    if (msg.method === 'Network.requestWillBeSent') {
      const url = new URL(msg.params.request.url);
      if (url.pathname === '/command') httpCommands.push(url.pathname);
    }
    if (msg.method === 'Network.webSocketFrameSent' || msg.method === 'Network.webSocketFrameReceived') {
      try {
        const frame = JSON.parse(msg.params.response.payloadData);
        if (Number.isInteger(frame.id)) {
          if (msg.method.endsWith('Sent') && frame.body) sent.push({id:frame.id,body:frame.body});
          else if (msg.method.endsWith('Received')) acknowledgements.push({id:frame.id,ok:frame.ok});
        }
      } catch {} // Ignore non-JSON DevTools frames.
    }
  };
  const cdp = (method, params={}) => new Promise((resolve,reject) => {
    const n=++id, timer=setTimeout(()=>{pending.delete(n);reject(Error(`${method} timed out`));},10000);
    pending.set(n, result=>{clearTimeout(timer);result.error ? reject(Error(`${method} failed`)) : resolve(result.result)});
    socket.send(JSON.stringify({id:n,method,params}));
  });
  closeBrowser=()=>cdp('Browser.close');
  const evaluate=async expression=>{
    const result=await cdp('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
    if (result.exceptionDetails) throw Error('Page evaluation failed');
    return result.result.value;
  };
  await cdp('Page.enable'); await cdp('Runtime.enable'); await cdp('Network.enable');
  await cdp('Page.addScriptToEvaluateOnNewDocument', {source:
    `localStorage.setItem('sofaKey',${JSON.stringify(token)}); Element.prototype.setPointerCapture=function(){};`});
  await cdp('Page.navigate',{url:`http://127.0.0.1:${port}/`});
  let ready=false;
  for (let i=0;i<100;i++) {
    try { ready=await evaluate('typeof streamState !== "undefined" && streamState === "ready"'); } catch {}
    if (ready) break;
    await wait(50);
  }
  assert.ok(ready,'native stream did not become ready within five seconds');
  const gesture=await evaluate(`(async()=>{
    const pad=document.querySelector('#pad'), dragButton=document.querySelector('#drag');
    const event=(type,x,y)=>pad.dispatchEvent(new PointerEvent(type,{pointerId:1,clientX:x,clientY:y,bubbles:true}));
    dragButton.click(); event('pointerdown',100,100);
    for(let i=1;i<=90;i++) { await new Promise(r=>setTimeout(r,16)); event('pointermove',100+i,100+Math.round(8*Math.sin(i/8))); }
    event('pointerup',190,100+Math.round(8*Math.sin(90/8))); dragButton.click();
    return true;
  })()`);
  assert.equal(gesture,true);
  let drained=false;
  for(let i=0;i<100;i++) {
    drained=await evaluate('streamState === "ready" && queue.length === 0 && pending.size === 0 && !active');
    if(drained) break;
    await wait(50);
  }
  assert.ok(drained,'input stream did not drain within five seconds');
  await wait(100); // Allow DevTools frame events to catch up with the page.
  const acked = new Set(acknowledgements.filter(x=>x.ok===true).map(x=>x.id));
  const clicks=sent.filter(x=>x.body.type==='click').length;
  const starts=sent.filter(x=>x.body.type==='drag' && x.body.phase==='start').length;
  const ends=sent.filter(x=>x.body.type==='drag' && x.body.phase==='end').length;
  assert.equal(httpCommands.length,0,'input must not fall back to HTTP');
  assert.ok(sent.length>=40,'expected at least 40 streamed input commands');
  assert.equal(acked.size,sent.length,'all streamed commands must be acknowledged');
  assert.equal(clicks,0,'continuous drag must not produce a click');
  assert.equal(starts,1); assert.equal(ends,1);
  assert.ok(sent.every((item,i)=>i===0 || item.id>sent[i-1].id),'command IDs stay ordered');
  console.log(JSON.stringify({streamReady:true,httpCommands:httpCommands.length,commandsSent:sent.length,
    commandsAcknowledged:acked.size,clicksSent:clicks,dragStartSent:starts===1,dragEndSent:ends===1}));
}
(async()=>{
  try { await main(); } catch(e) { console.error(`Live stream test failed: ${e.message}`); process.exitCode=1; }
  finally {
    if(closeBrowser && child?.exitCode===null && child?.signalCode===null) {
      try { await closeBrowser(); } catch {}
      await Promise.race([new Promise(r=>child.once('exit',r)),wait(2000)]);
    }
    socket?.close();
    if(child && child.exitCode===null && child.signalCode===null) {
      child.kill('SIGTERM'); await Promise.race([new Promise(r=>child.once('exit',r)),wait(2000)]);
      if(child.exitCode===null && child.signalCode===null) { child.kill('SIGKILL'); await new Promise(r=>child.once('exit',r)); }
    }
    await fs.promises.rm(profile,{recursive:true,force:true,maxRetries:20,retryDelay:150});
  }
})();
