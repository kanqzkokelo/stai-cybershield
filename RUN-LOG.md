# STAI Cybershield - run log

A running record of what works and what breaks, so a failure is never a mystery.
Every entry is something we actually saw, not something we assumed.

- **OK** = observed working, with the evidence next to it
- **FAIL** = observed broken, with the cause and the fix that was made
- **OPEN** = known, not yet fixed or not verifiable from here

---

## 1. Where it stands

Verified on 19 Oct 2026, ~12:35 PM, on a Cloud Shell VM in `europe-west4`.

| # | What | Evidence |
|---|------|----------|
| 1 | Locked browser runs in Cloud Shell | `docker ps` -> `cybershield: Up (healthy)`, port `6080->80` |
| 2 | It shows one hub page, no desktop | screenshot `hub-page.png` - maximised Firefox with its own toolbar on the hub, no taskbar, no icons |
| 3 | No taskbar, no desktop icons, no file manager | `supervisorctl status` has no `lxpanel` / `pcmanfm`; 8 of 8 programs `RUNNING` |
| 4 | The parent's website list reaches the machine | `~/cybershield/policy.json` = `{"mode":"allow","sites":["youtube.com","google.com"]}` |
| 5 | That list becomes a real Firefox policy | `policies.json` has those domains in `WebsiteFilter.Exceptions` |
| 6 | The app's own Launch code works, unmodified | ran the exact worker block out of `Start-Remote`: 43 s, returned `CYBERSHIELD_HOST=cs-<session-id>` |
| 7 | Firefox really is Firefox | build log: `RUN /usr/bin/firefox --version` -> `Mozilla Firefox 97.0` |
| 8 | The image builds from scratch | `cybershield-demo:latest`, 2.05 GB |
| 9 | The hub page matches the list, automatically | with `google.com, youtube.com` the page lists exactly those two; with wikipedia/khanacademy it lists those two instead |
| 10 | Reset survives being run repeatedly | two setups back to back -> `Up (healthy)`, all 8 programs `RUNNING` |
| 11 | The app writes a log of everything it does | `cybershield.log` next to the `.exe`, entries below |

Session URL (must be opened while signed in as the Cloud Shell account - it is
account-locked, see OPEN-1):

```
https://6080-cs-<session-id>.<region>.cloudshell.dev/?quality=2&compression=1&scalingMode=scale&clipToWindow=true&dotCursor=true
```

---

## 2. OK - things that work

### OK-1 The whole remote round trip (this was the big one)
`gcloud cloud-shell ssh` from the app now runs a command on the Cloud Shell VM
and gets the output back. See FAIL-1 for what it took.

### OK-2 Chunked upload and byte-exact verification
`setup.sh` is uploaded as four base64 chunks, reassembled with `base64 -d`, then
compared by md5 against the local file:

```
5f30209cced39ab0f4133babbcfcc31f  /home/<cloud-shell-user>/cybershield/setup.sh
10392 bytes
```

Both matched. This is how we know the machine is running *our* script and not a
half-written file.

### OK-3 The healthcheck now passes
`docker ps` reports `Up (healthy)`. Before, it sat at `unhealthy` forever - see FAIL-3.

### OK-4 A screenshot of the real screen
There is no `scrot`, `import`, `xwd` or `convert` in the image, but `ffmpeg` is
there, so the screen can be captured without installing anything:

```
docker exec cybershield ffmpeg -f x11grab -video_size 1280x720 -i :1 -frames:v 1 -y /tmp/shot.png
```

That is how `hub-page.png` was produced. It is the only way to see what the
locked browser is really showing without logging into the noVNC page.

### OK-5 The remote command runs exactly once
Worth checking, because a duplicated remote command would double a policy write:
`rm -f /tmp/c; echo X >> /tmp/c; wc -l < /tmp/c` -> `1`.

### OK-6 Turn off session, and Launch brings it back
Ran the button's exact remote command against the live session:

```
docker stop cybershield >/dev/null 2>&1; ...; docker inspect -f {{.State.Status}} cybershield
-> exited
CYBERSHIELD_OFF=ok
CYBERSHIELD_OFF=ok
```

