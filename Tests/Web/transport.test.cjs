// Exercise the real request wrapper without network access. Node 22+.
const assert = require('node:assert/strict'), fs = require('node:fs'), vm = require('node:vm');
const source = fs.readFileSync('Sources/SofaRemote/RemotePage.swift','utf8');
const start = source.indexOf('async function request('), end = source.indexOf('async function pair(', start);
assert.ok(start >= 0 && end > start);
let requests = [], resolveFetch, pairPrompts = 0; const saved = [];
const context = vm.createContext({ AbortController, Promise, Error, clearTimeout,
  setTimeout: (fn,ms) => setTimeout(fn,ms === 9000 ? 20 : ms),
  fetch: (path,options) => { requests.push({path,options}); return new Promise((resolve,reject)=>{
    resolveFetch=resolve; options.signal.addEventListener('abort',()=>reject(Error('aborted')),{once:true});
  }); },
  storage: { set: v => saved.push(v) }, showPair: () => pairPrompts++,
});
vm.runInContext("let key='old-key';" + source.slice(start,end),context);
const run = code => vm.runInContext(code,context);
(async()=>{
  const timed=run("request('/open',{url:'https://example.org'})");
  await assert.rejects(timed,/timed out|aborted/);
  assert.equal(requests.length,1,'timed-out POST is never replayed');
  assert.equal(requests[0].options.signal.aborted,true);
  assert.equal(requests[0].options.headers['X-Sofa-Key'],'old-key');
  const late=run("request('/state')");run("key='new-key'");
  resolveFetch({status:401});await assert.rejects(late,/unpaired/);
  assert.equal(run('key'),'new-key','late 401 cannot revoke a newly paired key');
  assert.equal(pairPrompts,0);
  const expired=run("request('/state')");resolveFetch({status:401});await assert.rejects(expired,/unpaired/);
  assert.equal(run('key'),'');assert.deepEqual(saved,['']);assert.equal(pairPrompts,1);
  console.log('PASS timeout, no POST replay, authorization and late-401 protection');
})().catch(e=>{console.error(e);process.exitCode=1});
