<#
  STAI Cybershield - launcher + website list (Windows)

  Runs either way:
    - as a script:      right-click -> Run with PowerShell
    - as an .exe:       compiled by build-exe.ps1

  If the Google Cloud CLI isn't installed, the app installs it for you and
  tracks the install on a progress bar. If you aren't signed in, it opens the
  sign-in flow for you. The website list is yours to edit.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------- remote bits --
# Deliberately free of > | & " % so nothing gets mangled passing through
# gcloud.cmd on Windows. $B64 is substituted at call time.
#
# Both of these finish with `bash setup.sh` rather than `docker restart`. A
# restart keeps the container's filesystem, so a stale X lock left behind by the
# previous run makes Xvfb refuse to start ("Server is already active for display
# 1") and the session comes back with a blank screen. setup.sh removes and
# re-creates the container, and it also re-generates policies.json and the hub
# page from the list that was just written, so the page and the policy can never
# drift apart.
#
# If the Cloud Shell side does not exist at all (brand-new session, or Cloud
# Shell recycled the VM and wiped $HOME), there is no ~/cybershield/setup.sh to
# run. Start-Remote checks for it before running either command, uploads the
# installer this app carries ($SetupScriptB64 below, generated from
# cloudshell-setup.sh), verifies it byte for byte, runs it - and only then runs
# the command. So Launch alone is enough, even on a fresh account.
#
# Every marker is echoed twice with a pause between the copies: the ssh tunnel
# can drop the last line of output while it closes, and when that line is the
# marker, a run that actually worked looks like it failed.
$RemotePushStart = 'python3 $HOME/cybershield/write_policy.py $B64; bash $HOME/cybershield/setup.sh > $HOME/cybershield/launch.log 2>&1; for i in $(seq 1 45); do s=$(docker inspect -f {{.State.Health.Status}} cybershield); test $s = healthy && break; sleep 2; done; echo CYBERSHIELD_HOST=$WEB_HOST; sleep 1; echo CYBERSHIELD_HOST=$WEB_HOST'
$RemotePushReset = 'python3 $HOME/cybershield/write_policy.py $B64; bash $HOME/cybershield/setup.sh > $HOME/cybershield/launch.log 2>&1; echo CYBERSHIELD_RESET=ok; sleep 1; echo CYBERSHIELD_RESET=ok'

# Turns the locked session off without tearing anything down: stops the
# container, so the screen inside the session goes dead until the next Launch
# or Reset brings it back. There is nothing to set up first, so this command
# skips the installer check - stopping something that is not there is not an
# error, and the state probe would only cost time.
$RemoteSessionOff = 'docker stop cybershield >/dev/null 2>&1; sleep 1; docker inspect -f {{.State.Status}} cybershield 2>/dev/null; echo CYBERSHIELD_OFF=ok; sleep 1; echo CYBERSHIELD_OFF=ok'

$CloudSdkInstaller = 'https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe'