Then a normal Launch: the checksum probe skipped the install, the container came
back `(healthy)` and both `CYBERSHIELD_HOST=...` markers were returned. Off and
back on with no extra steps.

---

## 3. FAIL - what went wrong, and the fix

### FAIL-1 Launch hung forever on "Listening on local port [N]."  **(the main bug)**
**Symptom.** Clicking Launch in the app did nothing visible, forever. The last
line on screen was gcloud saying it was listening on a local port.

**Cause.** gcloud does not speak SSH itself on Windows; it drives PuTTY's
`plink.exe` through a local websocket tunnel, and it makes three connection
attempts. Each attempt opens a **new random local port**, so PuTTY - which
caches host keys per `host:port` - sees a brand new server every time and asks
the "Store key in cache? (y/n)" question. That question goes to the console and
is read from stdin. With no console (which is exactly how a captured,
windowless call behaves) it blocks there for good.

**Fix.** Two things:
1. pass `--ssh-flag="-legacy-stdio-prompts"` so that question moves onto the
   normal streams where we can see and answer it;
2. keep writing `y` to the process's stdin **until it exits** - a single `y` is
   swallowed by attempt 1, and attempt 2 then sees EOF and gives up with
   "Connection abandoned."

Attempt 1 always fails anyway (`No supported authentication methods available`),
attempt 2 over the tunnel's port 2222 is the one that succeeds.

Implemented in `cybershield-launcher.ps1` -> `Start-Remote`, which now runs
gcloud through a one-line `.cmd` shim with a redirected stdin/stdout/stderr and
feeds it `y` every 200 ms while reading the output line by line into the tracker.

### FAIL-2 "How do you want to open this file?" when Launching
**Cause.** `Find-Gcloud` returned `gcloud.ps1`. The SDK's `bin` folder ships
`gcloud`, `gcloud.cmd` **and** `gcloud.ps1`, and PowerShell's `Get-Command`
prefers the `.ps1`. Handing a `.ps1` to `Start-Process` goes to the file
association, and this PC has no `.ps1` association registered.

**Fix.** `Find-Gcloud` now prefers `gcloud.cmd` / `gcloud.exe` from PATH, then
from the known install folders, and never returns a `.ps1`.

**Related.** Double-clicking any `.ps1` on this PC shows that same dialog. Use
`Cybershield.exe`, or `Rebuild Cybershield.cmd` / `Launch Cybershield.cmd`.

### FAIL-3 Container reported `unhealthy` forever, so every Launch waited out the whole health timeout
**Cause.** The desktop's taskbar (`lxpanel`) was disabled by pointing its
supervisor command at `/bin/true`. That makes it exit immediately on every
start, so supervisord parked it in a `FATAL` back-off loop. The image's own
healthcheck (`curl --fail http://127.0.0.1:6079/api/health`) runs
`supervisorctl status`, which exits 3 as soon as any program is not `RUNNING`,
so `/api/health` returned 500 and the container could never be healthy.

**Fix.** `lxpanel` and `pcmanfm` are removed from `supervisord.conf` outright
(their `[program:...]` sections and their names in the `[group:x]` list) instead
of being neutered. Nothing to fail means nothing to report as failed - and as a
bonus the session is now browser-only, which is what was actually wanted.

### FAIL-4 Cloud Shell recycled the VM in the middle of the work
**Symptom.** Everything vanished: different hostname, different user, empty
home, no Docker images.

**Cause.** Cloud Shell recycles sessions. The Cloud Shell username changed and
`$HOME` was wiped, taking the uploaded `setup.sh` and the built image with it.

**Fix.** Nothing to fix in code - it is how Cloud Shell behaves. Just re-upload
and re-run `setup.sh` (~6 minutes: mostly the 2 GB base image pull). Worth
remembering for the demo: **if the session looks empty, it was recycled, not
broken.** Also the reason `Launch` falls back to `bash setup.sh` when the
container is missing.

