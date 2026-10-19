#!/usr/bin/env bash
# ============================================================================
# STAI Cybershield - Cloud Shell installer
#
#   Paste this whole file into a Cloud Shell terminal. It installs itself to
#   ~/cybershield/setup.sh, then builds and runs the locked Firefox session.
#
#   After that, parents pick the websites from the Windows app - the app
#   pushes the list here and the session reloads with it.
#
#   Re-run any time:  bash ~/cybershield/setup.sh
# ============================================================================

mkdir -p "$HOME/cybershield"
cat > "$HOME/cybershield/setup.sh" <<'CYBERSHIELD_SETUP_EOF'
#!/usr/bin/env bash
# STAI Cybershield - locked Firefox session for Google Cloud Shell.
set -euo pipefail

# Locate ourselves from the script path, NOT $HOME: the boot hook runs this as
# root, where $HOME is /root.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=cybershield
IMAGE=cybershield-demo
BUILD="$DIR/image"

DOCKER=docker
docker info >/dev/null 2>&1 || { sudo -n docker info >/dev/null 2>&1 && DOCKER="sudo docker"; }
mkdir -p "$BUILD"

# ---------------------------------------------------------------------------
# 1. Policy generator. The Windows app calls this with a base64 blob; parents
#    never edit JSON by hand.
# ---------------------------------------------------------------------------
cat > "$DIR/write_policy.py" <<'PY'
#!/usr/bin/env python3
"""Cybershield policy writer.

    write_policy.py            regenerate policies.json from policy.json
    write_policy.py <base64>   replace policy.json from <base64>, then regenerate

policy.json   = what the parent chose  { "mode": "allow"|"block", "sites": [] }
policies.json = what Firefox reads (generated)
"""
import base64
import json
import os
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
PARENT = os.path.join(BASE, "policy.json")
FIREFOX = os.path.join(BASE, "policies.json")
HUB = os.path.join(BASE, "start.html")

DEFAULT = {"mode": "allow", "sites": ["wikipedia.org", "khanacademy.org"]}


def write_hub(cfg, sites, mode):
    """Rewrite the hub page so it lists exactly what the policy allows.

    In allow mode every listed site is a link. In block mode the list is what is
    forbidden, so the page shows the sites that are still reachable instead of
    dead links - a hub full of links that cannot open would look broken.
    """
    import html as htmllib

    if mode == "block":
        note = "Blocked here: %s" % (", ".join(sites) if sites else "nothing")
        cards = ['<a class="ok" href="https://www.google.com/">Browse <small>google.com</small></a>']
    else:
        note = "The parent decides what is reachable"
        cards = [
            '<a class="ok" href="https://%s/">%s <small>open &rarr;</small></a>'
            % (htmllib.escape(s), htmllib.escape(s))
            for s in sites
        ]
        if not cards:
            cards = ['<p>No sites have been allowed yet.</p>']

    page = """<!doctype html><html><head><meta charset="utf-8"><title>Cybershield</title>
<style>
 body{margin:0;font:16px system-ui,sans-serif;background:#0b1020;color:#e8ecf7;
      display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh}
 h1{margin:0 0 4px;font-size:34px;letter-spacing:-.5px}
 p{margin:0 0 30px;color:#8b97b8}
 .grid{display:grid;grid-template-columns:1fr 1fr;gap:14px;width:min(760px,90vw)}
 a{padding:22px 20px;border-radius:12px;text-decoration:none;font-weight:600;
   display:flex;justify-content:space-between;align-items:center}
 .ok{background:#12331f;color:#7ef2a8;border:1px solid #1e5c37}
 small{font-weight:400;opacity:.7}
</style></head><body>
<h1>STAI Cybershield</h1>
<p>%(note)s</p>
<div class="grid">
%(cards)s
</div>
</body></html>
""" % {"note": htmllib.escape(note),
       "cards": "\n  ".join("  " + c for c in cards)}

    with open(HUB, "w") as fh:
        fh.write(page)


def patterns(host):
    """Firefox WebsiteFilter patterns that cover a domain and its subdomains."""
    hosts = [host, host[4:]] if host.startswith("www.") else [host, "*." + host]
    out = []
    for h in hosts:
        out.append("http://%s/*" % h)
        out.append("https://%s/*" % h)
    return out


