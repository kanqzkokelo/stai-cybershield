# Presentation script — 15–20 minute showcase

Online rehearsal with two teachers, then the hackathon demo itself.
Format: live call, screen share, two presenters.
Content runs **15:45**; Q&A fills the rest of the 20 minutes.

Cast: **MAIN** tells the story and carries the pitch. **SUPPORT** drives the
app, owns the technical answers, and keeps the demo moving. Hand off by name.

---

## 1. Time budget

| Clock | Section | Who |
|-------|---------|-----|
| 0:00–1:00 | Framing + intros | MAIN |
| 1:00–3:00 | The problem, and what Cybershield is | MAIN |
| 3:00–4:00 | What you're about to see | SUPPORT |
| 4:00–6:00 | App tour | MAIN talks, SUPPORT clicks |
| 6:00–8:30 | Launch, live | SUPPORT clicks, MAIN narrates the wait |
| 8:30–11:00 | The proof: navigation + blocked page | SUPPORT drives, MAIN lands it |
| 11:00–12:30 | Change the rules live | MAIN asks, SUPPORT does |
| 12:30–14:00 | How it works | SUPPORT |
| 14:00–15:15 | Honest limits and what's next | MAIN |
| 15:15–15:45 | Close + Turn off | MAIN, SUPPORT clicks |
| 15:45–20:00 | Q&A | both |

If you're running long: cut the optional block-mode flip (11:00–12:30) and
shorten the architecture to one minute. If you're running short: add the
block-mode flip and one more Q&A prompt.

---

## 2. Pre-call checklist (start 20 minutes before)

- [ ] `Cybershield.exe` open; status reads **"Ready. Signed in as …"**
- [ ] Websites list: `wikipedia.org`, `khanacademy.org` — mode **Allow only these sites**
- [ ] Decide the live-add site for 11:00-12:30 (suggested: `nasa.gov`)
- [ ] **Warm the session**: Launch once, confirm toolbar + hub, open one site,
      try `youtube.com` → Blocked Page. Then **Turn off session**. (This caches the
      image; the live Launch then takes ~20–45 s, not 4.5 min.)
- [ ] Backup recording open in a tab, paused at frame one, volume up
- [ ] Close email/chat/personal tabs; turn on Focus Assist (no notifications)
- [ ] Window layout: app on the left half, empty browser window on the right half
- [ ] Laptop plugged in; phone hotspot on standby
- [ ] Know your screen-share order: app first, session window second
- [ ] Say your intro line once out loud before joining

**Never share the whole desktop.** Share the specific window being discussed.

---

## 3. The run of show

### 0:00–1:00 — Framing (MAIN)

> **MAIN:** "Thanks for making time. What we want from today is a real rehearsal,
> not a summary — we're going to run the exact demo we plan to give the judges,
> start to finish, and then we'd like your notes on what lands and what doesn't.
> I'm [name], I'll be talking. This is [name], who runs the demo and knows the
> engineering."

> **SUPPORT:** "Hi — I'll be driving, so if anything looks slow, that's the
> software doing real work, not a slide."

### 1:00–3:00 — The problem (MAIN)

> **MAIN:** "Every school that hands a student a laptop runs into the same
> problem: either the browser is wide open, or it's locked by a filter the
> student spends the first week learning to get around. Network filters lose to
> a phone hotspot. Installed agents need admin rights on every device and
> something to maintain. And none of it gives a teacher a simple switch.
>
> Cybershield takes a different angle: **the browser doesn't live on the
> student's machine — it lives in the cloud, and the rules travel with it.**
> The teacher decides which sites exist for that session, from a small Windows
> app, and the browser itself enforces the list. Nothing is installed on the
> student's PC, and there's nothing local to tamper with."

### 3:00–4:00 — What you're about to see (SUPPORT)

> **SUPPORT:** "Four things, in order. The app and the policy list. A live
> launch — about half a minute. Proof that navigation still works while the
> lock holds. And a rule change while the session is running: we add a site,
> reset, and it's there in about thirty seconds. Then we'll show the
> architecture and answer questions."

**[SUPPORT brings the app window to the front.]**

### 4:00–6:00 — App tour (MAIN talks, SUPPORT clicks)

**[SUPPORT clicks through the list, both radio buttons, hovers the buttons.]**

> **MAIN:** "This is the whole teacher-facing product. The website list — these
> are the only sites this session can reach. Two modes: *allow only these*, for
> a locked-down lesson, or *allow everything except these*, for normal school
> use with a few distractions removed. Add and Remove edit the list. Launch
> starts a session; Reset applies a new list to a session that's already
> running; Turn off ends it. That's it — no dashboards, no training course."