# cloudshell-setup.sh, the Cloud Shell side of the app, carried inside this
# build in base64 so a fresh Cloud Shell needs nothing pasted by hand.
# Start-Remote uploads and runs it when ~/cybershield/setup.sh is missing.
# Regenerate after editing cloudshell-setup.sh - from PowerShell, in this folder:
#
#   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\cloudshell-setup.sh"))
#
# and paste the single line it prints over the placeholder below. The file's LF
# line endings are part of the value: the bytes are uploaded as-is and run by
# bash, and CRLF would break it there ("$'\r': command not found").
$SetupScriptB64 = 'IyEvdXNyL2Jpbi9lbnYgYmFzaAojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KIyBTVEFJIEN5YmVyc2hpZWxkIC0gQ2xvdWQgU2hlbGwgaW5zdGFsbGVyCiMKIyAgIFBhc3RlIHRoaXMgd2hvbGUgZmlsZSBpbnRvIGEgQ2xvdWQgU2hlbGwgdGVybWluYWwuIEl0IGluc3RhbGxzIGl0c2VsZiB0bwojICAgfi9jeWJlcnNoaWVsZC9zZXR1cC5zaCwgdGhlbiBidWlsZHMgYW5kIHJ1bnMgdGhlIGxvY2tlZCBGaXJlZm94IHNlc3Npb24uCiMKIyAgIEFmdGVyIHRoYXQsIHBhcmVudHMgcGljayB0aGUgd2Vic2l0ZXMgZnJvbSB0aGUgV2luZG93cyBhcHAgLSB0aGUgYXBwCiMgICBwdXNoZXMgdGhlIGxpc3QgaGVyZSBhbmQgdGhlIHNlc3Npb24gcmVsb2FkcyB3aXRoIGl0LgojCiMgICBSZS1ydW4gYW55IHRpbWU6ICBiYXNoIH4vY3liZXJzaGllbGQvc2V0dXAuc2gKIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09Cgpta2RpciAtcCAiJEhPTUUvY3liZXJzaGllbGQiCmNhdCA+ICIkSE9NRS9jeWJlcnNoaWVsZC9zZXR1cC5zaCIgPDwnQ1lCRVJTSElFTERfU0VUVVBfRU9GJwojIS91c3IvYmluL2VudiBiYXNoCiMgU1RBSSBDeWJlcnNoaWVsZCAtIGxvY2tlZCBGaXJlZm94IHNlc3Npb24gZm9yIEdvb2dsZSBDbG91ZCBTaGVsbC4Kc2V0IC1ldW8gcGlwZWZhaWwKCiMgTG9jYXRlIG91cnNlbHZlcyBmcm9tIHRoZSBzY3JpcHQgcGF0aCwgTk9UICRIT01FOiB0aGUgYm9vdCBob29rIHJ1bnMgdGhpcyBhcwojIHJvb3QsIHdoZXJlICRIT01FIGlzIC9yb290LgpESVI9IiQoY2QgIiQoZGlybmFtZSAiJHtCQVNIX1NPVVJDRVswXX0iKSIgJiYgcHdkKSIKTkFNRT1jeWJlcnNoaWVsZApJTUFHRT1jeWJlcnNoaWVsZC1kZW1vCkJVSUxEPSIkRElSL2ltYWdlIgoKRE9DS0VSPWRvY2tlcgpkb2NrZXIgaW5mbyA+L2Rldi9udWxsIDI+JjEgfHwgeyBzdWRvIC1uIGRvY2tlciBpbmZvID4vZGV2L251bGwgMj4mMSAmJiBET0NLRVI9InN1ZG8gZG9ja2VyIjsgfQpta2RpciAtcCAiJEJVSUxEIgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyAxLiBQb2xpY3kgZ2VuZXJhdG9yLiBUaGUgV2luZG93cyBhcHAgY2FsbHMgdGhpcyB3aXRoIGEgYmFzZTY0IGJsb2I7IHBhcmVudHMKIyAgICBuZXZlciBlZGl0IEpTT04gYnkgaGFuZC4KIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KY2F0ID4gIiRESVIvd3JpdGVfcG9saWN5LnB5IiA8PCdQWScKIyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJDeWJlcnNoaWVsZCBwb2xpY3kgd3JpdGVyLgoKICAgIHdyaXRlX3BvbGljeS5weSAgICAgICAgICAgIHJlZ2VuZXJhdGUgcG9saWNpZXMuanNvbiBmcm9tIHBvbGljeS5qc29uCiAgICB3cml0ZV9wb2xpY3kucHkgPGJhc2U2ND4gICByZXBsYWNlIHBvbGljeS5qc29uIGZyb20gPGJhc2U2ND4sIHRoZW4gcmVnZW5lcmF0ZQoKcG9saWN5Lmpzb24gICA9IHdoYXQgdGhlIHBhcmVudCBjaG9zZSAgeyAibW9kZSI6ICJhbGxvdyJ8ImJsb2NrIiwgInNpdGVzIjogW10gfQpwb2xpY2llcy5qc29uID0gd2hhdCBGaXJlZm94IHJlYWRzIChnZW5lcmF0ZWQpCiIiIgppbXBvcnQgYmFzZTY0CmltcG9ydCBqc29uCmltcG9ydCBvcwppbXBvcnQgc3lzCgpCQVNFID0gb3MucGF0aC5kaXJuYW1lKG9zLnBhdGguYWJzcGF0aChfX2ZpbGVfXykpClBBUkVOVCA9IG9zLnBhdGguam9pbihCQVNFLCAicG9saWN5Lmpzb24iKQpGSVJFRk9YID0gb3MucGF0aC5qb2luKEJBU0UsICJwb2xpY2llcy5qc29uIikKSFVCID0gb3MucGF0aC5qb2luKEJBU0UsICJzdGFydC5odG1sIikKCkRFRkFVTFQgPSB7Im1vZGUiOiAiYWxsb3ciLCAic2l0ZXMiOiBbIndpa2lwZWRpYS5vcmciLCAia2hhbmFjYWRlbXkub3JnIl19CgoKZGVmIHdyaXRlX2h1YihjZmcsIHNpdGVzLCBtb2RlKToKICAgICIiIlJld3JpdGUgdGhlIGh1YiBwYWdlIHNvIGl0IGxpc3RzIGV4YWN0bHkgd2hhdCB0aGUgcG9saWN5IGFsbG93cy4KCiAgICBJbiBhbGxvdyBtb2RlIGV2ZXJ5IGxpc3RlZCBzaXRlIGlzIGEgbGluay4gSW4gYmxvY2sgbW9kZSB0aGUgbGlzdCBpcyB3aGF0IGlzCiAgICBmb3JiaWRkZW4sIHNvIHRoZSBwYWdlIHNob3dzIHRoZSBzaXRlcyB0aGF0IGFyZSBzdGlsbCByZWFjaGFibGUgaW5zdGVhZCBvZgogICAgZGVhZCBsaW5rcyAtIGEgaHViIGZ1bGwgb2YgbGlua3MgdGhhdCBjYW5ub3Qgb3BlbiB3b3VsZCBsb29rIGJyb2tlbi4KICAgICIiIgogICAgaW1wb3J0IGh0bWwgYXMgaHRtbGxpYgoKICAgIGlmIG1vZGUgPT0gImJsb2NrIjoKICAgICAgICBub3RlID0gIkJsb2NrZWQgaGVyZTogJXMiICUgKCIsICIuam9pbihzaXRlcykgaWYgc2l0ZXMgZWxzZSAibm90aGluZyIpCiAgICAgICAgY2FyZHMgPSBbJzxhIGNsYXNzPSJvayIgaHJlZj0iaHR0cHM6Ly93d3cuZ29vZ2xlLmNvbS8iPkJyb3dzZSA8c21hbGw+Z29vZ2xlLmNvbTwvc21hbGw+PC9hPiddCiAgICBlbHNlOgogICAgICAgIG5vdGUgPSAiVGhlIHBhcmVudCBkZWNpZGVzIHdoYXQgaXMgcmVhY2hhYmxlIgogICAgICAgIGNhcmRzID0gWwogICAgICAgICAgICAnPGEgY2xhc3M9Im9rIiBocmVmPSJodHRwczovLyVzLyI+JXMgPHNtYWxsPm9wZW4gJnJhcnI7PC9zbWFsbD48L2E+JwogICAgICAgICAgICAlIChodG1sbGliLmVzY2FwZShzKSwgaHRtbGxpYi5lc2NhcGUocykpCiAgICAgICAgICAgIGZvciBzIGluIHNpdGVzCiAgICAgICAgXQogICAgICAgIGlmIG5vdCBjYXJkczoKICAgICAgICAgICAgY2FyZHMgPSBbJzxwPk5vIHNpdGVzIGhhdmUgYmVlbiBhbGxvd2VkIHlldC48L3A+J10KCiAgICBwYWdlID0gIiIiPCFkb2N0eXBlIGh0bWw+PGh0bWw+PGhlYWQ+PG1ldGEgY2hhcnNldD0idXRmLTgiPjx0aXRsZT5DeWJlcnNoaWVsZDwvdGl0bGU+CjxzdHlsZT4KIGJvZHl7bWFyZ2luOjA7Zm9udDoxNnB4IHN5c3RlbS11aSxzYW5zLXNlcmlmO2JhY2tncm91bmQ6IzBiMTAyMDtjb2xvcjojZThlY2Y3OwogICAgICBkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO21pbi1oZWlnaHQ6MTAwdmh9CiBoMXttYXJnaW46MCAwIDRweDtmb250LXNpemU6MzRweDtsZXR0ZXItc3BhY2luZzotLjVweH0KIHB7bWFyZ2luOjAgMCAzMHB4O2NvbG9yOiM4Yjk3Yjh9CiAuZ3JpZHtkaXNwbGF5OmdyaWQ7Z3JpZC10ZW1wbGF0ZS1jb2x1bW5zOjFmciAxZnI7Z2FwOjE0cHg7d2lkdGg6bWluKDc2MHB4LDkwdncpfQogYXtwYWRkaW5nOjIycHggMjBweDtib3JkZXItcmFkaXVzOjEycHg7dGV4dC1kZWNvcmF0aW9uOm5vbmU7Zm9udC13ZWlnaHQ6NjAwOwogICBkaXNwbGF5OmZsZXg7anVzdGlmeS1jb250ZW50OnNwYWNlLWJldHdlZW47YWxpZ24taXRlbXM6Y2VudGVyfQogLm9re2JhY2tncm91bmQ6IzEyMzMxZjtjb2xvcjojN2VmMmE4O2JvcmRlcjoxcHggc29saWQgIzFlNWMzN30KIHNtYWxse2ZvbnQtd2VpZ2h0OjQwMDtvcGFjaXR5Oi43fQo8L3N0eWxlPjwvaGVhZD48Ym9keT4KPGgxPlNUQUkgQ3liZXJzaGllbGQ8L2gxPgo8cD4lKG5vdGUpczwvcD4KPGRpdiBjbGFzcz0iZ3JpZCI+CiUoY2FyZHMpcwo8L2Rpdj4KPC9ib2R5PjwvaHRtbD4KIiIiICUgeyJub3RlIjogaHRtbGxpYi5lc2NhcGUobm90ZSksCiAgICAgICAiY2FyZHMiOiAiXG4gICIuam9pbigiICAiICsgYyBmb3IgYyBpbiBjYXJkcyl9CgogICAgd2l0aCBvcGVuKEhVQiwgInciKSBhcyBmaDoKICAgICAgICBmaC53cml0ZShwYWdlKQoKCmRlZiBwYXR0ZXJucyhob3N0KToKICAgICIiIkZpcmVmb3ggV2Vic2l0ZUZpbHRlciBwYXR0ZXJucyB0aGF0IGNvdmVyIGEgZG9tYWluIGFuZCBpdHMgc3ViZG9tYWlucy4iIiIKICAgIGhvc3RzID0gW2hvc3QsIGhvc3RbNDpdXSBpZiBob3N0LnN0YXJ0c3dpdGgoInd3dy4iKSBlbHNlIFtob3N0LCAiKi4iICsgaG9zdF0KICAgIG91dCA9IFtdCiAgICBmb3IgaCBpbiBob3N0czoKICAgICAgICBvdXQuYXBwZW5kKCJodHRwOi8vJXMvKiIgJSBoKQogICAgICAgIG91dC5hcHBlbmQoImh0dHBzOi8vJXMvKiIgJSBoKQogICAgcmV0dXJuIG91dAoKCmRlZiBidWlsZChjZmcpOgogICAgbW9kZSA9IGNmZy5nZXQoIm1vZGUiLCAiYWxsb3ciKQogICAgc2l0ZXMgPSBjZmcuZ2V0KCJzaXRlcyIsIFtdKQogICAgaWYgaXNpbnN0YW5jZShzaXRlcywgc3RyKTogICAgICAgICAgIyBndWFyZCBhZ2FpbnN0IGEgc2luZ2xlLXNpdGUgbGlzdAogICAgICAgIHNpdGVzID0gW3NpdGVzXQogICAgc2l0ZXMgPSBzb3J0ZWQoe3Muc3RyaXAoKS5sb3dlcigpIGZvciBzIGluIHNpdGVzIGlmIHMuc3RyaXAoKX0pCgogICAgIyBUaGUgaHViIHBhZ2UgaXMgZ2VuZXJhdGVkIGZyb20gdGhlIHNhbWUgbGlzdCB0aGF0IGlzIGVuZm9yY2VkLCBzbyB0aGUgcGFnZQogICAgIyBhIGNoaWxkIHNlZXMgY2FuIG5ldmVyIGRpc2FncmVlIHdpdGggd2hhdCB0aGUgcG9saWN5IGFjdHVhbGx5IGFsbG93cy4KICAgIHdyaXRlX2h1YihjZmcsIHNpdGVzLCBtb2RlKQoKICAgIGV4Y2VwdGlvbnMgPSBbImh0dHA6Ly9sb2NhbGhvc3QvKiIsICJodHRwczovL2xvY2FsaG9zdC8qIiwKICAgICAgICAgICAgICAgICAgImh0dHA6Ly8xMjcuMC4wLjEvKiIsICJodHRwczovLzEyNy4wLjAuMS8qIl0KICAgIGJsb2NrID0gW10KCiAgICBpZiBtb2RlID09ICJibG9jayI6CiAgICAgICAgZm9yIHMgaW4gc2l0ZXM6CiAgICAgICAgICAgIGJsb2NrLmV4dGVuZChwYXR0ZXJucyhzKSkKICAgIGVsc2U6CiAgICAgICAgZm9yIHMgaW4gc2l0ZXM6CiAgICAgICAgICAgIGV4Y2VwdGlvbnMuZXh0ZW5kKHBhdHRlcm5zKHMpKQogICAgICAgIGJsb2NrID0gWyI8YWxsX3VybHM+Il0KCiAgICByZXR1cm4gewogICAgICAgICJwb2xpY2llcyI6IHsKICAgICAgICAgICAgIldlYnNpdGVGaWx0ZXIiOiB7IkJsb2NrIjogYmxvY2ssICJFeGNlcHRpb25zIjogZXhjZXB0aW9uc30sCiAgICAgICAgICAgICJCbG9ja0Fib3V0Q29uZmlnIjogVHJ1ZSwKICAgICAgICAgICAgIkRpc2FibGVEZXZlbG9wZXJUb29scyI6IFRydWUsCiAgICAgICAgICAgICJEaXNhYmxlUHJpdmF0ZUJyb3dzaW5nIjogVHJ1ZSwKICAgICAgICAgICAgIkRpc2FibGVGaXJlZm94QWNjb3VudHMiOiBUcnVlLAogICAgICAgICAgICAiRGlzYWJsZUZpcmVmb3hTdHVkaWVzIjogVHJ1ZSwKICAgICAgICAgICAgIkRpc2FibGVQb2NrZXQiOiBUcnVlLAogICAgICAgICAgICAiRGlzYWJsZVRlbGVtZXRyeSI6IFRydWUsCiAgICAgICAgICAgICJEaXNhYmxlRmVlZGJhY2tDb21tYW5kcyI6IFRydWUsCiAgICAgICAgICAgICJEb250Q2hlY2tEZWZhdWx0QnJvd3NlciI6IFRydWUsCiAgICAgICAgICAgICJEaXNwbGF5Qm9va21hcmtzVG9vbGJhciI6IEZhbHNlLAogICAgICAgICAgICAiT2ZmZXJUb1NhdmVMb2dpbnMiOiBGYWxzZSwKICAgICAgICAgICAgIlBhc3N3b3JkTWFuYWdlckVuYWJsZWQiOiBGYWxzZSwKICAgICAgICAgICAgIlNlYXJjaFN1Z2dlc3RFbmFibGVkIjogRmFsc2UsCiAgICAgICAgICAgICJPdmVycmlkZUZpcnN0UnVuUGFnZSI6ICIiLAogICAgICAgICAgICAiT3ZlcnJpZGVQb3N0VXBkYXRlUGFnZSI6ICIiLAogICAgICAgICAgICAiUHJlZmVyZW5jZXMiOiB7CiAgICAgICAgICAgICAgICAiYnJvd3Nlci5hYm91dHdlbGNvbWUuZW5hYmxlZCI6IEZhbHNlLAogICAgICAgICAgICAgICAgImJyb3dzZXIuc2Vzc2lvbnN0b3JlLnJlc3VtZV9mcm9tX2NyYXNoIjogRmFsc2UsCiAgICAgICAgICAgICAgICAiYnJvd3Nlci50YWJzLndhcm5PbkNsb3NlIjogRmFsc2UsCiAgICAgICAgICAgICAgICAidG9vbGtpdC50ZWxlbWV0cnkuZW5hYmxlZCI6IEZhbHNlLAogICAgICAgICAgICAgICAgImRhdGFyZXBvcnRpbmcucG9saWN5LmRhdGFTdWJtaXNzaW9uRW5hYmxlZCI6IEZhbHNlLAogICAgICAgICAgICAgICAgImFwcC51cGRhdGUuYXV0byI6IEZhbHNlLAogICAgICAgICAgICB9LAogICAgICAgIH0KICAgIH0KCgpkZWYgbWFpbigpOgogICAgb3MubWFrZWRpcnMoQkFTRSwgZXhpc3Rfb2s9VHJ1ZSkKCiAgICBpZiBsZW4oc3lzLmFyZ3YpID4gMToKICAgICAgICBjZmcgPSBqc29uLmxvYWRzKGJhc2U2NC5iNjRkZWNvZGUoc3lzLmFyZ3ZbMV0pLmRlY29kZSgidXRmLTgiKSkKICAgICAgICB3aXRoIG9wZW4oUEFSRU5ULCAidyIpIGFzIGZoOiAgICAgICAgICAjIGluLXBsYWNlOiBrZWVwcyB0aGUgYmluZCBtb3VudCB2YWxpZAogICAgICAgICAgICBqc29uLmR1bXAoY2ZnLCBmaCwgaW5kZW50PTIpCiAgICBlbGlmIG9zLnBhdGguZXhpc3RzKFBBUkVOVCk6CiAgICAgICAgd2l0aCBvcGVuKFBBUkVOVCkgYXMgZmg6CiAgICAgICAgICAgIGNmZyA9IGpzb24ubG9hZChmaCkKICAgIGVsc2U6CiAgICAgICAgY2ZnID0gREVGQVVMVAogICAgICAgIHdpdGggb3BlbihQQVJFTlQsICJ3IikgYXMgZmg6CiAgICAgICAgICAgIGpzb24uZHVtcChjZmcsIGZoLCBpbmRlbnQ9MikKCiAgICB3aXRoIG9wZW4oRklSRUZPWCwgInciKSBhcyBmaDoKICAgICAgICBqc29uLmR1bXAoYnVpbGQoY2ZnKSwgZmgsIGluZGVudD0yKQoKICAgIHNpdGVzID0gY2ZnLmdldCgic2l0ZXMiLCBbXSkKICAgIGlmIGlzaW5zdGFuY2Uoc2l0ZXMsIHN0cik6CiAgICAgICAgc2l0ZXMgPSBbc2l0ZXNdCiAgICBwcmludCgiQ1lCRVJTSElFTERfT0sgc2l0ZXM9JWQgbW9kZT0lcyIgJSAobGVuKHNpdGVzKSwgY2ZnLmdldCgibW9kZSIsICJhbGxvdyIpKSkKCgppZiBfX25hbWVfXyA9PSAiX19tYWluX18iOgogICAgbWFpbigpClBZCgojIGdlbmVyYXRlIHBvbGljeS5qc29uIChkZWZhdWx0cyBvbiBmaXJzdCBydW4pICsgcG9saWNpZXMuanNvbiBmb3IgRmlyZWZveApweXRob24zICIkRElSL3dyaXRlX3BvbGljeS5weSIKY3AgIiRESVIvcG9saWNpZXMuanNvbiIgIiRCVUlMRC9wb2xpY2llcy5qc29uIgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KIyAyLiBQb3J0YWwgcGFnZSAtIHNlcnZlZCBieSB0aGUgY29udGFpbmVyJ3MgbmdpbnggYXQgL3N0YXJ0Lmh0bWwKIwojIFRoaXMgaXMgb25seSB0aGUgZmFsbGJhY2sgdXNlZCBpZiB0aGUgZ2VuZXJhdG9yIGFib3ZlIGhhcyBub3QgcnVuIHlldC4gVGhlCiMgcmVhbCBwYWdlIGlzIHdyaXR0ZW4gYnkgd3JpdGVfcG9saWN5LnB5IGZyb20gdGhlIHBhcmVudCdzIGFjdHVhbCBsaXN0LCBzbyBpdAojIGFsd2F5cyBtYXRjaGVzIHRoZSBwb2xpY3kgdGhhdCBpcyBlbmZvcmNlZC4KIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KY2F0ID4gIiRESVIvc3RhcnQuaHRtbCIgPDwnSFRNTCcKPCFkb2N0eXBlIGh0bWw+PGh0bWw+PGhlYWQ+PG1ldGEgY2hhcnNldD0idXRmLTgiPjx0aXRsZT5DeWJlcnNoaWVsZDwvdGl0bGU+CjxzdHlsZT4KIGJvZHl7bWFyZ2luOjA7Zm9udDoxNnB4IHN5c3RlbS11aSxzYW5zLXNlcmlmO2JhY2tncm91bmQ6IzBiMTAyMDtjb2xvcjojZThlY2Y3OwogICAgICBkaXNwbGF5OmZsZXg7ZmxleC1kaXJlY3Rpb246Y29sdW1uO2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO2hlaWdodDoxMDB2aH0KIGgxe21hcmdpbjowIDAgNHB4O2ZvbnQtc2l6ZTozNHB4O2xldHRlci1zcGFjaW5nOi0uNXB4fQogcHttYXJnaW46MCAwIDM2cHg7Y29sb3I6IzhiOTdiOH0KIC5ncmlke2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6MWZyIDFmcjtnYXA6MTRweDt3aWR0aDptaW4oNzYwcHgsOTB2dyl9CiBhe3BhZGRpbmc6MjJweCAyMHB4O2JvcmRlci1yYWRpdXM6MTJweDt0ZXh0LWRlY29yYXRpb246bm9uZTtmb250LXdlaWdodDo2MDA7CiAgIGRpc3BsYXk6ZmxleDtqdXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjthbGlnbi1pdGVtczpjZW50ZXJ9CiAub2t7YmFja2dyb3VuZDojMTIzMzFmO2NvbG9yOiM3ZWYyYTg7Ym9yZGVyOjFweCBzb2xpZCAjMWU1YzM3fQogLm5ve2JhY2tncm91bmQ6IzMzMTIxYTtjb2xvcjojZmY4ZmEzO2JvcmRlcjoxcHggc29saWQgIzVlMWUyYX0KIHNtYWxse2ZvbnQtd2VpZ2h0OjQwMDtvcGFjaXR5Oi43fQo8L3N0eWxlPjwvaGVhZD48Ym9keT4KPGgxPlNUQUkgQ3liZXJzaGllbGQ8L2gxPgo8cD5NYW5hZ2VkIGxvY2tlZCBzZXNzaW9uICZtZGFzaDsgdGhlIHBhcmVudCBkZWNpZGVzIHdoYXQgaXMgcmVhY2hhYmxlPC9wPgo8ZGl2IGNsYXNzPSJncmlkIj4KICA8YSBjbGFzcz0ib2siIGhyZWY9Imh0dHBzOi8vZW4ud2lraXBlZGlhLm9yZy93aWtpL0NvbXB1dGVyX3NlY3VyaXR5Ij5BbGxvd2VkIDxzbWFsbD53aWtpcGVkaWEub3JnPC9zbWFsbD48L2E+CiAgPGEgY2xhc3M9Im9rIiBocmVmPSJodHRwczovL3d3dy5raGFuYWNhZGVteS5vcmcvIj5BbGxvd2VkIDxzbWFsbD5raGFuYWNhZGVteS5vcmc8L3NtYWxsPjwvYT4KICA8YSBjbGFzcz0ibm8iIGhyZWY9Imh0dHBzOi8vd3d3LnlvdXR1YmUuY29tLyI+QkxPQ0tFRCA8c21hbGw+eW91dHViZS5jb208L3NtYWxsPjwvYT4KICA8YSBjbGFzcz0ibm8iIGhyZWY9Imh0dHBzOi8vd3d3LnJlZGRpdC5jb20vIj5CTE9DS0VEIDxzbWFsbD5yZWRkaXQuY29tPC9zbWFsbD48L2E+CjwvZGl2Pgo8L2JvZHk+PC9odG1sPgpIVE1MCgojIHRoZSBnZW5lcmF0b3Igb3ducyBzdGFydC5odG1sIGZyb20gaGVyZSBvbgpweXRob24zICIkRElSL3dyaXRlX3BvbGljeS5weSIKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgMy4gU2Vzc2lvbiBsYXVuY2hlcgojCiMgQSBub3JtYWwgRmlyZWZveCB3aW5kb3csIG1heGltaXNlZCAtIE5PVCAtLWtpb3NrLiBLaW9zayBtb2RlIGhpZGVzIHRoZSB3aG9sZQojIGJyb3dzZXIgVUksIGFuZCB0aGVuIHRoZXJlIGlzIG5vIGJhY2sgYnV0dG9uLCBubyByZWxvYWQgYW5kIG5vIGFkZHJlc3MgYmFyLCBzbwojIGEgY2hpbGQgY2FuIG9ubHkgZXZlciBjbGljayBsaW5rcyBvbiB0aGUgcGFnZSBpbiBmcm9udCBvZiB0aGVtLiBXaXRoIHRoZSByZWFsCiMgdG9vbGJhciB2aXNpYmxlIHRoZSBicm93c2VyIGlzIG5hdmlnYWJsZTsgdGhlIFdlYnNpdGVGaWx0ZXIgcG9saWN5IGlzIHdoYXQKIyBrZWVwcyBpdCBsb2NrZWQsIG5vdCB0aGUgYWJzZW5jZSBvZiBidXR0b25zLgojCiMgd21jdHJsIChpbnN0YWxsZWQgaW4gdGhlIGltYWdlKSB0ZWxscyBvcGVuYm94IHRvIG1heGltaXNlIHRoZSB3aW5kb3cuIElmIHRoYXQKIyBldmVyIGZhaWxzIHRoZSB3aW5kb3cgaXMgc3RpbGwgYSBub3JtYWwgb25lIC0ganVzdCBub3QgZnVsbC1zY3JlZW4uCiMKIyBGaXJlZm94IGlzIHJlc3RhcnRlZCBpZiBpdCBpcyBjbG9zZWQ6IG5vIHBhbmVsLCBubyBkZXNrdG9wLCBhbmQgY2xvc2luZyB0aGUKIyB3aW5kb3cgc2hvdWxkIG5vdCBsZWF2ZSBhIGJsYW5rIG1hY2hpbmUuCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCmNhdCA+ICIkRElSL2ZpcmVmb3gtc2Vzc2lvbiIgPDwnS0lPU0snCiMhL2Jpbi9zaApmb3IgXyBpbiAkKHNlcSAxIDMwKTsgZG8geGRweWluZm8gLWRpc3BsYXkgOjEgPi9kZXYvbnVsbCAyPiYxICYmIGJyZWFrOyBzbGVlcCAxOyBkb25lCnNsZWVwIDMKd2hpbGUgOjsgZG8KICAvdXNyL2Jpbi9maXJlZm94IC0tbmV3LWluc3RhbmNlIGh0dHA6Ly9sb2NhbGhvc3Qvc3RhcnQuaHRtbCAmCiAgZmY9JCEKICBpPTAKICB3aGlsZSBbICRpIC1sdCA0NSBdOyBkbwogICAgaWRzPSQod21jdHJsIC1seCAyPi9kZXYvbnVsbCB8IGF3ayAndG9sb3dlcigkMCkgfiAvZmlyZWZveC8ge3ByaW50ICQxfScpCiAgICBbIC1uICIkaWRzIiBdICYmIGJyZWFrCiAgICBzbGVlcCAxCiAgICBpPSQoKGkgKyAxKSkKICBkb25lCiAgZm9yIGlkIGluICRpZHM7IGRvCiAgICB3bWN0cmwgLWkgLXIgIiRpZCIgLWIgYWRkLG1heGltaXplZF92ZXJ0LG1heGltaXplZF9ob3J6CiAgZG9uZQogIHdhaXQgJGZmCiAgc2xlZXAgMgpkb25lCktJT1NLCmNobW9kICt4ICIkRElSL2ZpcmVmb3gtc2Vzc2lvbiIKCmNwICIkRElSL3N0YXJ0Lmh0bWwiICIkQlVJTEQvc3RhcnQuaHRtbCIKY3AgIiRESVIvZmlyZWZveC1zZXNzaW9uIiAiJEJVSUxEL2ZpcmVmb3gtc2Vzc2lvbiIKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgNC4gSW1hZ2UKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0KY2F0ID4gIiRCVUlMRC9Eb2NrZXJmaWxlIiA8PCdET0NLRVJGSUxFJwpGUk9NIHdlbm9wdGljcy91YnVudHUtZGVza3RvcC1ub3ZuYzpsYXRlc3QKCiMgc21vb3RoZXIgb24gQ2xvdWQgU2hlbGwncyBzaGFyZWQgdkNQVQpSVU4gcHJpbnRmICcjIS9iaW4vc2hcblJFUz0iJHtSRVNPTFVUSU9OOi0xMjgweDcyMH0iXG5leGVjIC91c3IvYmluL1h2ZmIgOjEgLXNjcmVlbiAwICIke1JFU314MTYiXG4nIFwKICAgICAgPiAvdXNyL2xvY2FsL2Jpbi94dmZiLnNoICYmIGNobW9kICt4IC91c3IvbG9jYWwvYmluL3h2ZmIuc2gKUlVOIHNlZCAtaSAncyNeY29tbWFuZD14MTF2bmMgLiojJiAtbm93ZiMnIC9ldGMvc3VwZXJ2aXNvci9jb25mLmQvc3VwZXJ2aXNvcmQuY29uZgoKIyBGaXJlZm94IGlzIHRoZSBPTkxZIGJyb3dzZXIgaW4gdGhpcyBtYWNoaW5lClJVTiBhcHQtZ2V0IHB1cmdlIC15IGdvb2dsZS1jaHJvbWUtc3RhYmxlIHx8IHRydWUKUlVOIHJtIC1mIC9ldGMvYXB0L3NvdXJjZXMubGlzdC5kL2dvb2dsZS1jaHJvbWUubGlzdCBcCiAgICAgICAgICAvdXNyL3NoYXJlL2FwcGxpY2F0aW9ucy9nb29nbGUtY2hyb21lLmRlc2t0b3AgXAogICAgICAgICAgL3Vzci9zaGFyZS9hcHBsaWNhdGlvbnMvY2hyb21pdW0tYnJvd3Nlci1zb3VuZC5kZXNrdG9wIFwKICAgICAgICAgIC91c3IvbG9jYWwvYmluL2Nocm9taXVtLWJyb3dzZXItc291bmQuc2ggXAogICAgICAgICAgL3Vzci9sb2NhbC9iaW4vY2hyb21lLWdvb2QKCiMgd21jdHJsIGxldHMgdGhlIHNlc3Npb24gbGF1bmNoZXIgbWF4aW1pc2UgdGhlIEZpcmVmb3ggd2luZG93LiBJbnN0YWxsZWQgb25seQojIEFGVEVSIHRoZSBkZWFkIGdvb2dsZS1jaHJvbWUgYXB0IHNvdXJjZSBpcyBnb25lIC0gd2l0aCBpdCBwcmVzZW50LCBhcHQtZ2V0CiMgdXBkYXRlIGRpZXMgb24gInJlcG9zaXRvcnkgaXMgbm90IHNpZ25lZCIgKE5PX1BVQktFWSBGRDUzM0MwN0MyNjQ2NDhGKSBhbmQKIyB0YWtlcyB0aGUgd2hvbGUgYnVpbGQgZG93biB3aXRoIGl0LgpSVU4gYXB0LWdldCB1cGRhdGUgXAogJiYgYXB0LWdldCBpbnN0YWxsIC15IC0tbm8taW5zdGFsbC1yZWNvbW1lbmRzIHdtY3RybCBcCiAmJiBybSAtcmYgL3Zhci9saWIvYXB0L2xpc3RzLyoKCiMgRmFsbGJhY2sgcG9saWN5LCBiYWtlZCBpbiBzbyBhIGJhcmUgYGRvY2tlciBydW5gIGlzIG5ldmVyIHdpZGUgb3Blbi4KIyBBdCBub3JtYWwgcnVudGltZSB0aGlzIGlzIHJlcGxhY2VkIGJ5IHRoZSBwYXJlbnQncyBsaXN0IHZpYSBhIGJpbmQgbW91bnQuCkNPUFkgcG9saWNpZXMuanNvbiAvZXRjL2ZpcmVmb3gvcG9saWNpZXMvcG9saWNpZXMuanNvbgoKIyBwb3J0YWwgcGFnZQpDT1BZIHN0YXJ0Lmh0bWwgL3Vzci9sb2NhbC9saWIvd2ViL2Zyb250ZW5kL3N0YXJ0Lmh0bWwKCiMgTm8gdGFza2JhciBhbmQgbm8gZGVza3RvcCBpY29uczogdGFrZSBseHBhbmVsIGFuZCBwY21hbmZtIG91dCBvZiBzdXBlcnZpc29yZAojIGNvbXBsZXRlbHksIHNvIGFsbCB0aGF0IGlzIGxlZnQgb24gdGhlIHNjcmVlbiBpcyB0aGUga2lvc2sgYnJvd3Nlci4KIwojIERvIE5PVCBkbyB0aGlzIGJ5IHBvaW50aW5nIGx4cGFuZWwgYXQgL2Jpbi90cnVlOiB0aGUgcHJvY2VzcyB0aGVuIGV4aXRzCiMgaW1tZWRpYXRlbHkgb24gZXZlcnkgc3RhcnQgYW5kIHN1cGVydmlzb3JkIHBhcmtzIGl0IGluIGEgRkFUQUwgYmFjay1vZmYgbG9vcC4KIyBgc3VwZXJ2aXNvcmN0bCBzdGF0dXNgIHRoZW4gZXhpdHMgMywgdGhlIGltYWdlJ3Mgb3duIC9hcGkvaGVhbHRoIHJldHVybnMgNTAwLAojIGFuZCB0aGF0IGVuZHBvaW50IGlzIGV4YWN0bHkgd2hhdCB0aGUgaW1hZ2UncyBIRUFMVEhDSEVDSyBjYWxscyAtIHNvIHRoZQojIGNvbnRhaW5lciBzaXRzIGF0ICJ1bmhlYWx0aHkiIGZvcmV2ZXIgYW5kIGV2ZXJ5IExhdW5jaCB3YWl0cyBvdXQgdGhlIHdob2xlCiMgaGVhbHRoIHRpbWVvdXQuClJVTiBzZWQgLWkgXAogICAgICAtZSAnL15cW3Byb2dyYW06bHhwYW5lbFxdLywvXlxbcHJvZ3JhbTpwY21hbmZtXF0vey9eXFtwcm9ncmFtOnBjbWFuZm1cXS8hZH0nIFwKICAgICAgLWUgJy9eXFtwcm9ncmFtOnBjbWFuZm1cXS8sL15cW3Byb2dyYW06eHZmYlxdL3svXlxbcHJvZ3JhbTp4dmZiXF0vIWR9JyBcCiAgICAgIC1lICdzL15wcm9ncmFtcz14dmZiLHdtLGx4cGFuZWwscGNtYW5mbSx4MTF2bmMsbm92bmMkL3Byb2dyYW1zPXh2ZmIsd20seDExdm5jLG5vdm5jLycgXAogICAgICAvZXRjL3N1cGVydmlzb3IvY29uZi5kL3N1cGVydmlzb3JkLmNvbmYKCiMgbWF4aW1pc2VkIEZpcmVmb3ggd2l0aCBpdHMgbm9ybWFsIHRvb2xiYXIsIHN0YXJ0ZWQgb25jZSBYIGlzIHVwCkNPUFkgZmlyZWZveC1zZXNzaW9uIC91c3IvbG9jYWwvYmluL2ZpcmVmb3gtc2Vzc2lvbgpSVU4gY2htb2QgK3ggL3Vzci9sb2NhbC9iaW4vZmlyZWZveC1zZXNzaW9uIFwKICYmIHByaW50ZiAnXG5bcHJvZ3JhbTpjeWJlcnNoaWVsZF1cbnByaW9yaXR5PTMwXG5kaXJlY3Rvcnk9L3Jvb3RcbmNvbW1hbmQ9L3Vzci9sb2NhbC9iaW4vZmlyZWZveC1zZXNzaW9uXG5lbnZpcm9ubWVudD1ESVNQTEFZPSI6MSIsSE9NRT0iL3Jvb3QiLFVTRVI9InJvb3QiXG5zdGFydHNlY3M9NVxuJyBcCiAgICAgID4+IC9ldGMvc3VwZXJ2aXNvci9jb25mLmQvc3VwZXJ2aXNvcmQuY29uZgoKIyBBIGNvbnRhaW5lciByZXN0YXJ0IGtlZXBzIHRoZSBmaWxlc3lzdGVtLCBzbyBYdmZiJ3MgbG9jayBmaWxlIGFuZCBpdHMgc29ja2V0CiMgc3Vydml2ZSBmcm9tIHRoZSBydW4gYmVmb3JlLiBYdmZiIHRoZW4gcmVmdXNlcyB0byBzdGFydCAtICJTZXJ2ZXIgaXMgYWxyZWFkeQojIGFjdGl2ZSBmb3IgZGlzcGxheSAxIiAtIGFuZCBiZWNhdXNlIEZpcmVmb3ggd2FpdHMgZm9yIHRoYXQgZGlzcGxheSwgdGhlIHdob2xlCiMgc2Vzc2lvbiBjb21lcyB1cCBkZWFkLiBUaGF0IG1hZGUgZXZlcnkgUmVzZXQgKGFuZCBldmVyeSBMYXVuY2ggb2YgYW4gZXhpc3RpbmcKIyBzZXNzaW9uKSBzaG93IGEgYmxhbmsgc2NyZWVuLCBzbyBjbGVhciB0aGVtIGZpcnN0LgpSVU4gcHJpbnRmICcjIS9iaW4vc2hcbnJtIC1mIC90bXAvLlgxLWxvY2sgL3RtcC8uWDExLXVuaXgvWDFcbmV4ZWMgL3Vzci9iaW4vWHZmYiA6MSAtc2NyZWVuIDAgMTI4MHg3MjB4MjQgLWFjICtleHRlbnNpb24gR0xYICtyZW5kZXIgLW5vcmVzZXRcbicgPiAvdXNyL2xvY2FsL2Jpbi94dmZiLnNoIFwKICYmIGNobW9kICt4IC91c3IvbG9jYWwvYmluL3h2ZmIuc2gKCiMgd2hpY2ggRmlyZWZveCBkaWQgd2UgZ2V0PyAoaWYgdGhpcyBwcmludHMgInNuYXAiLCB0ZWxsIG1lKQpSVU4gL3Vzci9iaW4vZmlyZWZveCAtLXZlcnNpb24gMj4mMSB8IGhlYWQgLTEgfHwgdHJ1ZQpET0NLRVJGSUxFCgojIFJlYnVpbGQgd2hlbiB0aGUgZmlsZXMgdGhhdCBERUZJTkUgdGhlIGltYWdlIGNoYW5nZSwgbm90IG9ubHkgd2hlbiB0aGUgaW1hZ2UgaXMKIyBtaXNzaW5nLiBPdGhlcndpc2UgYSBtYWNoaW5lIHRoYXQgYWxyZWFkeSBoYXMgYW4gb2xkZXIgYnVpbGQgKG5vIHRvb2xiYXIsIG9sZAojIGtpb3NrIGxhdW5jaGVyKSBrZWVwcyBydW5uaW5nIGl0IGZvcmV2ZXIgLSB0aGUgaW1hZ2UgdGFnIGFsb25lIG5ldmVyIGNoYW5nZXMuCkJVSUxEX0lEPSQoY2F0ICIkQlVJTEQvRG9ja2VyZmlsZSIgIiRCVUlMRC9maXJlZm94LXNlc3Npb24iIHwgbWQ1c3VtIHwgY3V0IC1jMS0xMikKSEFWRV9JRD0kKCRET0NLRVIgaW1hZ2UgaW5zcGVjdCAtZiAne3tpbmRleCAuQ29uZmlnLkxhYmVscyAiY3liZXJzaGllbGQuYnVpbGQifX0nICIkSU1BR0UiIDI+L2Rldi9udWxsIHx8IHRydWUpCmlmIFsgIiRIQVZFX0lEIiAhPSAiJEJVSUxEX0lEIiBdOyB0aGVuCiAgZWNobyAiPT0gYnVpbGRpbmcgJElNQUdFIChmaXJzdCBydW4gcHVsbHMgfjIgR0IgLSBkbyB0aGlzIEJFRk9SRSB0aGUgZGVtbykgPT0iCiAgJERPQ0tFUiBidWlsZCAtLWxhYmVsICJjeWJlcnNoaWVsZC5idWlsZD0kQlVJTERfSUQiIC10ICIkSU1BR0UiICIkQlVJTEQiCmZpCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQojIDUuIFJ1bi4gVGhlIHBhcmVudCdzIGxpc3QgaXMgYmluZC1tb3VudGVkIGluLCBzbyBjaGFuZ2luZyBpdCBvbmx5IG5lZWRzIGEKIyAgICBjb250YWluZXIgcmVzdGFydCAtIG5vIHJlYnVpbGQuCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiRET0NLRVIgcm0gLWYgIiROQU1FIiA+L2Rldi9udWxsIDI+JjEgfHwgdHJ1ZQokRE9DS0VSIHJ1biAtZCAtLW5hbWUgIiROQU1FIiAtLXNobS1zaXplPTFnIC1wIDYwODA6ODAgXAogIC12ICIkRElSL3BvbGljaWVzLmpzb24iOi9ldGMvZmlyZWZveC9wb2xpY2llcy9wb2xpY2llcy5qc29uOnJvIFwKICAtdiAiJERJUi9zdGFydC5odG1sIjovdXNyL2xvY2FsL2xpYi93ZWIvZnJvbnRlbmQvc3RhcnQuaHRtbDpybyBcCiAgIiRJTUFHRSIgPi9kZXYvbnVsbAoKcHJpbnRmICc9PSB3YWl0aW5nIGZvciBzZXNzaW9uJwpmb3IgXyBpbiAkKHNlcSAxIDYwKTsgZG8KICBzdD0kKCRET0NLRVIgaW5zcGVjdCAtZiAne3tpZiAuU3RhdGUuSGVhbHRofX17ey5TdGF0ZS5IZWFsdGguU3RhdHVzfX17e2Vsc2V9fW5vaGN7e2VuZH19JyAiJE5BTUUiIDI+L2Rldi9udWxsIHx8IGVjaG8geCkKICBjYXNlICIkc3QiIGluIGhlYWx0aHl8bm9oYykgYnJlYWs7OyBlc2FjCiAgcHJpbnRmICcuJzsgc2xlZXAgMgpkb25lCmVjaG8gIiAoJHN0KSIKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgNi4gQXV0by1zdGFydCBvbiBldmVyeSBmcmVzaCBDbG91ZCBTaGVsbCBWTQojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLQpjYXQgPiAiJEhPTUUvLmN1c3RvbWl6ZV9lbnZpcm9ubWVudCIgPDxFT0YKIyEvYmluL2Jhc2gKYmFzaCAiJERJUi9zZXR1cC5zaCIgPj4iJERJUi9ib290LmxvZyIgMj4mMQpFT0YKY2htb2QgK3ggIiRIT01FLy5jdXN0b21pemVfZW52aXJvbm1lbnQiCgplY2hvCmVjaG8gIiAgaW5zdGFsbGVkIGluID0gJERJUiIKZWNobyAiICBob3N0ICAgICAgICAgPSAkV0VCX0hPU1QiCmVjaG8gIiAgb3BlbiAgICAgICAgID0gaHR0cHM6Ly82MDgwLSRXRUJfSE9TVC8/cXVhbGl0eT0yJmNvbXByZXNzaW9uPTEmc2NhbGluZ01vZGU9c2NhbGUmY2xpcFRvV2luZG93PXRydWUmZG90Q3Vyc29yPXRydWUiCmVjaG8KQ1lCRVJTSElFTERfU0VUVVBfRU9GCgpiYXNoICIkSE9NRS9jeWJlcnNoaWVsZC9zZXR1cC5zaCIK'