def build(cfg):
    mode = cfg.get("mode", "allow")
    sites = cfg.get("sites", [])
    if isinstance(sites, str):          # guard against a single-site list
        sites = [sites]
    sites = sorted({s.strip().lower() for s in sites if s.strip()})

    # The hub page is generated from the same list that is enforced, so the page
    # a child sees can never disagree with what the policy actually allows.
    write_hub(cfg, sites, mode)

    exceptions = ["http://localhost/*", "https://localhost/*",
                  "http://127.0.0.1/*", "https://127.0.0.1/*"]
    block = []

    if mode == "block":
        for s in sites:
            block.extend(patterns(s))
    else:
        for s in sites:
            exceptions.extend(patterns(s))
        block = ["<all_urls>"]

    return {
        "policies": {
            "WebsiteFilter": {"Block": block, "Exceptions": exceptions},
            "BlockAboutConfig": True,
            "DisableDeveloperTools": True,
            "DisablePrivateBrowsing": True,
            "DisableFirefoxAccounts": True,
            "DisableFirefoxStudies": True,
            "DisablePocket": True,
            "DisableTelemetry": True,
            "DisableFeedbackCommands": True,
            "DontCheckDefaultBrowser": True,
            "DisplayBookmarksToolbar": False,
            "OfferToSaveLogins": False,
            "PasswordManagerEnabled": False,
            "SearchSuggestEnabled": False,
            "OverrideFirstRunPage": "",
            "OverridePostUpdatePage": "",
            "Preferences": {
                "browser.aboutwelcome.enabled": False,
                "browser.sessionstore.resume_from_crash": False,
                "browser.tabs.warnOnClose": False,
                "toolkit.telemetry.enabled": False,
                "datareporting.policy.dataSubmissionEnabled": False,
                "app.update.auto": False,
            },
        }
    }


def main():
    os.makedirs(BASE, exist_ok=True)

    if len(sys.argv) > 1:
        cfg = json.loads(base64.b64decode(sys.argv[1]).decode("utf-8"))
        with open(PARENT, "w") as fh:          # in-place: keeps the bind mount valid
            json.dump(cfg, fh, indent=2)
    elif os.path.exists(PARENT):
        with open(PARENT) as fh:
            cfg = json.load(fh)
    else:
        cfg = DEFAULT
        with open(PARENT, "w") as fh:
            json.dump(cfg, fh, indent=2)

    with open(FIREFOX, "w") as fh:
        json.dump(build(cfg), fh, indent=2)

    sites = cfg.get("sites", [])
    if isinstance(sites, str):
        sites = [sites]
    print("CYBERSHIELD_OK sites=%d mode=%s" % (len(sites), cfg.get("mode", "allow")))


if __name__ == "__main__":
    main()
PY

# generate policy.json (defaults on first run) + policies.json for Firefox
python3 "$DIR/write_policy.py"
cp "$DIR/policies.json" "$BUILD/policies.json"