### FAIL-5 The `.exe` could not be rebuilt while the app was open
**Cause.** Windows locks a running executable, so the build's `Remove-Item` failed.

**Fix.** Build to a side file and swap it in after closing the app:

```
build-exe.ps1 -OutFile Cybershield.new.exe
```

then close the app and copy over `Cybershield.exe`.

### FAIL-6 Writing `setup.sh` while running `setup.sh` destroys it
**Cause.** The outer installer writes the inner script to the very path bash is
executing, so the heredoc truncates the file mid-run.

**Fix.** Extract to a different filename (the outer installer is meant to be run
as `install.sh`, and it writes `setup.sh`). Both files exist for that reason.

### FAIL-7 Screenshot came back empty over the wire
**Symptom.** `base64 -w 0 /tmp/shot.png` returned nothing on stdout, twice, even
though the file existed on the machine.

**Workaround used.** Capture and encode in the **same** remote command, separating
the payload with a marker line, and wrap the base64 (not `-w 0`):

```
docker exec cybershield ffmpeg ... -y /tmp/s.png; echo SEPB64; docker exec cybershield base64 /tmp/s.png; echo SEPEND
```

**Still OPEN** as to why a 24 KB single line does not survive `plink`'s stdout
here. The wrapped form is proven, so the helper uses that. **This is the one to
suspect first if a future screenshot/upload looks empty.**

**RESOLVED** (19 Oct, evening) - it was the reader, not plink: the last line(s)
of output are lost when the ssh process exits, and a single-line base64 payload
*is* one line. See FAIL-10. After the drain fix the single-line form works, and
`hub-page.png` was captured that way.

### FAIL-8 `docker restart` left the X display dead  **(FIXED)**
**Symptom.** After the app restarted the container, the X programs came up bad:

```
x:xvfb    FATAL     Exited too quickly
x:wm      FATAL     Exited too quickly
x:x11vnc  STARTING
```

The screen went blank, so the browser had nothing to draw on.

**Cause.** `docker restart` keeps the container's filesystem, so
`/tmp/.X1-lock` and `/tmp/.X11-unix/X1` survive from the previous run. Xvfb then
refuses to start - the log says it plainly:

```
Fatal server error:
(EE) Server is already active for display 1
     If this server is no longer running, remove /tmp/.X1-lock
```

That happened on **every Reset**, because Reset restarts the container.

**Fix.** `/usr/local/bin/xvfb.sh` now removes the stale lock and socket before
exec'ing Xvfb, so a restart is always a clean start. Proven by running the setup
twice back to back: `Up (healthy)` and 8 of 8 programs `RUNNING`.

Also, Launch and Reset now run `setup.sh` (remove + re-create the container)
instead of `docker restart`, which sidesteps stale state in general and
regenerates the policy and hub page on the way through.

### FAIL-9 The transport fix could not be tested from the UI without a click
**Symptom.** No way to prove `Start-Remote` works short of clicking Launch and
watching, which is a bad way to debug a 45-second network operation.

**Fix.** The worker block was pulled out of the file with the PowerShell parser
and run directly, with the app's own command template and a real policy blob:

```powershell
$ast  = [System.Management.Automation.Language.Parser]::ParseFile($src, [ref]$null, [ref]$null)
$hit  = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true) |
        Where-Object { $_.Extent.Text -match 'param\(\s*\$gcloudExe' } | Select-Object -First 1
$body = [scriptblock]::Create($hit.Extent.Text.Trim().Substring(1, $hit.Extent.Text.Trim().Length - 2))
& $body $gcloud $cmd $prog
```

Result: 43 s, `CYBERSHIELD_HOST=cs-<session-id>`. The UI path is proven, not
assumed. Useful trick for the next time something only fails behind a button.

### FAIL-10 The last line of every reply could vanish - markers, screenshots, all of it  **(the silent one)**
**Symptom.** Intermittently `CYBERSHIELD_RESET=ok` never appeared, a Launch that
had just returned a working URL reported "no CYBERSHIELD_HOST in the reply", and
the base64 screenshot came back empty (FAIL-7). The work always happened; the
report did not arrive.