$script:ps          = $null
$script:handle      = $null
$script:marker      = ''
$script:lastUrl     = ''
$script:Gcloud      = $null
$script:SetupAction = 'install'
$script:Account     = ''

# Progress is published from the worker runspace and read here on the UI
# thread, so it has to be a shared, thread-safe object.
$script:Progress = [hashtable]::Synchronized(@{
    phase   = ''
    detail  = ''
    percent = -1
    read    = 0
    total   = 0
})

$script:JobStart   = Get-Date
$script:LastSample = Get-Date
$script:LastRead   = 0
$script:SpeedBps   = 0
$script:MarqueePos = -140

# ------------------------------------------------------------ gcloud lookup -
function Find-Gcloud {
    # Prefer gcloud.cmd / gcloud.exe, and deliberately NEVER gcloud.ps1.
    # The SDK installer puts its bin folder on PATH, and that folder ships
    # gcloud, gcloud.cmd AND gcloud.ps1 - PowerShell's Get-Command prefers the
    # .ps1. Handing a .ps1 to Start-Process goes to the file association, which
    # on a machine with no .ps1 association is a "How do you want to open this
    # file?" dialog rather than a gcloud run.
    foreach ($dir in @($env:Path -split ';')) {
        if (-not $dir) { continue }
        $d = $dir.Trim().Trim('"')
        if (-not $d -or $d.Contains('%')) { continue }   # skip unexpanded %VARS%
        foreach ($n in @('gcloud.cmd', 'gcloud.exe')) {
            try {
                $p = Join-Path $d $n
                if (Test-Path $p) { return $p }
            } catch { }
        }
    }

    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)
    foreach ($r in $roots) {
        if (-not $r) { continue }
        foreach ($rel in @('Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd',
                           'Google\CloudSDK\google-cloud-sdk\bin\gcloud.cmd')) {
            $p = Join-Path $r $rel
            if (Test-Path $p) { return $p }
        }
    }

    # last resort: whatever the shell resolves, as long as it is not a .ps1
    $cmd = @(Get-Command gcloud -ErrorAction SilentlyContinue) |
           Where-Object { $_.Source -and $_.Source -notlike '*.ps1' } |
           Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Refresh-Path {
    try {
        $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $u = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($m -or $u) { $env:Path = "$m;$u" }
    } catch { }
}

