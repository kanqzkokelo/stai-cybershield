# STAI Cybershield — complete project brief

**What this document is for:** hand it to another AI or engineer and ask: *given where this project is, how should we progress?* It is written to be self-contained.

---

## 1. Snapshot

STAI Cybershield is a parental-control demo built for a judged demo day. A Windows desktop app lets a parent choose which websites are reachable. The actual browsing happens in a locked Firefox session running in Google Cloud Shell (free tier), inside Docker; the child's PC only displays it. There are two policy modes: **allow only these sites** (allowlist) and **allow everything except these** (blocklist). Nothing is installed on the child's machine.

**Current status:** working end-to-end, manually verified on a live Cloud Shell on 19 Oct 2026, pushed to a public GitHub repo. Demo readiness is close: the remaining critical gaps are a full rehearsal, a backup recording, and visual proof of block mode (details in §7).

---

## 2. The idea and the pitch

A parent opens `Cybershield.exe`, types `khanacademy.org`, clicks **Add**, chooses "Allow only these sites", and clicks **Launch session**. A maximized Firefox appears inside a chromeless window. Only the listed sites load; anything else gets Firefox's "blocked by your organization" page. The parent can add a site, click **Reset session**, and it becomes reachable about half a minute later. **Turn off session** stops it and the screen goes dead.

The selling point: the browser and the policy live in the cloud, so the child's PC has nothing installed to uninstall, and the lock is enforced by browser policy rather than by hiding buttons.

The 60-second demo flow (from `DEMO-DAY.md`):

1. Open the app: "The parent decides what is reachable — and the browser lives in the cloud."
2. **Launch session** → the locked Firefox appears; the hub lists exactly the allowed sites.
3. Type an off-list site (`reddit.com`) → blocked-by-policy page. "The lock is real policy, not hidden buttons."
4. Add `nasa.gov` → **Add** → **Reset session** → the hub shows it; open it. "Rules change while it runs — no reinstall."
5. **Turn off session** → screen goes dead. "And it ends when I say so."

Honesty line for judges: the preview URL is locked to the owner's Google account, so only the owner can open the session; it is presented on the owner's screen.

---

## 3. Architecture

```text
Windows PC                              Google Cloud Shell (free tier)
┌───────────────────────────┐           ┌──────────────────────────────────────┐
│ Cybershield.exe           │  gcloud   │ ~/cybershield/                       │
│ PowerShell 5.1 + WinForms │  cloud-   │  setup.sh, write_policy.py,          │
│ site list / mode          │  shell    │  policy.json, policies.json,         │
│ Launch / Reset / Off      │  ssh      │  start.html, firefox-session, image/ │
│ progress bar + log        │──────────>│                                      │
│                           │           │ Docker container `cybershield`       │
│ Edge/Chrome `--app` window│<──────────│  6080 -> 80                          │
│ (viewer only)             │  preview  │  Xvfb + openbox + x11vnc + noVNC     │
└───────────────────────────┘           │  Firefox, maximized, policy-bound    │
                                        └──────────────────────────────────────┘
```

**Components**