**Cause.** `Invoke-RemoteOnce` reads stdout line by line (`ReadLineAsync` +
`Wait(200)`) and stops the moment the process exits. A line that was *mid-read*
at that moment sits in a pending task and is never appended, and a later
`ReadToEnd` cannot recover it - the pipe is already closed. Which line is lost
depends on timing; it is often the final marker.

**Proof.** Same 3-line command, marker placed after one long line, 3 runs each:
old reader lost the marker **3 of 3** times; with the drain fix, **0 of 3**.
Earlier, a marker echo missing from every run also turned out to be this bug,
not a failed command.

**Fix.** Before `ReadToEnd`, every pending stdout/stderr `ReadLineAsync` task is
awaited (`Wait(2000)`) and its line appended. Every app marker is also echoed
twice with a pause between copies, so one lost copy still leaves one.

### FAIL-11 Firefox was locked so hard it could not be navigated
**Symptom.** "All the buttons, ie back front searchbar nothing works." There
were literally no back/reload/address-bar controls in the session: the launcher
started Firefox with `--kiosk`, which hides the whole browser UI. The site list
was enforced, but the only way to move was clicking the links on the hub page.

**Cause.** Kiosk mode was chosen for the "nothing but the hub" look; it also
removes every way of navigating - including the ways the policy is supposed to
govern (typing a URL, back/forward, reload).

**Fix.** The session launcher (`firefox-session`) opens a normal Firefox window
and maximises it through openbox (`wmctrl`, installed in the image). The lock is
unchanged: allow mode still blocks `<all_urls>` outside the list, so a typed URL
that is not allowed lands on the blocked-by-policy page. Verified on the live
session: screenshot shows title bar, tab, back/forward/reload and the address
bar at `localhost/start.html`.

### FAIL-12 The window *around* the session was a normal browser
**Symptom.** Even with an in-session toolbar, the PC window holding the session
is the PC's own browser - its address bar and back button act on the PC, not on
the locked browser, so the controls on screen are the wrong ones.

**Fix.** Launch opens the session in a chromeless app window (Edge or Chrome
`--app=<url>`): no address bar, no tabs, no back button on the outside. Falls
back to the default browser if neither is installed; the README says which
controls are the session's.

### FAIL-13 A fresh Cloud Shell could never start the session from the app
**Symptom.** Launch on a Cloud Shell with no `~/cybershield` failed with a pile
of "No such file or directory". The README's answer was "paste
`cloudshell-setup.sh` by hand first"; the app itself could not recover.

**Fix.** The app now carries the installer inside itself (base64), probes the
remote side, and when it is missing or stale uploads it in chunks, proves the
upload by md5, runs it (image build, minutes) and only then runs the request.
Proven end-to-end: `~/cybershield` was wiped on the live VM and the app's own
code rebuilt everything unattended - upload md5 matched, `INSTALL_EXIT=0`,
container `healthy`, session URL returned (~4.5 min).

### FAIL-14 A session-side update could never reach an existing Cloud Shell
**Symptom.** Fixing the session code (Dockerfile, launcher) changed nothing on
a machine that already had an older `~/cybershield`: the app only checked that
`setup.sh` *existed*, and the image build only ran when the image was missing.

**Fix.** Two checksums. The app compares `md5(setup.sh)` on Cloud Shell with the
copy it carries and updates whenever they differ. On the session side the image
build carries a label hashed from the Dockerfile + launcher, so a changed recipe
rebuilds. Exercised for real: the toolbar change rolled onto the live VM with no
manual steps.

### FAIL-15 The image build died on a dead apt source
**Symptom.** `failed to solve ... exit code: 100`; `install.log` showed
`E: The repository 'https://dl.google.com/linux/chrome/deb stable InRelease' is
not signed` (`NO_PUBKEY FD533C07C264648F`).

**Cause.** The base image ships a google-chrome apt source whose key is gone,
and `apt-get update` fails on it - taking the whole build with it.

**Fix.** `wmctrl` is installed only *after* the dead chrome source is removed,
in the same Dockerfile. Rebuild succeeded (`INSTALL_EXIT=0`), `/usr/bin/wmctrl`
present, window maximised.