# Open the session in a chromeless app window when Edge or Chrome is available.
#
# The outer window is only a viewer for the Cloud Shell machine. Its back
# button, reload and address bar drive THIS PC, not the locked browser inside -
# and typing in them takes the person out of the protected session entirely.
# An app window has no address bar, no tabs and no back button, so the only
# browser controls on screen are the ones inside the session, which are the
# ones the policy governs. Falls back to the default browser if neither is here.
function Open-Session([string]$url) {
    if (-not $url) { return }
    $candidates = @()
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe') }
    if ($env:ProgramFiles)        { $candidates += (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe') }
    if ($env:ProgramFiles)        { $candidates += (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe') }
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe') }

    foreach ($exe in $candidates) {
        if (-not (Test-Path $exe)) { continue }
        try {
            Start-Process -FilePath $exe -ArgumentList ('--app=' + $url)
            return
        } catch { }
    }
    Start-Process $url
}

# winget downloads the package into %TEMP%\WinGet before installing it. Watching
# that folder gives a real "bytes downloaded" number even though winget itself
# keeps its own progress bar to itself.
function Get-WingetBytes {
    $t = Join-Path $env:TEMP 'WinGet'
    if (-not (Test-Path $t)) { return 0 }
    try {
        $sum = (Get-ChildItem $t -Recurse -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        if ($sum) { return [int64]$sum }
    } catch { }
    return 0
}

# ------------------------------------------------------ local config file ---
$base = $PSScriptRoot
if (-not $base) {
    $exe = $null
    try { $exe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch { }
    if ($exe -and (Split-Path -Leaf $exe) -notmatch '^powershell(_ise)?\.exe$') {
        $base = Split-Path -Parent $exe
    }
}
if (-not $base) { $base = $env:USERPROFILE }
$script:CfgPath = Join-Path $base 'cybershield-sites.json'
$script:LogPath = Join-Path $base 'cybershield.log'

# A plain-text record of every action, next to the .exe, so a demo failure can be
# explained afterwards instead of guessed at. Written from both the UI thread and
# the worker runspace, hence the lock; logging must never be able to crash the
# app, so every failure here is swallowed on purpose.
$script:LogLock = New-Object object

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    try {
        [Threading.Monitor]::Enter($script:LogLock)
        try {
            $line = '{0}  {1,-5}  {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Message
            Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
        }
        finally { [Threading.Monitor]::Exit($script:LogLock) }
    } catch { }
}

function Normalize-Site([string]$s) {
    $s = $s.Trim().ToLower()
    $s = $s -replace '^[a-z]+://', ''   # strip https://
    $s = $s -replace '/.*$', ''         # strip path
    $s = $s -replace '^www\.', ''       # wildcard covers www anyway
    $s = $s.Trim('.')
    return $s
}

# ------------------------------------------------------------------- UI -----
$form = New-Object Windows.Forms.Form
$form.Text = 'STAI Cybershield'
$form.ClientSize = New-Object Drawing.Size(560, 540)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = [Drawing.Color]::FromArgb(11, 16, 32)
$form.ForeColor = [Drawing.Color]::FromArgb(232, 236, 247)
$form.Font = New-Object Drawing.Font('Segoe UI', 10)

$title = New-Object Windows.Forms.Label
$title.Text = 'STAI Cybershield'
$title.Font = New-Object Drawing.Font('Segoe UI', 16, [Drawing.FontStyle]::Bold)
$title.ForeColor = [Drawing.Color]::FromArgb(126, 242, 168)
$title.Location = New-Object Drawing.Point(20, 16)
$title.AutoSize = $true

$btnSetup = New-Object Windows.Forms.Button
$btnSetup.Text = 'Install Google CLI'
$btnSetup.Location = New-Object Drawing.Point(386, 20)
$btnSetup.Size = New-Object Drawing.Size(152, 30)
$btnSetup.FlatStyle = 'Flat'
$btnSetup.FlatAppearance.BorderSize = 0
$btnSetup.BackColor = [Drawing.Color]::FromArgb(24, 30, 50)
$btnSetup.ForeColor = [Drawing.Color]::FromArgb(200, 208, 230)

$sub = New-Object Windows.Forms.Label
$sub.Text = 'Pick the websites this session can reach.'
$sub.ForeColor = [Drawing.Color]::FromArgb(139, 151, 184)
$sub.Location = New-Object Drawing.Point(22, 50)
$sub.AutoSize = $true

$lblSites = New-Object Windows.Forms.Label
$lblSites.Text = 'Websites'
$lblSites.ForeColor = [Drawing.Color]::FromArgb(200, 208, 230)
$lblSites.Location = New-Object Drawing.Point(22, 84)
$lblSites.AutoSize = $true

$list = New-Object Windows.Forms.ListBox
$list.Location = New-Object Drawing.Point(22, 106)
$list.Size = New-Object Drawing.Size(516, 170)
$list.BackColor = [Drawing.Color]::FromArgb(17, 22, 40)
$list.ForeColor = [Drawing.Color]::FromArgb(232, 236, 247)
$list.BorderStyle = 'FixedSingle'

$txtSite = New-Object Windows.Forms.TextBox
$txtSite.Location = New-Object Drawing.Point(22, 288)
$txtSite.Size = New-Object Drawing.Size(330, 26)
$txtSite.BackColor = [Drawing.Color]::FromArgb(17, 22, 40)
$txtSite.ForeColor = [Drawing.Color]::FromArgb(232, 236, 247)
$txtSite.BorderStyle = 'FixedSingle'

$btnAdd = New-Object Windows.Forms.Button
$btnAdd.Text = 'Add'
$btnAdd.Location = New-Object Drawing.Point(362, 286)
$btnAdd.Size = New-Object Drawing.Size(80, 30)
$btnAdd.FlatStyle = 'Flat'
$btnAdd.FlatAppearance.BorderSize = 0
$btnAdd.BackColor = [Drawing.Color]::FromArgb(24, 30, 50)
$btnAdd.ForeColor = [Drawing.Color]::FromArgb(200, 208, 230)

$btnRemove = New-Object Windows.Forms.Button
$btnRemove.Text = 'Remove'
$btnRemove.Location = New-Object Drawing.Point(452, 286)
$btnRemove.Size = New-Object Drawing.Size(86, 30)
$btnRemove.FlatStyle = 'Flat'
$btnRemove.FlatAppearance.BorderSize = 0
$btnRemove.BackColor = [Drawing.Color]::FromArgb(24, 30, 50)
$btnRemove.ForeColor = [Drawing.Color]::FromArgb(200, 208, 230)

$rbAllow = New-Object Windows.Forms.RadioButton
$rbAllow.Text = 'Allow only these sites'
$rbAllow.Location = New-Object Drawing.Point(22, 328)
$rbAllow.AutoSize = $true
$rbAllow.ForeColor = [Drawing.Color]::FromArgb(200, 208, 230)

$rbBlock = New-Object Windows.Forms.RadioButton
$rbBlock.Text = 'Allow everything except these'
$rbBlock.Location = New-Object Drawing.Point(230, 328)
$rbBlock.AutoSize = $true
$rbBlock.ForeColor = [Drawing.Color]::FromArgb(200, 208, 230)

$hint = New-Object Windows.Forms.Label
$hint.Text = 'e.g. khanacademy.org, or paste a full link'
$hint.ForeColor = [Drawing.Color]::FromArgb(120, 130, 155)
$hint.Location = New-Object Drawing.Point(24, 354)
$hint.AutoSize = $true

$btnLaunch = New-Object Windows.Forms.Button
$btnLaunch.Text = 'Launch session'
$btnLaunch.Location = New-Object Drawing.Point(22, 384)
$btnLaunch.Size = New-Object Drawing.Size(200, 48)
$btnLaunch.FlatStyle = 'Flat'
$btnLaunch.FlatAppearance.BorderSize = 0
$btnLaunch.BackColor = [Drawing.Color]::FromArgb(18, 51, 31)
$btnLaunch.ForeColor = [Drawing.Color]::FromArgb(126, 242, 168)

$btnReset = New-Object Windows.Forms.Button
$btnReset.Text = 'Reset session'
$btnReset.Location = New-Object Drawing.Point(234, 384)
$btnReset.Size = New-Object Drawing.Size(140, 48)
$btnReset.FlatStyle = 'Flat'
$btnReset.FlatAppearance.BorderSize = 0
$btnReset.BackColor = [Drawing.Color]::FromArgb(24, 30, 50)
$btnReset.ForeColor = [Drawing.Color]::FromArgb(200, 208, 230)

$btnOff = New-Object Windows.Forms.Button
$btnOff.Text = 'Turn off session'
$btnOff.Location = New-Object Drawing.Point(386, 384)
$btnOff.Size = New-Object Drawing.Size(152, 48)
$btnOff.FlatStyle = 'Flat'
$btnOff.FlatAppearance.BorderSize = 0
$btnOff.BackColor = [Drawing.Color]::FromArgb(48, 26, 32)
$btnOff.ForeColor = [Drawing.Color]::FromArgb(240, 150, 150)

$status = New-Object Windows.Forms.Label
$status.Text = 'Ready.'
$status.Location = New-Object Drawing.Point(22, 438)
$status.Size = New-Object Drawing.Size(516, 60)
$status.ForeColor = [Drawing.Color]::FromArgb(180, 190, 215)

# hand-drawn progress bar - the themed WinForms one looks wrong on a dark form
$barTrough = New-Object Windows.Forms.Panel
$barTrough.Location = New-Object Drawing.Point(22, 504)
$barTrough.Size = New-Object Drawing.Size(516, 12)
$barTrough.BackColor = [Drawing.Color]::FromArgb(26, 33, 54)
$barTrough.Visible = $false

$barFill = New-Object Windows.Forms.Panel
$barFill.Location = New-Object Drawing.Point(0, 0)
$barFill.Size = New-Object Drawing.Size(0, 12)
$barFill.BackColor = [Drawing.Color]::FromArgb(126, 242, 168)
$barFill.Visible = $false
$barTrough.Controls.Add($barFill)

$form.Controls.AddRange(@($title, $btnSetup, $sub, $lblSites, $list, $txtSite,
                          $btnAdd, $btnRemove, $rbAllow, $rbBlock, $hint,
                          $btnLaunch, $btnReset, $btnOff, $status, $barTrough, $barFill))
$form.AcceptButton = $btnAdd

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 500

# ---------------------------------------------------------- install tracker --
function Reset-Progress {
    param([string]$Phase)
    $script:Progress['phase']   = $Phase
    $script:Progress['detail']  = ''
    $script:Progress['percent'] = -1
    $script:Progress['read']    = 0
    $script:Progress['total']   = 0
    $script:JobStart   = Get-Date
    $script:LastSample = Get-Date
    $script:LastRead   = 0
    $script:SpeedBps   = 0
    $script:MarqueePos = -140
}

function Format-Size {
    param([int64]$bytes)
    if ($bytes -ge 1GB) { return ('{0:N2} GB' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N1} MB' -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ('{0:N0} KB' -f ($bytes / 1KB)) }
    return "$bytes B"
}

function Render-Tracker {
    $p = $script:Progress

    # winget keeps its download in %TEMP%\WinGet - read it while we wait
    if ($script:marker -eq 'CYBERSHIELD_INSTALL' -and [int]$p['percent'] -lt 0) {
        $b = Get-WingetBytes
        if ($b -gt 0) { $p['detail'] = "$(Format-Size $b) downloaded" }
    }

    $barTrough.Visible = $true
    $barFill.Visible   = $true

    if ([int]$p['total'] -gt 0) {
        # determinate: we know the size, so show speed as well
        $now = Get-Date
        $dt = ($now - $script:LastSample).TotalSeconds
        if ($dt -gt 0.1) {
            $delta = [int64]$p['read'] - $script:LastRead
            if ($delta -ge 0) { $script:SpeedBps = [int64]($delta / $dt) }
            $script:LastRead = [int64]$p['read']
            $script:LastSample = $now
        }
        $pct = [int][Math]::Min(100, [Math]::Max(0, [int]$p['percent']))
        $barFill.Left  = 0
        $barFill.Width = [int]($barTrough.Width * $pct / 100)

        $detail = "$pct%  -  $(Format-Size ([int64]$p['read'])) / $(Format-Size ([int64]$p['total']))"
        if ($script:SpeedBps -gt 0) { $detail += "  -  $(Format-Size $script:SpeedBps)/s" }
    }
    else {
        # indeterminate: slide a block so there is always visible motion
        $script:MarqueePos += 14
        if ($script:MarqueePos -gt ($barTrough.Width + 140)) { $script:MarqueePos = -140 }
        $barFill.Width = 140
        $barFill.Left  = $script:MarqueePos
        $detail = "$($p['detail'])"
    }

    $secs = [int]((Get-Date) - $script:JobStart).TotalSeconds
    $elapsed = '{0}:{1:00}' -f [int]($secs / 60), ($secs % 60)

    $lines = @()
    if ($p['phase']) { $lines += "$($p['phase'])" }
    if ($detail.Trim()) { $lines += "   $detail" }
    $lines += "   elapsed $elapsed"
    $status.Text = ($lines -join "`r`n")
}

function Stop-Tracker {
    $barTrough.Visible = $false
    $barFill.Visible   = $false
}

# ----------------------------------------------------------- UI state -------
function Update-Ui {
    $script:Gcloud = Find-Gcloud
    $has = [bool]$script:Gcloud
    $btnLaunch.Enabled = $has
    $btnReset.Enabled  = $has
    $btnOff.Enabled    = $has

    # Any finished job disables this button, so it MUST be re-enabled here or it
    # stays greyed out forever after the first install/sign-in attempt.
    $btnSetup.Enabled = $true

    if ($has) {
        $script:SetupAction = 'auth'
        if ($script:Account) { $btnSetup.Text = 'Sign in again' }
        else                 { $btnSetup.Text = 'Sign in to Google' }
    } else {
        $script:SetupAction = 'install'
        $btnSetup.Text = 'Install Google CLI'
    }
    $lblSites.Text = "Websites ($($list.Items.Count))"
}

# ------------------------------------------------------- config handling ----
function Save-Config {
    $cfg = [ordered]@{
        mode  = $(if ($rbBlock.Checked) { 'block' } else { 'allow' })
        sites = @($list.Items | ForEach-Object { "$_" })
    }
    try {
        ($cfg | ConvertTo-Json -Depth 4) | Set-Content -Path $script:CfgPath -Encoding UTF8
    } catch { }
    $lblSites.Text = "Websites ($($list.Items.Count))"
}

function Load-Config {
    if (Test-Path $script:CfgPath) {
        try {
            $cfg = Get-Content $script:CfgPath -Raw | ConvertFrom-Json
            $list.Items.Clear()
            foreach ($s in @($cfg.sites)) { if ($s) { [void]$list.Items.Add("$s") } }
            if ($cfg.mode -eq 'block') { $rbBlock.Checked = $true } else { $rbAllow.Checked = $true }
        } catch { }
    }
    else {
        foreach ($s in @('wikipedia.org', 'khanacademy.org')) { [void]$list.Items.Add($s) }
        $rbAllow.Checked = $true
    }
    $lblSites.Text = "Websites ($($list.Items.Count))"
}

function Get-PolicyBlob {
    $cfg = [ordered]@{
        mode  = $(if ($rbBlock.Checked) { 'block' } else { 'allow' })
        sites = @($list.Items | ForEach-Object { "$_" })
    }
    $json = $cfg | ConvertTo-Json -Depth 4 -Compress
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
}

# ------------------------------------------------------------- plumbing -----
$timer.Add_Tick({
    try {
        if ($null -eq $script:handle) { return }

        if (-not $script:handle.IsCompleted) {
            Render-Tracker
            return
        }

        $timer.Stop()
        Stop-Tracker

        $out = ''
        try { $out = ($script:ps.EndInvoke($script:handle) | Out-String) } catch { $out = "$_" }
        if ($script:ps.Streams.Error.Count -gt 0) { $out += ($script:ps.Streams.Error | Out-String) }
        $script:ps.Dispose()
        $script:ps = $null
        $script:handle = $null

        switch ($script:marker) {

            'CYBERSHIELD_HOST' {
                Update-Ui
                $m = [regex]::Match($out, 'CYBERSHIELD_HOST=(\S+)')
                if ($m.Success) {
                    $webHost = $m.Groups[1].Value
                    $script:lastUrl = "https://6080-$webHost/?quality=2&compression=1&scalingMode=scale&clipToWindow=true&dotCursor=true"
                    $status.Text = 'Session ready - opening browser...'
                    Write-Log "Launch OK - $($list.Items.Count) sites, url $($script:lastUrl)"
                    Write-Log "reply tail: $(($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 3) -join ' / ')"
                    Open-Session $script:lastUrl
                    $status.Text = "Running with $($list.Items.Count) sites. Reopen: $($script:lastUrl)"
                } else {
                    Write-Log "Launch FAILED - no CYBERSHIELD_HOST in the reply" 'ERROR'
                    Write-Log "reply: $(($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 5) -join ' / ')" 'ERROR'
                    $status.Text = "Could not reach the session. Check the internet, then press Launch again - the first run can take a few minutes."
                }
            }

            'CYBERSHIELD_RESET' {
                Update-Ui
                if ($out -match 'CYBERSHIELD_RESET=ok') {
                    $status.Text = "Session reset - blank machine, $($list.Items.Count) sites applied."
                    Write-Log "Reset OK - $($list.Items.Count) sites"
                    if ($script:lastUrl) { Open-Session $script:lastUrl }
                } else {
                    Write-Log "Reset FAILED - reply: $(($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 5) -join ' / ')" 'ERROR'
                    $status.Text = 'Reset failed - is the container running?'
                }
            }

            'CYBERSHIELD_OFF' {
                Update-Ui
                if ($out -match 'CYBERSHIELD_OFF=ok') {
                    $status.Text = 'Session is off. Launch session starts it again.'
                    Write-Log 'Turn off OK - the session is stopped'
                } else {
                    Write-Log "Turn off FAILED - reply: $(($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 5) -join ' / ')" 'ERROR'
                    $status.Text = 'Could not reach Cloud Shell to turn the session off - check the connection and try again.'
                }
            }

            'CYBERSHIELD_INSTALL' {
                Refresh-Path
                Update-Ui
                if ($script:Gcloud) {
                    Write-Log "Install OK - gcloud at $($script:Gcloud)"
                    $status.Text = "Google Cloud CLI installed.`r`n   Click 'Sign in to Google' to finish."
                } else {
                    $tail = ($out -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 3) -join "`r`n"
                    Write-Log "Install FAILED - $tail" 'ERROR'
                    $status.Text = "Install did not complete.`r`n$tail`r`nManual install: https://cloud.google.com/sdk/docs/install"
                }
            }

            'CYBERSHIELD_AUTH' {
                $m2 = [regex]::Match($out, 'CYBERSHIELD_AUTH=(.*)')
                if ($m2.Success) { $script:Account = $m2.Groups[1].Value.Trim() }
                Update-Ui
                if ($script:Account) {
                    Write-Log "Sign-in OK - $($script:Account)"
                    $status.Text = "Signed in as $($script:Account).`r`n   Click Launch session."
                } else {
                    Write-Log 'Sign-in FAILED - nobody signed in afterwards' 'ERROR'
                    $status.Text = "Sign-in did not complete.`r`n   Run it by hand if you need to: gcloud auth login"
                }
            }

            'CYBERSHIELD_AUTHCHECK' {
                $m2 = [regex]::Match($out, 'CYBERSHIELD_AUTH=(.*)')
                if ($m2.Success) { $script:Account = $m2.Groups[1].Value.Trim() }
                Update-Ui
                if ($script:Account) {
                    Write-Log "Sign-in check OK - $($script:Account)"
                    $status.Text = "Ready. Signed in as $($script:Account)"
                } else {
                    Write-Log 'Sign-in check - nobody signed in'
                    $status.Text = 'Google Cloud CLI found, but nobody is signed in. Click "Sign in to Google".'
                }
            }
        }
    }
    catch {
        $timer.Stop()
        Stop-Tracker
        if ($script:ps) { $script:ps.Dispose(); $script:ps = $null }
        $script:handle = $null
        Update-Ui
        Write-Log "Exception - $($_.Exception.Message)" 'ERROR'
        $status.Text = "Error: $($_.Exception.Message)"
    }
})

function Start-Job2 {
    param([scriptblock]$Body, [object[]]$Arguments, [string]$Marker, [string]$Phase)

    $btnLaunch.Enabled = $false
    $btnReset.Enabled  = $false
    $btnOff.Enabled    = $false
    $btnSetup.Enabled  = $false
    $script:marker = $Marker
    Reset-Progress $Phase
    Write-Log "$Marker started - $Phase"

    # In-process runspace: keeps the window responsive, and works without a
    # console, which matters once this is compiled to an .exe.
    $script:ps = [PowerShell]::Create()
    [void]$script:ps.AddScript($Body)
    foreach ($a in $Arguments) { [void]$script:ps.AddArgument($a) }
    $script:handle = $script:ps.BeginInvoke()
    $timer.Start()
}

# Start-Remote runs one command inside Cloud Shell and returns everything it
# printed. It is written the long way on purpose, because the obvious version
# (just calling gcloud and reading the output) hangs forever on Windows:
#
#   * `gcloud cloud-shell ssh` does not talk SSH itself on Windows, it drives
#     PuTTY's plink through a local websocket tunnel. It has three connection
#     attempts, and EACH attempt opens a NEW random local port. PuTTY caches
#     host keys per host:port, so every attempt looks like a brand new server
#     and asks the "Store key in cache? (y/n)" question. That question goes to
#     the console and is read from stdin. With no console - which is exactly how
#     a captured, windowless call behaves - it blocks there for good. That is
#     the famous "stuck on Listening on local port [N]." hang.
#   * `--ssh-flag="-legacy-stdio-prompts"` moves the question onto the standard
#     streams, where we can see it and answer it.
#   * The answer has to keep coming. plink swallows the whole stdin pipe into
#     its own buffer on the first prompt, so a single "y" is spent on attempt 1
#     (which always fails anyway - it asks for publickey auth) and attempt 2
#     then reads EOF and gives up with "Connection abandoned." So we keep
#     writing "y" until the process actually exits. Attempt 2, over the tunnel's
#     port 2222, is the one that succeeds.
#
# The call also goes through a one-line .cmd shim rather than a PowerShell
# argument list, for the same reason the sign-in does: gcloud is a .cmd, and
# cmd.exe eats quotes and meaning from `>`, `|`, `&`. The batch file keeps the
# remote command intact.
#
# Before the caller's command runs, the worker makes sure the Cloud Shell side
# exists at all: it probes for ~/cybershield/setup.sh, and when it is missing
# (fresh account, or Cloud Shell recycled the VM and wiped $HOME) it uploads the
# installer embedded above in chunks, checks it by md5, runs it, and only then
# runs the command. That is what makes Launch work on a brand-new Cloud Shell
# without anyone pasting the script by hand.
function Start-Remote {
    param([string]$Template, [string]$Marker, [string]$Phase, [switch]$SkipSetup)
    $command = $Template.Replace('$B64', (Get-PolicyBlob))
    $exe = $script:Gcloud
    $prog = $script:Progress
    Start-Job2 -Marker $Marker -Phase $Phase -Arguments @($exe, $command, $prog, $SetupScriptB64, [bool]$SkipSetup) -Body {
        param($gcloudExe, $c, $prog, $setupB64, $skipSetup)

        # gcloud is a python program, and python block-buffers its output when it
        # is not attached to a console. Unbuffered keeps Cloud Shell's progress
        # visible while it works instead of dumping it all at the end.
        $env:PYTHONUNBUFFERED = '1'
        $env:CLOUDSDK_CORE_DISABLE_PROMPTS = '1'

        $dir = Join-Path $env:TEMP 'cybershield-remote'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $bat = Join-Path $dir 'run.cmd'

        # One round trip to Cloud Shell: write a fresh shim, run it, feed "y" to
        # plink's host-key question until the process ends, collect stdout and
        # stderr, hand back everything that was printed.
        function Invoke-RemoteOnce([string]$cmdText) {
            Set-Content -LiteralPath $bat -Encoding ASCII -Value @(
                '@echo off',
                ('call "' + $gcloudExe + '" cloud-shell ssh --authorize-session --quiet ' +
                 '--ssh-flag="-legacy-stdio-prompts" --command "' + $cmdText + '"')
            )

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName               = $env:ComSpec
            $psi.Arguments              = '/c "' + $bat + '"'
            $psi.UseShellExecute        = $false
            $psi.CreateNoWindow         = $true
            $psi.RedirectStandardInput  = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.WorkingDirectory       = $dir

            $prog['detail'] = 'connecting to Cloud Shell'
            $p = [System.Diagnostics.Process]::Start($psi)

            # Reading line by line (rather than ReadToEnd) is what feeds the
            # tracker, so the window shows what Cloud Shell is doing all along.
            $outTask = $p.StandardOutput.ReadLineAsync()
            $errTask = $p.StandardError.ReadLineAsync()

            $sb = New-Object System.Text.StringBuilder
            $sw = [Diagnostics.Stopwatch]::StartNew()

            while (-not $p.HasExited -and $sw.Elapsed.TotalMinutes -lt 45) {
                try { $p.StandardInput.Write("y`n"); $p.StandardInput.Flush() } catch { }

                if ($outTask.IsCompleted) {
                    $l = $outTask.Result
                    if ($null -ne $l) {
                        [void]$sb.AppendLine($l)
                        $t = $l.Trim()
                        if ($t) {
                            if ($t.Length -gt 110) { $t = $t.Substring(0, 110) }
                            $prog['detail'] = $t
                        }
                    }
                    $outTask = $p.StandardOutput.ReadLineAsync()
                }
                if ($errTask.IsCompleted) {
                    $l = $errTask.Result
                    if ($null -ne $l) {
                        [void]$sb.AppendLine($l)
                        $t = $l.Trim()
                        if ($t) {
                            if ($t.Length -gt 110) { $t = $t.Substring(0, 110) }
                            $prog['detail'] = $t
                        }
                    }
                    $errTask = $p.StandardError.ReadLineAsync()
                }

                Start-Sleep -Milliseconds 200
            }

            $timedOut = -not $p.HasExited
            if ($timedOut) { try { $p.Kill() } catch { } }
            Start-Sleep -Milliseconds 500

            # A line that a ReadLineAsync had ALREADY taken off the stream when
            # the process ended is invisible to ReadToEnd - it is gone, and the
            # lost line is often the marker the caller is waiting for
            # ("CYBERSHIELD_HOST=..."), which made a run that worked look like it
            # failed. Collect those before draining whatever is left.
            foreach ($pending in @($outTask, $errTask)) {
                if ($null -eq $pending) { continue }
                try {
                    if (-not $pending.IsCompleted) { [void]$pending.Wait(5000) }
                    $l = $pending.Result
                    if ($null -ne $l) { [void]$sb.AppendLine($l) }
                } catch { }
            }
            try { [void]$sb.Append($p.StandardOutput.ReadToEnd()) } catch { }
            try { [void]$sb.Append($p.StandardError.ReadToEnd()) } catch { }
            try { $p.Dispose() } catch { }
            try { Remove-Item -LiteralPath $bat -Force } catch { }

            $text = $sb.ToString()
            if ($timedOut) {
                $text += "`nCYBERSHIELD: Cloud Shell did not answer within $([int]$sw.Elapsed.TotalSeconds) seconds."
            }
            $text
        }

        $pre = ''
        if (-not $skipSetup) {
        # ---- is the Cloud Shell side there at all, and up to date? -----------
        # The remote copy counts as present only when its setup.sh hashes to
        # the copy embedded in this app. A fresh account, a wiped $HOME and an
        # older build of this repo all fail that check, so all three get the
        # installer uploaded and run right here: upload in chunks, prove the
        # upload by md5, run it (the first run builds the image; minutes),
        # then carry on with what the caller actually asked for.
        $probe = ''
        for ($try = 1; $try -le 3; $try++) {
            $probe = Invoke-RemoteOnce 'if [ -f $HOME/cybershield/setup.sh ]; then md5sum $HOME/cybershield/setup.sh; else echo none; fi; echo CYBERSHIELD_SETUP_CHECK=done'
            if ($probe -match 'CYBERSHIELD_SETUP_CHECK=done') { break }
            $prog['detail'] = 'could not read the session state - asking again'
        }
        if ($probe -notmatch 'CYBERSHIELD_SETUP_CHECK=done') {
            return ($probe + "`nCYBERSHIELD: could not ask Cloud Shell whether it is set up yet - check the connection and press Launch again.")
        }

        # md5 of the setup.sh that running the embedded installer produces: the
        # text between the installer's heredoc markers, byte for byte. The
        # remote probe hashes exactly that file, so the two are comparable.
        $wantInner = ''
        if ($setupB64) {
            $s = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($setupB64))
            $open = $s.IndexOf("<<'CYBERSHIELD_SETUP_EOF'")
            $close = $s.LastIndexOf('CYBERSHIELD_SETUP_EOF')
            if ($open -ge 0 -and $close -gt $open) {
                $inner = $s.Substring($open, $close - $open)
                $inner = $inner.Substring($inner.IndexOf("`n") + 1)
                $h2 = [Security.Cryptography.MD5]::Create()
                $wantInner = ([BitConverter]::ToString($h2.ComputeHash([Text.Encoding]::UTF8.GetBytes($inner))) -replace '-', '').ToLower()
                $h2.Dispose()
            }
        }
        $remoteMd5 = ''
        if ($probe -match '(?m)^([0-9a-f]{32})\s') { $remoteMd5 = $Matches[1] }

        $pre = $probe + "`n"
        if (-not ($wantInner -and $remoteMd5 -eq $wantInner)) {
            if (-not $setupB64) {
                return ($pre + 'CYBERSHIELD: Cloud Shell has no ~/cybershield and this build carries no installer to upload.')
            }

            # md5 of the very bytes about to be uploaded, so the two cannot disagree
            $hasher = [Security.Cryptography.MD5]::Create()
            $want = ([BitConverter]::ToString($hasher.ComputeHash([Convert]::FromBase64String($setupB64))) -replace '-', '').ToLower()
            $hasher.Dispose()

            $prog['detail'] = 'session update - clearing any half-written installer'
            [void](Invoke-RemoteOnce 'mkdir -p $HOME/cybershield; rm -f $HOME/cybershield/setup.b64; echo CYBERSHIELD_UPLOAD=cleared')

            $chunk = 4700
            $count = [int][Math]::Ceiling($setupB64.Length / $chunk)
            for ($i = 0; $i -lt $count; $i++) {
                $piece = $setupB64.Substring($i * $chunk, [Math]::Min($chunk, $setupB64.Length - $i * $chunk))
                $prog['detail'] = "session update - uploading the installer, chunk $($i + 1) of $count"
                [void](Invoke-RemoteOnce ('echo ' + $piece + ' >> $HOME/cybershield/setup.b64; echo CYBERSHIELD_CHUNK=ok'))
            }

            # The echo of each chunk is deliberately not trusted - only the md5
            # of the reassembled file decides whether the upload really landed.
            $prog['detail'] = 'session update - checking the upload byte for byte'
            $verify = Invoke-RemoteOnce 'cd $HOME/cybershield; base64 -d setup.b64 > install.sh; md5sum install.sh; wc -c < install.sh; rm -f setup.b64; echo CYBERSHIELD_UPLOAD=done'
            $pre += $verify + "`n"
            if ($verify -notmatch $want) {
                return ($pre + "CYBERSHIELD: the installer did not survive the upload intact (wanted md5 $want) - press Launch again.")
            }

            $prog['detail'] = 'session update - building the session image (a ~2 GB pull, once)'
            $install = Invoke-RemoteOnce 'bash $HOME/cybershield/install.sh > $HOME/cybershield/install.log 2>&1; echo CYBERSHIELD_INSTALL_EXIT=$?; tail -8 $HOME/cybershield/install.log'
            $pre += $install + "`n"
            if ($install -match 'CYBERSHIELD_INSTALL_EXIT=[1-9]') {
                return ($pre + 'CYBERSHIELD: the session install on Cloud Shell failed - the last lines of its log are above.')
            }
        }
        }

        return ($pre + (Invoke-RemoteOnce $c))
    }
}

# --------------------------------------------------- install / sign-in job --
$InstallGoogleCli = {
    param($url, $prog)

    $ErrorActionPreference = 'Continue'
    $ok = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $prog['phase']  = 'Installing via winget'
        $prog['detail'] = 'resolving Google.CloudSDK'
        $prog['percent'] = -1
        & winget install --id Google.CloudSDK -e --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) { $ok = $true }
        else { $prog['detail'] = "winget exited with code $LASTEXITCODE - falling back" }
    }

    if (-not $ok) {
        # Download the official installer ourselves so the byte count is real.
        $prog['phase']   = 'Downloading the official installer'
        $prog['percent'] = 0
        $dest = Join-Path $env:TEMP 'GoogleCloudSDKInstaller.exe'

        try { Add-Type -AssemblyName System.Net.Http } catch { }
        $client = New-Object System.Net.Http.HttpClient
        $client.Timeout = [TimeSpan]::FromMinutes(30)
        $resp = $client.GetAsync($url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        $resp.EnsureSuccessStatusCode() | Out-Null

        $total = $resp.Content.Headers.ContentLength
        if (-not $total) { $total = 0 }
        $prog['total'] = [int64]$total
        $prog['read']  = 0

        $in  = $resp.Content.ReadAsStreamAsync().Result
        $out = [IO.File]::Create($dest)
        $buf = New-Object byte[] 131072
        while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
            $out.Write($buf, 0, $n)
            $prog['read'] = [int64]($prog['read'] + $n)
            if ($total -gt 0) {
                $prog['percent'] = [int](100 * $prog['read'] / $total)
            }
        }
        $out.Close(); $out.Dispose()
        $in.Close();  $in.Dispose()
        $client.Dispose()

        $prog['percent'] = 100
        $prog['phase']   = 'Running the installer'
        $prog['detail']  = 'approve the Windows prompt - click through the wizard'
        Start-Sleep -Milliseconds 400
        $prog['total'] = 0
        $prog['percent'] = -1
        Start-Process -FilePath $dest -Wait
    }

    $prog['phase']  = 'Finishing up'
    $prog['detail'] = 'checking the install'
    $prog['total'] = 0
    $prog['percent'] = -1

    'CYBERSHIELD_INSTALL=ok'
}

# Sign-in runs in its own visible console window on purpose: gcloud prints the
# login URL there, so if the browser does not open by itself you can still read
# and copy the URL, instead of watching a bar that never moves. Afterwards we ask
# gcloud who is actually signed in, so the window reports a fact, not a guess.
$SignInJob = {
    param($gcloudExe, $prog, $mode)

    if ($mode -eq 'login') {
        $prog['phase']  = 'Signing in to Google'
        $prog['detail'] = 'finish the sign-in in the cmd window that just opened'

        # Run it in a real cmd window. A batch wrapper rather than quoting the
        # path on cmd's own command line, because the Cloud SDK often lives under
        # "C:\Program Files (x86)\..." and cmd strips the quotes around a path
        # like that. The wrapper also holds the window open when the sign-in
        # fails, so the error stays on screen instead of flashing past.
        # `call` is essential: invoking a .cmd without it hands control over
        # permanently, so the wrapper's own error handling below would never run.
        $exeLine = 'call "' + $gcloudExe + '" auth login'
        $bat = Join-Path $env:TEMP 'cybershield-signin.cmd'
        try {
            Set-Content -LiteralPath $bat -Encoding ASCII -Value @(
                '@echo off'
                'title Cybershield - Google sign-in'
                'echo Opening your browser for the Google sign-in...'
                'echo.'
                $exeLine
                'if errorlevel 1 ('
                '    echo.'
                '    echo Sign-in did not complete - the message above says why.'
                '    echo.'
                '    pause'
                ')'
            )
            Start-Process -FilePath $env:ComSpec -ArgumentList '/c', 'cybershield-signin.cmd' `
                          -WorkingDirectory $env:TEMP -Wait
        }
        catch {
            $prog['detail'] = "could not start the sign-in: $($_.Exception.Message)"
        }
    }

    $prog['phase']  = 'Checking the sign-in'
    $prog['detail'] = 'asking gcloud who is signed in'

    $account = ''
    try {
        # No --filter=status:ACTIVE here: gcloud emits a confusing "filter keys
        # were not present in any resource" warning when the account list is
        # empty. Asking for every credentialed account is warning-free and is the
        # same answer for our purposes ("is anyone signed in?").
        $raw = (& $gcloudExe auth list '--format=value(account)' 2>&1 | Out-String)
        $account = ($raw -split "`n" |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { $_ -match '@' } |
                    Select-Object -Last 1)
    }
    catch { }

    if ($account) { $prog['detail'] = "signed in as $account" }
    "CYBERSHIELD_AUTH=$account"
}

$btnSetup.Add_Click({
    if ($script:SetupAction -eq 'install') {
        Start-Job2 -Marker 'CYBERSHIELD_INSTALL' -Phase 'Starting the install' `
                   -Arguments @($CloudSdkInstaller, $script:Progress) -Body $InstallGoogleCli
    }
    else {
        $status.Text = 'A console window is opening for the sign-in...'
        $g = $script:Gcloud
        Start-Job2 -Marker 'CYBERSHIELD_AUTH' -Phase 'Signing in to Google' `
                   -Arguments @($g, $script:Progress, 'login') -Body $SignInJob
    }
})

# ---------------------------------------------------------------- events ----
$btnAdd.Add_Click({
    $s = Normalize-Site $txtSite.Text
    if ($s -and -not $list.Items.Contains($s)) { [void]$list.Items.Add($s) }
    $txtSite.Clear()
    Save-Config
})

$txtSite.Add_KeyDown({
    if ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) {
        $s = Normalize-Site $txtSite.Text
        if ($s -and -not $list.Items.Contains($s)) { [void]$list.Items.Add($s) }
        $txtSite.Clear()
        Save-Config
        $_.SuppressKeyPress = $true
    }
})

$btnRemove.Add_Click({
    if ($list.SelectedIndex -ge 0) { $list.Items.RemoveAt($list.SelectedIndex) }
    Save-Config
})

$rbAllow.Add_CheckedChanged({ Save-Config })
$rbBlock.Add_CheckedChanged({ Save-Config })

$btnLaunch.Add_Click({
    Write-Log "Launch clicked - mode=$(if ($rbBlock.Checked) { 'block' } else { 'allow' }) sites=$(@($list.Items) -join ',')"
    Start-Remote $RemotePushStart 'CYBERSHIELD_HOST' 'Provisioning the Cloud Shell session'
})

$btnReset.Add_Click({
    Write-Log "Reset clicked - mode=$(if ($rbBlock.Checked) { 'block' } else { 'allow' }) sites=$(@($list.Items) -join ',')"
    Start-Remote $RemotePushReset 'CYBERSHIELD_RESET' 'Applying the website list and restarting'
})

$btnOff.Add_Click({
    Write-Log 'Turn off clicked'
    Start-Remote $RemoteSessionOff 'CYBERSHIELD_OFF' 'Turning the session off' -SkipSetup
})

# ------------------------------------------------------------------ init ----
Write-Log "app start - $($PSVersionTable.PSVersion) on $([Environment]::OSVersion.VersionString)"
Load-Config
Update-Ui
Write-Log "config loaded - $($list.Items.Count) sites, mode $(if ($rbBlock.Checked) { 'block' } else { 'allow' }), file $script:CfgPath"
if ($script:Gcloud) {
    Write-Log "gcloud found - $($script:Gcloud)"
    # Ask gcloud up front, so the window tells you whether you are signed in
    # rather than letting you find out when Launch fails.
    $g = $script:Gcloud
    $status.Text = 'Google Cloud CLI found. Checking the sign-in...'
    Start-Job2 -Marker 'CYBERSHIELD_AUTHCHECK' -Phase 'Checking the sign-in' `
               -Arguments @($g, $script:Progress, 'check') -Body $SignInJob
} else {
    Write-Log 'gcloud not found - install needed'
    $status.Text = 'Google Cloud CLI not found. Click "Install Google CLI" to install it (~100 MB, one time).'
}

try {
    [void]$form.ShowDialog()
}
catch {
    [void][Windows.Forms.MessageBox]::Show("$($_.Exception.Message)", 'STAI Cybershield')
}