**[SUPPORT switches to the block-mode radio and back, so both are seen.]**

> **MAIN:** "The important part isn't the buttons. It's where the rule lives:
> not on the student's machine, and not as an overlay in the page — inside the
> browser's own policy engine, on the remote session."

### 6:00–8:30 — Launch, live (SUPPORT clicks, MAIN narrates)

**[SUPPORT clicks Launch session. Status bar: "Provisioning the Cloud Shell session".]**

> **SUPPORT:** "Launch is doing three things: it pushes the site list to the
> session machine, it starts the browser container, and it reads back the
> session's address."

> **MAIN:** "While that runs — this is the part most demos hide with a loading
> spinner. The session runs on a Cloud Shell VM, and the app checks that the
> session software is present and current before every launch. If the machine
> has been wiped or recycled, it reinstalls itself automatically — upload
> checksum-verified, image rebuilt — about four and a half minutes, unattended.
> That's how the demo survives a fresh laptop."

**[Session window opens: full Firefox, toolbar visible, hub page listing exactly
the two sites.]**

> **MAIN:** "And that's the entire internet for this session: Wikipedia and
> Khan Academy. Not a blocklist with holes in it — an allowlist."

### 8:30–11:00 — The proof (SUPPORT drives)

**[SUPPORT clicks Wikipedia from the hub. It loads. Then uses Back, Forward,
Reload, and types a URL in the address bar.]**

> **SUPPORT:** "It's a real browser — back, forward, reload, address bar. A
> kiosk that can't navigate is useless in a classroom, so navigation stays."

**[SUPPORT types `youtube.com`, Enter. The Firefox Blocked Page appears.]**

> **MAIN:** "That page is generated by Firefox's own enterprise policy engine,
> because the policy says no. It's not a picture we drew and it's not a browser
> extension the student can disable. Try it again, reload it — it stays blocked."

**[SUPPORT reloads the blocked page once to prove it.]**

> **MAIN:** "This is the moment to be precise: this is a policy-enforced
> *browsing* lock, not a network firewall. It decides what this browser may
> reach. That's exactly the surface a school cares about."

### 11:00–12:30 — Change the rules live (MAIN asks, SUPPORT does)

> **MAIN:** "Now the teacher changes their mind mid-lesson. We're doing a
> project on space — add NASA."

**[SUPPORT types `nasa.gov` in the Websites box, clicks Add, clicks Reset
session. ~30 s. The session window reopens; the hub now lists three sites.]**

> **SUPPORT:** "Reset re-pushes the list and restarts the browser — no
> reinstall, about half a minute."

**[SUPPORT opens nasa.gov from the hub.]**

> **MAIN:** "Rules changed while it ran. That's the whole workflow a teacher
> needs: edit the list, reset, done."

**Optional (30–40 s):** switch to *Allow everything except these*, list
`youtube.com`, Reset → everything loads except YouTube. Use this only if time
allows; it's the strongest answer to "what about normal school use?"

### 12:30–14:00 — How it works (SUPPORT)

**[SUPPORT shows the README architecture diagram.]**

> **SUPPORT:** "Five pieces. The Windows app — a PowerShell WinForms program,
> compiled to one exe. It talks to Google Cloud Shell over the authenticated
> `gcloud` channel. The Cloud Shell VM runs a Docker container: Firefox with a
> locked policy file, plus a small VNC server that streams the screen. Your
> browser is just a viewer for that stream.
>
> Two consequences. First, the lock lives on the remote machine — the student's
> PC has no policy file to edit and no extension to remove. Second, the whole
> thing provisions itself: the app compares a checksum of the session software
> against what's on the VM, uploads it in verified chunks if it's missing, and
> runs the installer. A wiped Cloud Shell comes back to a working session in
> about four and a half minutes with nobody touching it.
>
> The app is about a thousand lines; the session side is a setup script, a policy
> writer, and a Dockerfile. The interesting engineering is in the failure log —
> sixteen documented failures, each with cause and proof."

### 14:00–15:15 — Honest limits and what's next (MAIN)

