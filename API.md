# Internal interface, v0.1

The Mac listener serves RemotePage.html at GET /. No CDN or third-party requests from the page.
GET /manifest.webmanifest, /icon.svg and /icon-{180,192,512}.png are public. All other GET/POST except POST /pair and the authenticated WebSocket upgrade flow require `X-Sofa-Key: <64hex>`.
POST /pair JSON `{code,name}` => `{token,deviceID}`. Native pairing opens a 5min invitation; no caller-chosen role. All paired phones have desktop control. Native owner can revoke.
GET /state => `{name,accessibility,sharing,screenSleeping,sessionLocked,frontApp,displayID,displays:[{id,name}],shortcuts:[{id,name,kind}],keepAwake}`. `kind` is `website`, `app`, or `downloads`.
POST /command JSON:
- `{type:"move",dx,dy}` finite relative motion. Client single-flight/coalesced; max ±300 per packet.
- `{type:"click",button:"left"|"right",count:1|2}`
- `{type:"drag",phase:"start"|"move"|"end",dx?,dy?}`; ensure end on pointercancel/hidden; native reset releases on stop/lock/disconnect timeout.
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

## Ordered input stream

The same HTTP listener accepts a WebSocket upgrade at `GET /input`, protocol `sofa.v1`. Host/private-peer checks and a matching HTTP Origin are required; credentials never appear in the URL. Within five seconds send JSON `{type:"auth",token}` using an existing paired-device secret. A successful handshake replies `{type:"ready"}`.

Send `{id,body}` with a strictly increasing positive safe-integer id and an ordinary `/command` body. Replies are `{id,ok:true}` or `{id,ok:false,error}`. The server authenticates/rate-limits every command and processes commands sequentially, including asynchronous window moves. The client can send up to four outstanding commands so motion does not wait for each acknowledgement, while preserving stream order and a roughly 60 Hz send limit. Ambiguous commands are never replayed through HTTP.

Browser heartbeat `{type:"ping"}` receives `{type:"pong"}` every three seconds while visible. Frames must be masked, final UTF-8 text, at most 4 KiB; standard protocol ping/pong/close control frames are supported. Fragmented/binary/invalid frames are rejected. Buffers are capped at 64 KiB/32 queued frames; the existing sixteen-client cap covers HTTP and WebSocket together. Authentication expires after five seconds without a valid first message, and authenticated idle/command deadlines remain nine seconds.

Disconnect, revocation and Stop sharing cancel pending work and release held input. A browser whose first stream connection is unavailable can retain HTTP compatibility control. Losing an established stream rejects pending input before reconnecting; it never silently repeats it. Oversized serialized text remains in the phone field with a request to send smaller parts.
