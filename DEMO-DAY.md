# Demo day — runbook and readiness list

Where we're lacking, in priority order — plus the exact beats to rehearse.
Owner "me" = the assistant can do it; "you" = needs the account / the stage.

## 1. Gap list

| # | Gap | Why it hurts | Fix | Owner | Status |
|---|-----|--------------|-----|-------|--------|
| 1 | Full click-through with the new build | surprises on stage | rehearse §2 once, start to finish | you | **partly done** — real use 19 Oct 21:48–22:03: Launch (2 sites), Turn off, Launch (4 sites), Turn off — all OK first try (OK-7); the scripted §2 run is still TODO |
| 2 | Block mode never shown with evidence | "except these" is half the pitch | proof run on the live session | me | policy + Reset verified live; the visible block page on record is allow-mode — `blocked-page.png` |
| 3 | Work uncommitted | losing it = losing the demo | pushed to GitHub (public) | me | DONE — `github.com/kanqzkokelo/stai-cybershield` |
| 4 | No backup recording | wifi / Cloud Shell can fail | record one clean 2-min run | you | TODO |
| 5 | First-run image build is ~4.5 min | it must never appear live | pre-warm ritual (§3) + stay warm | you | ritual below |
| 6 | SmartScreen / antivirus on a foreign laptop | judges' PC refuses the exe | two fallbacks (§4) | you | noted |
| 7 | Judges cannot open the session URL themselves (account-locked) | they may try | present on your screen; say §2's honesty line | you | noted |
| 8 | README lacks screenshots / a diagram for skimming judges | first impression | hub screenshot + mini diagram | me | TODO |
| 9 | Cloud Shell weekly quota is 50 h | a cap ends the day early | glance at the quota in the Cloud Shell console | you | TODO |
| 10 | Branded blocked page (stretch) | demo sparkle | bundle a tiny extension via policy | me | optional |
| 11 | No LICENSE file | convention, if judged as a public repo | MIT, your call | you | ask |

## 2. The 60-second live demo

Setup: your list — currently `wikipedia.org`, `khanacademy.org`, `google.com`,
`youtube.com`, allow-only mode. (Adjust the list first if you want a different
live-add beat.)

1. **(5 s)** Open the app. "This is Cybershield. The parent decides what is
   reachable — and the browser lives in the cloud, so nothing gets installed on
   the kid's PC."
2. **(15 s)** **Launch session** → locked Firefox appears; the hub lists exactly
   your sites. "That's the whole internet for this machine right now."
3. **(15 s)** Type a site that is **not** on your list (`reddit.com`, say) →
   the blocked-by-policy page (`blocked-page.png`). "The lock is real policy,
   not hidden buttons — and the controls are there for the parent: back,
   reload, search."
4. **(20 s)** Add a site live: type `nasa.gov` → **Add** → **Reset session** →
   hub shows the new site; open it. "Rules change while it runs — no reinstall,
   about half a minute."
5. **(5 s)** **Turn off session** → the screen goes dead. "And it ends when I
   say so."

Honesty line (builds trust with judges): "The preview URL is locked to my
Google account, so I present it from my machine — nobody else can open the
session."

Optional block-mode beat (only once §1-#2 lands): switch to "Allow everything
except these", add `youtube.com`, **Reset** → same blocked page, everything
else reachable.

If there is time, the engineering story: RUN-LOG (16 documented failures with
causes and proofs), the self-provisioning install, the plink transport work.

## 3. Ten minutes before you go on

- [ ] App open, status shows "Ready. Signed in as …"
- [ ] Launch once: toolbar + hub correct, `youtube.com` blocked
- [ ] Decide the live-add site for beat 4
- [ ] Don't let the session idle >1 h; if the wait runs long, Launch once more
- [ ] Phone hotspot on standby; laptop charged
- [ ] Backup video ready to play
- [ ] Projector sanity: window readable; remember the chromeless window reloads
      with Ctrl+R

## 4. If something breaks (recovery playbook)

- **Launch takes >90 s / bar says building** — Cloud Shell was recycled; the app
  is rebuilding itself (~4.5 min). Narrate that; it's the self-provisioning
  feature working. Or roll the backup video.
- **"Could not reach the session"** — press Launch again (no run has failed
  twice in a row). Still failing: backup video + the RUN-LOG story.
- **Outer window blank** — Ctrl+R in it; if dead, Launch again.
- **SmartScreen on a fresh machine** — More info → Run anyway.
  **Antivirus eats the exe** — run `Launch Cybershield.cmd` instead (source, no
  SmartScreen).
- **Wifi gone** — hotspot; nothing works fully offline (the session lives in
  Cloud Shell) — the video is the floor.

## 5. If it is judged on submission instead of live

- Push the repo; the README front page carries the story and the screenshot.
- The 2-minute video still matters — record it and link it.
- RUN-LOG is the differentiator for engineering-minded judges: 16 failures,
  each with cause, fix, and evidence.

## 6. Maintenance

This file lives in the repo. Status column moves as items land; keep §2's
numbers in sync with what actually works on the stage machine.
