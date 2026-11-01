# Internal interface, v0.1

The Mac listener serves RemotePage.html at GET /. No CDN or third-party requests from the page.
GET /manifest.webmanifest, /icon.svg and /icon-{180,192,512}.png are public. All other GET/POST except POST /pair require `X-Sofa-Key: <64hex>`.
POST /pair JSON `{code,name}` => `{token,deviceID}`. Native pairing opens a 5min invitation; no caller-chosen role. All paired phones have desktop control. Native owner can revoke.
GET /state => `{name,accessibility,sharing,screenSleeping,sessionLocked,frontApp,displayID,displays:[{id,name}],shortcuts:[{id,name,kind}],keepAwake}`. `kind` is `website`, `app`, or `downloads`.
POST /command JSON:
- `{type:"move",dx,dy}` finite relative motion. Client single-flight/coalesced; max ±1,000 per packet.
- `{type:"click",button:"left"|"right",count:1|2}`
- `{type:"drag",phase:"start"|"move"|"end",dx?,dy?}` finite ±1,000; ensure end on pointercancel/hidden; native reset releases on stop/lock/disconnect timeout.
- `{type:"scroll",dx,dy}` finite ±300.
- `{type:"text",value:"..."}` max1000 chars; no passwords while session locked.
- `{type:"key",key:"enter"|"escape"|"backspace"|"delete"|"tab"|"space"|"up"|"down"|"left"|"right"|"a"..."z"|"0"..."9",modifiers:["command","control","option","shift"]}`
- `{type:"action",action:"playPause"|"previous"|"next"|"volumeUp"|"volumeDown"|"mute"|"fullscreen"|"appSwitcher"|"spotlight"|"showDesktop"|"downloads"|"lock"|"screenOff"|"screenOn"|"moveWindow"}`. Lock must require deliberate confirmation on phone. Wake is not unlock. Commands while sessionLocked are restricted to screenOn; no generic typing/login injection.
POST /display `{id}` sets preferred connected display and moves pointer there, does not move window. `moveWindow` explicitly moves current foreground window to selected display, preserving native fullscreen where possible.
POST /open `{url}` HTTP(S) only; opens in installed Brave, otherwise user's default browser.
POST /launch `{id}` runs a saved shortcut. No shell execution API.
POST /shortcuts/add `{name,url}` OR `{name,bundleID}` app must be installed. Append; max24.
POST /shortcuts/move `{id,offset:-1|1}`; POST /shortcuts/remove `{id}`; persist order.
GET /devices => `[{id,name,current}]`; POST /devices/revoke `{id}`.
POST /settings `{keepAwake:Bool}`; only prevent idle SYSTEM sleep, never display sleep.
All mutations return `{ok:true}` or non-2xx JSON `{error:"helpful message"}`. Request deadlines9sec; no mutation replay. No CORS, no cache. Show direct HTTP/trusted network notice on pairing. Tailscale IP optional alternative via native QR links.