> **MAIN:** "What this is today: a working demo of the control model, and a
> reliable one — we've killed the session, wiped the server, and rebuilt it
> from the app, repeatedly.
>
> What it isn't yet: per-student accounts — right now the session belongs to
> one Google account, which is fine for a demo and wrong for a school. Cloud
> Shell is a free tier with weekly limits; production would be a small VM per
> school. And locking the *device* — so the student can't open another browser
> — is a deployment concern we'd solve with kiosk mode on managed hardware.
>
> Next: a class roster instead of one list, schedules — homework hours versus
> lesson hours — and an audit log of what was reachable when. The control model
> is the part we're proving today; the rest is product work."

### 15:15–15:45 — Close (MAIN)

> **MAIN:** "Cybershield: the browser lives in the cloud, the rules live with
> it, and the teacher holds the switch."

**[SUPPORT clicks Turn off session. The status reads "Session is off."]**

> **MAIN:** "And it ends when we say so. Thank you — questions?"

### 15:45–20:00 — Q&A

Use the crib below. MAIN takes why/impact/roadmap; SUPPORT takes technical.
If a question needs the session, SUPPORT launches again (~30 s) and narrates
the wait — it's a feature, not a stall.

---

## 4. Q&A crib

| Question | Answer | Who |
|----------|--------|-----|
| "Can't a student just open Chrome?" | "On an unmanaged PC, yes — this is the policy layer, not device lockdown. The target is a school-managed device in kiosk mode, where this is the only browser that runs. The lock itself is remote, so the student can't edit it." | MAIN |
| "What if the internet drops?" | "The browser is remote, so there's no browsing offline — same as any cloud filter. When the connection returns, the session is still there; the policy persists. The app is the only local piece and it holds the list." | SUPPORT |
| "How do you stop a student changing the rules?" | "The policy lives on the session VM, behind the Google account that owns it. The student's machine has nothing to edit. Per-student accounts and an audit log are the next step." | SUPPORT |
| "Isn't Cloud Shell a toy?" | "It is a free tier — 50 hours a week — and that's exactly why the demo works anywhere with no setup. Production would be a small VM per school; the app and session image don't change." | MAIN |
| "Is the block page real?" | "Yes — Firefox enterprise policy, `WebsiteFilter`. The browser refuses the request; there's no overlay to dismiss." | SUPPORT |
| "What did you build vs. use?" | "We built the app, the provisioning, the session image and the policy pipeline. Firefox, Docker and the VNC stream are standing on shoulders. The run log documents sixteen failures we found and fixed." | SUPPORT |
| "What about phones/tablets?" | "Same model — the session is just a browser; it doesn't care what the viewer runs. The app is Windows today because that's the teacher's desk." | MAIN |
| "What's next?" | "Class rosters, schedules, audit log, SSO, and a local edge option for schools that can't stream." | MAIN |
| "Why should we believe it works?" | "We wiped the server during development and let the app rebuild it — four and a half minutes, unattended. We also killed the session and relaunched it live before this call." | SUPPORT |

---

## 5. If something breaks (online playbook)

- **Launch passes 90 s** — narrate the self-provisioning story (§6:00). Past
  2.5 minutes: switch to the backup recording, keep talking, relaunch in the
  background.
- **"Could not reach the session"** — click Launch again; no run has failed
  twice in a row. Still dead: backup recording + RUN-LOG story.
- **Session window blank** — `Ctrl+R` in it; if dead, Launch again.
- **Wrong window shared** — stop sharing, share the correct window, apologize
  once, move on. Never share the desktop.
- **Wrong site in the list / typo** — fix it in the app, Reset; the audience
  sees the workflow, not a failure.
- **Wifi drops** — rejoin on hotspot; the session survives; if the call itself
  dies, the backup video and screenshots are in the repo.
- **App crashes** — relaunch `Cybershield.exe`; the site list is saved.
- **SmartScreen on a new machine** — More info → Run anyway; antivirus ate the
  exe → `Launch Cybershield.cmd`.

---

## 6. Rehearsal plan

1. **Run 1 — stopwatch.** No interruptions. Note where you cross 5:00, 10:00,
   15:00. Trim or expand to land the close at ~15:30.
2. **Run 2 — with a failure.** Have SUPPORT close the session window mid-demo
   and recover with Ctrl+R, then do a second Launch. Practice narrating the
   wait without dead air.
3. **Record run 2** — that's the backup video (2 minutes of highlights is
   enough; link it from the README).

Feedback to ask the teachers at the end, verbatim:

> "What would you cut? And what question do you think the judges will ask that
> we didn't answer?"

---

## 7. End state

After the call: session **off**, app open, site list back to the three demo
sites (or your chosen list), backup video saved, this file updated with any
timing changes you made.