# ---------------------------------------------------------------------------
# 2. Portal page - served by the container's nginx at /start.html
#
# This is only the fallback used if the generator above has not run yet. The
# real page is written by write_policy.py from the parent's actual list, so it
# always matches the policy that is enforced.
# ---------------------------------------------------------------------------
cat > "$DIR/start.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><title>Cybershield</title>
<style>
 body{margin:0;font:16px system-ui,sans-serif;background:#0b1020;color:#e8ecf7;
      display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh}
 h1{margin:0 0 4px;font-size:34px;letter-spacing:-.5px}
 p{margin:0 0 36px;color:#8b97b8}
 .grid{display:grid;grid-template-columns:1fr 1fr;gap:14px;width:min(760px,90vw)}
 a{padding:22px 20px;border-radius:12px;text-decoration:none;font-weight:600;
   display:flex;justify-content:space-between;align-items:center}
 .ok{background:#12331f;color:#7ef2a8;border:1px solid #1e5c37}
 .no{background:#33121a;color:#ff8fa3;border:1px solid #5e1e2a}
 small{font-weight:400;opacity:.7}
</style></head><body>
<h1>STAI Cybershield</h1>
<p>Managed locked session &mdash; the parent decides what is reachable</p>
<div class="grid">
  <a class="ok" href="https://en.wikipedia.org/wiki/Computer_security">Allowed <small>wikipedia.org</small></a>
  <a class="ok" href="https://www.khanacademy.org/">Allowed <small>khanacademy.org</small></a>
  <a class="no" href="https://www.youtube.com/">BLOCKED <small>youtube.com</small></a>
  <a class="no" href="https://www.reddit.com/">BLOCKED <small>reddit.com</small></a>
</div>
</body></html>
HTML

# the generator owns start.html from here on
python3 "$DIR/write_policy.py"

# ---------------------------------------------------------------------------
# 3. Session launcher
#
# A normal Firefox window, maximised - NOT --kiosk. Kiosk mode hides the whole
# browser UI, and then there is no back button, no reload and no address bar, so
# a child can only ever click links on the page in front of them. With the real
# toolbar visible the browser is navigable; the WebsiteFilter policy is what
# keeps it locked, not the absence of buttons.
#
# wmctrl (installed in the image) tells openbox to maximise the window. If that
# ever fails the window is still a normal one - just not full-screen.
#
# Firefox is restarted if it is closed: no panel, no desktop, and closing the
# window should not leave a blank machine.
# ---------------------------------------------------------------------------
cat > "$DIR/firefox-session" <<'KIOSK'
#!/bin/sh
for _ in $(seq 1 30); do xdpyinfo -display :1 >/dev/null 2>&1 && break; sleep 1; done
sleep 3
while :; do
  /usr/bin/firefox --new-instance http://localhost/start.html &
  ff=$!
  i=0
  while [ $i -lt 45 ]; do
    ids=$(wmctrl -lx 2>/dev/null | awk 'tolower($0) ~ /firefox/ {print $1}')
    [ -n "$ids" ] && break
    sleep 1
    i=$((i + 1))
  done
  for id in $ids; do
    wmctrl -i -r "$id" -b add,maximized_vert,maximized_horz
  done
  wait $ff
  sleep 2
done
KIOSK
chmod +x "$DIR/firefox-session"

cp "$DIR/start.html" "$BUILD/start.html"
cp "$DIR/firefox-session" "$BUILD/firefox-session"

# ---------------------------------------------------------------------------
# 4. Image
# ---------------------------------------------------------------------------
cat > "$BUILD/Dockerfile" <<'DOCKERFILE'
FROM wenoptics/ubuntu-desktop-novnc:latest

# smoother on Cloud Shell's shared vCPU
RUN printf '#!/bin/sh\nRES="${RESOLUTION:-1280x720}"\nexec /usr/bin/Xvfb :1 -screen 0 "${RES}x16"\n' \
      > /usr/local/bin/xvfb.sh && chmod +x /usr/local/bin/xvfb.sh
RUN sed -i 's#^command=x11vnc .*#& -nowf#' /etc/supervisor/conf.d/supervisord.conf

# Firefox is the ONLY browser in this machine
RUN apt-get purge -y google-chrome-stable || true
RUN rm -f /etc/apt/sources.list.d/google-chrome.list \
          /usr/share/applications/google-chrome.desktop \
          /usr/share/applications/chromium-browser-sound.desktop \
          /usr/local/bin/chromium-browser-sound.sh \
          /usr/local/bin/chrome-good

# wmctrl lets the session launcher maximise the Firefox window. Installed only
# AFTER the dead google-chrome apt source is gone - with it present, apt-get
# update dies on "repository is not signed" (NO_PUBKEY FD533C07C264648F) and
# takes the whole build down with it.
RUN apt-get update \
 && apt-get install -y --no-install-recommends wmctrl \
 && rm -rf /var/lib/apt/lists/*

# Fallback policy, baked in so a bare `docker run` is never wide open.
# At normal runtime this is replaced by the parent's list via a bind mount.
COPY policies.json /etc/firefox/policies/policies.json

# portal page
COPY start.html /usr/local/lib/web/frontend/start.html

# No taskbar and no desktop icons: take lxpanel and pcmanfm out of supervisord
# completely, so all that is left on the screen is the kiosk browser.
#
# Do NOT do this by pointing lxpanel at /bin/true: the process then exits
# immediately on every start and supervisord parks it in a FATAL back-off loop.
# `supervisorctl status` then exits 3, the image's own /api/health returns 500,
# and that endpoint is exactly what the image's HEALTHCHECK calls - so the
# container sits at "unhealthy" forever and every Launch waits out the whole
# health timeout.
RUN sed -i \
      -e '/^\[program:lxpanel\]/,/^\[program:pcmanfm\]/{/^\[program:pcmanfm\]/!d}' \
      -e '/^\[program:pcmanfm\]/,/^\[program:xvfb\]/{/^\[program:xvfb\]/!d}' \
      -e 's/^programs=xvfb,wm,lxpanel,pcmanfm,x11vnc,novnc$/programs=xvfb,wm,x11vnc,novnc/' \
      /etc/supervisor/conf.d/supervisord.conf

# maximised Firefox with its normal toolbar, started once X is up
COPY firefox-session /usr/local/bin/firefox-session
RUN chmod +x /usr/local/bin/firefox-session \
 && printf '\n[program:cybershield]\npriority=30\ndirectory=/root\ncommand=/usr/local/bin/firefox-session\nenvironment=DISPLAY=":1",HOME="/root",USER="root"\nstartsecs=5\n' \
      >> /etc/supervisor/conf.d/supervisord.conf

# A container restart keeps the filesystem, so Xvfb's lock file and its socket
# survive from the run before. Xvfb then refuses to start - "Server is already
# active for display 1" - and because Firefox waits for that display, the whole
# session comes up dead. That made every Reset (and every Launch of an existing
# session) show a blank screen, so clear them first.
RUN printf '#!/bin/sh\nrm -f /tmp/.X1-lock /tmp/.X11-unix/X1\nexec /usr/bin/Xvfb :1 -screen 0 1280x720x24 -ac +extension GLX +render -noreset\n' > /usr/local/bin/xvfb.sh \
 && chmod +x /usr/local/bin/xvfb.sh

# which Firefox did we get? (if this prints "snap", tell me)
RUN /usr/bin/firefox --version 2>&1 | head -1 || true
DOCKERFILE

# Rebuild when the files that DEFINE the image change, not only when the image is
# missing. Otherwise a machine that already has an older build (no toolbar, old
# kiosk launcher) keeps running it forever - the image tag alone never changes.
BUILD_ID=$(cat "$BUILD/Dockerfile" "$BUILD/firefox-session" | md5sum | cut -c1-12)
HAVE_ID=$($DOCKER image inspect -f '{{index .Config.Labels "cybershield.build"}}' "$IMAGE" 2>/dev/null || true)
if [ "$HAVE_ID" != "$BUILD_ID" ]; then
  echo "== building $IMAGE (first run pulls ~2 GB - do this BEFORE the demo) =="
  $DOCKER build --label "cybershield.build=$BUILD_ID" -t "$IMAGE" "$BUILD"
fi

# ---------------------------------------------------------------------------
# 5. Run. The parent's list is bind-mounted in, so changing it only needs a
#    container restart - no rebuild.
# ---------------------------------------------------------------------------
$DOCKER rm -f "$NAME" >/dev/null 2>&1 || true
$DOCKER run -d --name "$NAME" --shm-size=1g -p 6080:80 \
  -v "$DIR/policies.json":/etc/firefox/policies/policies.json:ro \
  -v "$DIR/start.html":/usr/local/lib/web/frontend/start.html:ro \
  "$IMAGE" >/dev/null

printf '== waiting for session'
for _ in $(seq 1 60); do
  st=$($DOCKER inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}nohc{{end}}' "$NAME" 2>/dev/null || echo x)
  case "$st" in healthy|nohc) break;; esac
  printf '.'; sleep 2
done
echo " ($st)"

# ---------------------------------------------------------------------------
# 6. Auto-start on every fresh Cloud Shell VM
# ---------------------------------------------------------------------------
cat > "$HOME/.customize_environment" <<EOF
#!/bin/bash
bash "$DIR/setup.sh" >>"$DIR/boot.log" 2>&1
EOF
chmod +x "$HOME/.customize_environment"

echo
echo "  installed in = $DIR"
echo "  host         = $WEB_HOST"
echo "  open         = https://6080-$WEB_HOST/?quality=2&compression=1&scalingMode=scale&clipToWindow=true&dotCursor=true"
echo
CYBERSHIELD_SETUP_EOF

bash "$HOME/cybershield/setup.sh"