- **Windows app** — `cybershield-launcher.ps1`, ~1,050 lines of PowerShell 5.1 + WinForms, compiled to `Cybershield.exe` with `ps2exe`. It installs the Google Cloud SDK itself (winget, or Google's installer), signs in with `gcloud auth login` in a visible cmd window, stores the site list in `cybershield-sites.json`, logs every action to `cybershield.log`, and shows a live progress bar (phase, bytes, speed, elapsed time). Buttons: **Launch session**, **Reset session**, **Turn off session**, and a top-right **Install Google CLI / Sign in to Google / Sign in again**.
- **Cloud Shell installer** — `cloudshell-setup.sh`, a self-contained bash script. It writes `~/cybershield/setup.sh`, a Python policy generator, the hub page, and a Firefox session wrapper; builds a Docker image `cybershield-demo` from `wenoptics/ubuntu-desktop-novnc:latest`; runs container `cybershield` with `-p 6080:80`; bind-mounts the generated `policies.json` and `start.html`; and installs `~/.customize_environment` so a fresh Cloud Shell VM rebuilds and starts the session automatically.
- **Container** — Ubuntu desktop + noVNC base. Supervisor runs Xvfb, openbox, x11vnc, noVNC, and the Firefox session. `lxpanel` and `pcmanfm` are removed (no taskbar, no desktop icons); Chrome is removed; `wmctrl` is installed so Firefox can be maximized. Firefox is a normal window, **not kiosk**: back/forward/reload and the address bar exist, and the Firefox policy is what enforces the lock.
- **Policy generator** — `write_policy.py`, embedded in `setup.sh`. It converts the parent's `{mode, sites}` into Firefox enterprise `policies.json`, and regenerates the hub page from the same list so the page cannot disagree with what is enforced.
- **Transport** — `gcloud cloud-shell ssh` on Windows drives PuTTY's `plink` through a local tunnel. The app works around plink's per-port host-key prompt by using `--ssh-flag="-legacy-stdio-prompts"` and continuously writing `y` to stdin until the process exits. It runs gcloud through a one-line `.cmd` shim so cmd.exe does not mangle quotes, reads output line by line into the progress UI, and drains pending `ReadLineAsync` tasks before `ReadToEnd`, because the final line (often the success marker) was intermittently being lost.
- **Self-provisioning** — the app carries a base64 copy of `cloudshell-setup.sh` inside itself. Before every Launch/Reset it probes `md5(setup.sh)` on Cloud Shell. If the file is missing or differs, it uploads the installer in ~4.7 KB base64 chunks, decodes it, verifies the upload byte-for-byte by md5, runs it (first run ~4.5 min, ~2 GB image pull), and only then runs the requested command. A brand-new Cloud Shell, or a VM whose `$HOME` was wiped, therefore needs no manual setup.
- **Viewer** — opens the preview URL in `msedge.exe --app=<url>` or `chrome.exe --app=<url>` (no tabs, no address bar, no back button on the outside). Falls back to the default browser if neither exists.

---

## 4. Launch sequence end to end

1. The app serializes `{mode, sites}` to JSON and base64-encodes it.
2. `Start-Remote` probes the remote installer and self-heals it if missing or stale.
3. `python3 write_policy.py <base64>` writes `policy.json`, then regenerates `policies.json` and `start.html`.
4. `bash setup.sh` rebuilds the image only if the Dockerfile/session wrapper hash changed; `docker rm -f` + `docker run` with the bind mounts; waits for the container to become `healthy`.
5. The remote command echoes `CYBERSHIELD_HOST=<WEB_HOST>` twice. The app regexes it, builds `https://6080-<WEB_HOST>/?quality=2&compression=1&scalingMode=scale&clipToWindow=true&dotCursor=true`, and opens it in the chromeless app window.
6. **Reset** does steps 3–5 but returns `CYBERSHIELD_RESET=ok`; **Turn off** only runs `docker stop cybershield` and returns `CYBERSHIELD_OFF=ok` (it skips the installer probe entirely).

Warm timings from the live log: Launch 56–64 s; Turn off ~15 s. First cold build ~4.5 min.

---

## 5. The policy model

**Allow mode**

- `WebsiteFilter.Block = ["<all_urls>"]`
- `WebsiteFilter.Exceptions` contains, for each site: `http://<site>/*`, `https://<site>/*`, and the `www.`/subdomain variants (`*.example.com`), plus `http://localhost/*`, `https://localhost/*`, `http://127.0.0.1/*`, `https://127.0.0.1/*` so the hub page itself loads.

**Block mode**

- `WebsiteFilter.Block` contains the same site patterns.
- `WebsiteFilter.Exceptions` contains only the localhost entries.

Both modes also set hardening policies: `BlockAboutConfig`, `DisableDeveloperTools`, `DisablePrivateBrowsing`, `DisableFirefoxAccounts`, `DisableFirefoxStudies`, `DisablePocket`, `DisableTelemetry`, `DisableFeedbackCommands`, `OfferToSaveLogins=false`, `PasswordManagerEnabled=false`, `SearchSuggestEnabled=false`, auto-update off, telemetry off, bookmark toolbar off. The hub page is generated from the same list, so it always matches enforcement.

One edge case: the block-mode hub always renders a single "Browse google.com" card. If the parent has blocked `google.com`, that card is a dead link. Cosmetic, but worth knowing.

---

## 6. Verified state (19 Oct 2026, live Cloud Shell, `europe-west4`)

- Container `cybershield` is `Up (healthy)`, port `6080->80`; 8 of 8 supervisor programs `RUNNING`; no taskbar or desktop.
- Firefox 97, normal toolbar, maximized.
- The parent's list reaches the VM; the generated `policies.json` matches it; the hub page matches it.
- Real click-through, first try:
  - 21:47 Launch with 2 sites → 21:48 OK (64 s)
  - 21:57 Turn off → OK (15 s)
  - 22:01 Launch with 4 sites → 22:01 OK (56 s)
  - 22:03 Turn off → OK (15 s)
- Allow-mode blocking proven visually: typing `youtube.com` into the session with an allowlist that excludes it returns Firefox's "Blocked Page — your organization has blocked access" (`blocked-page.png`). Live session screenshot: `hub-page.png`.
- Self-provisioning proven for real: `~/cybershield` was wiped on the live VM, and the app's own code re-uploaded it, matched the md5, rebuilt everything unattended, and returned a working URL (~4.5 min).
- Reset survived repeated runs; the stale Xvfb lock problem was fixed.
- Block mode was exercised at policy level end-to-end (`sites=1`, `mode=block`, the domain landed in `policies.json`, Reset came back clean), but there is **no screenshot** of the block-mode blocked page yet.
- Public repo: `github.com/kanqzkokelo/stai-cybershield`, 3 commits, latest `dfd8ef0 "Demo-day readiness..."`. Executable, screenshots, and docs are committed.
- `RUN-LOG.md` documents 17 real failures, each with cause, fix, and evidence. It is deliberately part of the engineering pitch.

Verification environment: Windows 10, PowerShell 5.1, Cloud SDK installed under `C:\Program Files (x86)\...`, signed in with a personal Gmail (credentials/account redacted here), Cloud Shell free tier. The preview URL is account-locked.

---

## 7. Gaps and risks, in priority order

**Demo-critical**

1. **No rehearsal of the scripted 60-second demo.** Real manual use passed; the exact runbook in `DEMO-DAY.md §2` has not been run start-to-finish.
2. **No backup recording.** A Wi-Fi or Cloud Shell failure would end the demo. Record one clean 2-minute run.
3. **Block mode has no visual proof.** Policy-level only. One live block-mode Reset + screenshot closes it.
4. **Cold start is ~4.5 min.** Pre-warm shortly before presenting. Cloud Shell discards idle VMs after ~1 h and has a 12 h session cap.
5. **Quota.** Cloud Shell free tier: 50 h/week; unavailable to under-18 accounts. Check the quota before the day.
6. **Judges cannot open the preview URL**; it is locked to the Cloud Shell account. Present on the owner's screen and say so explicitly.
7. **Unsigned exe / SmartScreen / antivirus** on a foreign laptop. Fallbacks: More info → Run anyway, or `Launch Cybershield.cmd` (runs the source, no SmartScreen). Both need internet.

**Engineering / housekeeping**

8. **FAIL-17 cosmetic error:** `Remove-Item ... ItemNotFoundException` can appear in a reply tail after a successful Launch (seen at 21:48 in `cybershield.log`). Guard the cleanup with `-ErrorAction SilentlyContinue`, then rebuild the exe.
9. **Stale embedded installer hazard:** the base64 of `cloudshell-setup.sh` is pasted into the PS1 by hand. If you edit the shell script and forget to regenerate the base64, the app will overwrite a newer remote installation with the old embedded version. Automate this in `build-exe.ps1` (or generate it at build time).
10. **The localhost exemption exposes `fsweb` on port 8080** inside the locked browser. Tighten the exception to the exact hub path if it matters.
11. **Docs drift:** `DEMO-DAY.md` row 8 still says the README lacks screenshots/diagram, but the README now has both. Row statuses need a pass; `DEMO-DAY.md` is the working checklist.
12. **No LICENSE** (MIT suggested; owner's call).
13. `.opencode/` (agent goal state) is untracked and not in `.gitignore`; decide whether to ignore it.
14. `Cybershield.exe` is a committed binary. Any source change requires a rebuild, and Windows locks a running exe (`build-exe.ps1 -OutFile Cybershield.new.exe`, close the app, swap).
15. **No automated tests, linting, or CI.** PowerShell/bash are verified by running the app and the live session.

---

## 8. Production-readiness gaps (beyond the demo)

This is demo-grade, not a product:

- Single user, single Cloud Shell, single container; no accounts, tenancy, roles, or admin console.
- No persistence beyond the Cloud Shell home directory; VM recycling and quotas are Google's behavior, not controlled.
- The preview URL is account-locked; there is no way to hand access to a parent or judge.
- No usage reports, history, schedules, per-child profiles, or audit trail — only a local app log.
- No local/offline mode; if Cloud Shell is unavailable, nothing works (a local Docker fallback exists but is not bundled or automated).
- Security relies on Firefox enterprise policy and the child not reaching the host; the outer viewer browser is not sandboxed by the app.
- The installer is unsigned; SmartScreen/UAC create friction.
- Windows-only launcher; Cloud Shell-only backend (no AWS/Azure/self-hosted option).
- No graceful concurrency handling (two launches at once), no cancellation, limited retry/backoff.

---

## 9. Constraints and gotchas worth knowing

- Never double-click a `.ps1` on this machine (no file association). Use the `.exe` or the `.cmd` wrappers.
- `.sh` files must stay LF; `.gitattributes` enforces this. CRLF breaks Cloud Shell with `$'\r': command not found`.
- The installer writes `setup.sh` from a heredoc. Run the outer file as `install.sh`, not `setup.sh`, or bash truncates the file it is executing.
- Firefox reads its policy at startup, so list changes only apply on Launch/Reset.
- A Docker restart keeps the filesystem; the stale `/tmp/.X1-lock` killed Xvfb. `setup.sh` now removes and recreates the container and clears the lock.
- `lxpanel`/`pcmanfm` were removed from supervisord, not neutered. Pointing a program at `/bin/true` makes the healthcheck fail forever.
- The base image's dead google-chrome apt source breaks `apt-get update`; it is removed before installing `wmctrl`.
- Cloud Shell free tier recycles sessions; the app self-heals, but a cold start takes minutes.
- The session is 1280×720 (Xvfb), viewed through noVNC.
- Screen capture for evidence: `docker exec cybershield ffmpeg -f x11grab -video_size 1280x720 -i :1 -frames:v 1 -y /tmp/shot.png`.

---

## 10. Repository map

```text
README.md                  user-facing story, setup, demo checks, gotchas
DEMO-DAY.md                gap list, 60-second demo beats, pre-flight, recovery
RUN-LOG.md                 17 documented failures + fixes + open items; verification log
cybershield-launcher.ps1   Windows app source (~1,050 lines)
Cybershield.exe            compiled app (ps2exe), committed
build-exe.ps1              compile step; installs ps2exe if needed; generates the icon
Rebuild Cybershield.cmd    double-click rebuild wrapper
Launch Cybershield.cmd     run the source without the exe
cloudshell-setup.sh        Cloud Shell installer + image/session definition
cybershield-sites.json     local site list (gitignored; created on first save)
cybershield.log            local action log (gitignored)
hub-page.png               screenshot of the live locked session
blocked-page.png           screenshot of the allow-mode blocked page
cybershield.ico            app icon
```

Git: branch `main`, public `origin` = `github.com/kanqzkokelo/stai-cybershield`; working tree clean except untracked `.opencode/`.

---

## 11. What "progress" could mean — the decision to make

**A. Demo-first (next 1–3 days).** Rehearse the 60-second run twice; record a backup video; capture block-mode proof; pre-warm the session; fix FAIL-17; add a LICENSE; update `DEMO-DAY.md` statuses. Lowest risk, highest demo payoff.

**B. Hardening (next 1–2 weeks).** Automate the embedded-installer regeneration; tighten the localhost exemption; add a diagnostics/self-test button; improve retries and cancellation; add PowerShell/bash lint and CI; sign the build; test on a clean Windows machine.

**C. Product (next 1–3 months).** Accounts and multi-tenancy; a parent/admin web console; per-child profiles; schedules and time limits; usage reports; a hosted backend instead of a personal Cloud Shell; local/offline mode; a cross-platform client; privacy/compliance story; pricing.

**D. Pitch/presentation.** A 2-minute video, a README front page, an architecture diagram, impact metrics (time saved, bypass resistance), and judge Q&A prep.

The likely answer is **A now, then B**, with C only if this is meant to become a real product rather than a competition entry.

---

## 12. Questions for the reviewing AI

1. Given that demo day is imminent, what is the minimum set of work that materially de-risks the demo? What should we explicitly *not* do?
2. Is the architecture defensible to technical judges — especially "cloud-hosted browser as parental control" versus local filtering? What are the strongest objections, and what are the honest answers?
3. What is the highest-leverage next engineering step after the demo?
4. If this were to become a product, what would you change first and what would you keep?
5. What evidence or metrics should we capture now (screenshots, timings, failure counts) to make the submission stronger?

**Context the reviewer still needs from us:** judging criteria, deadline, team size, whether this is a competition or a startup, and what "progress" means — winning the demo versus shipping a product.