### FAIL-16 The checksum probe broke gcloud's own argument parser
**Symptom.** `ERROR: (gcloud.cloud-shell.ssh) unrecognized arguments: -f1; else
echo none; ...` - one probe call in testing.

**Cause.** The Windows `cmd` shim under gcloud eats double quotes; `cut -d" "`
fell apart and `-f1` looked like a gcloud flag.

**Fix.** The probe uses no quotes and no pipes: plain `md5sum <file>`, parsed on
the PC side. Verified live: it returns `9bce501c...  /home/.../setup.sh` and the
launch skips straight to the policy push (~40 s).

---

## 4. OPEN - known, and not verifiable from here

### OPEN-1 The session page is locked to the Cloud Shell account
`https://6080-<host>/` redirects to a Google sign-in unless you are already
signed in as the Cloud Shell user. So the assistant cannot look at the live
session - only the account owner can, by opening the URL above while signed in.
This is Google's design, not something we can change.

### OPEN-2 The hub page is now generated, not hardcoded  **(FIXED)**
`start.html` used to be a static page with the four demo entries (wikipedia,
khanacademy, youtube, reddit) no matter what the parent chose. It is now written
by `write_policy.py` from the same list that produces `policies.json`, and the
container bind-mounts it, so the page cannot disagree with what is enforced.

Verified: with the list `google.com, youtube.com`, the page served from inside
the container lists exactly those two.

### OPEN-3 `localhost` is exempt in the policy
`http://localhost/*` and `127.0.0.1/*` have to be exceptions so the hub page
itself loads, but that also makes the image's file-browser service
(`fsweb`, port 8080) reachable from inside the locked browser. Tighten to the
exact hub path if this matters.

### OPEN-4 Only the allow list was proven, not the block list
The policy generator writes both, and the block-list branch was reviewed, but
only allow mode has been exercised end to end. Worth one demo run in block mode.

### OPEN-5 Cloud Shell limits (by design, not bugs)
Unavailable to under-18 accounts; 50 h/week quota; 12 h session cap; a session
is discarded after roughly 1 h idle. All acceptable for a demo, none fixable.

---

## 6. The app keeps its own log

Every action is appended to `cybershield.log`, next to the `.exe`:

```
2026-10-19 12:44:29  INFO   app start - 5.1.x on Microsoft Windows NT 10.0...
2026-10-19 12:44:30  INFO   gcloud found - C:\...\bin\gcloud.cmd
2026-10-19 12:44:31  INFO   CYBERSHIELD_AUTHCHECK started - Checking the sign-in
2026-10-19 12:44:32  INFO   Sign-in check OK - you@example.com
2026-10-19 12:45:02  INFO   Launch clicked - mode=allow sites=google.com,youtube.com
2026-10-19 12:45:40  INFO   Launch OK - 2 sites, url https://6080-...
```

Failures are recorded too, with the tail of what Cloud Shell actually replied, so
"it didn't work" becomes a specific line in a file:

```
2026-10-19 12:50:11  ERROR  Launch FAILED - no CYBERSHIELD_HOST in the reply
2026-10-19 12:50:11  ERROR  reply: ... Connection abandoned. / Tunnel stopped.
```

That file is the first thing to read after a failed demo. This document
(`RUN-LOG.md`) is the longer version: the causes, the fixes, and what is still
open.

---

## 7. How to re-check the whole thing in about a minute

From the app: click **Launch session**. It writes the policy, restarts the
container, waits for `healthy`, opens the browser and prints the URL.

From a terminal, if the app is suspect, these three commands tell you almost
everything:

```powershell
docker ps --filter name=cybershield          # up and healthy?
docker exec cybershield supervisorctl status # every program RUNNING?
docker exec cybershield ls -la /etc/firefox/policies/policies.json
```

And to actually see the screen:

```powershell
docker exec cybershield ffmpeg -f x11grab -video_size 1280x720 -i :1 -frames:v 1 -y /tmp/shot.png
```
