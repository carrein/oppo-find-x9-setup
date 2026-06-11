#!/usr/bin/env bash
# fetch-apk.sh — pull an APK from the APKPure CDN and verify its signature. NEVER installs.
#
#   * Works when the web mirrors (APKPure web, APKCombo, APKMirror) 403 or JS-gate the
#     download: the CDN itself serves anyone presenting the app's user agent.
#   * Tries d.cdnpure.com first, then d.apkpure.net. (d.apkpure.com 403s — don't bother.)
#   * Decodes the final URL's _fn/_p params (base64 filename / package id) so you can
#     confirm you got the right app before trusting the file.
#   * Runs `apksigner verify --print-certs` (from ANDROID_HOME build-tools) and prints the
#     cert digests. COMPARE THEM against a known-good fingerprint for the publisher before
#     `adb install`. For first-party Oplus apps the v3.1 signer DN is
#     "O=Oplus, CN=AndroidTeam, OU=OSTeam, L=DongGuan, C=CN".
#
# Usage: scripts/fetch-apk.sh <package.id> [--xapk] [--version <ver>]
set -u

UA="APKPure/3.20.10 (Aegon)"
HOSTS=(d.cdnpure.com d.apkpure.net)

pkg="" kind=APK version=latest
while [ $# -gt 0 ]; do
  case "$1" in
    --xapk) kind=XAPK ;;
    --version) shift; version="${1:?--version needs a value}" ;;
    -h|--help) sed -n '2,${/^#/!q;s/^# \{0,1\}//p;}' "$0"; exit 0 ;;
    -*) echo "unknown arg: $1" >&2; exit 2 ;;
    *) pkg="$1" ;;
  esac
  shift
done
[ -n "$pkg" ] || { echo "usage: scripts/fetch-apk.sh <package.id> [--xapk] [--version <ver>]" >&2; exit 2; }

out="$pkg.$(tr '[:upper:]' '[:lower:]' <<<"$kind")"
ok=0
for host in "${HOSTS[@]}"; do
  url="https://$host/b/$kind/$pkg?version=$version"
  echo "fetching $url"
  final=$(curl -sL -A "$UA" -H "Accept: application/vnd.android.package-archive" \
               -o "$out" -w '%{url_effective}' "$url") && [ -s "$out" ] || { echo "  failed, trying next host"; continue; }
  # reject HTML error pages masquerading as success
  if head -c 2 "$out" | grep -q 'PK'; then ok=1; break; fi
  echo "  response is not an APK/ZIP, trying next host"
done
[ "$ok" -eq 1 ] || { echo "all hosts failed for $pkg" >&2; rm -f "$out"; exit 1; }

echo
echo "saved: $out ($(du -h "$out" | cut -f1 | tr -d ' '))"
# the CDN encodes filename and package id in the redirect target — decode and confirm
python3 - "$final" <<'EOF'
import base64, sys, urllib.parse
q = urllib.parse.parse_qs(urllib.parse.urlparse(sys.argv[1]).query)
for k, label in (("_fn", "filename"), ("_p", "package")):
    if k in q:
        pad = q[k][0] + "=" * (-len(q[k][0]) % 4)
        try: print(f"cdn-declared {label}: {base64.b64decode(pad).decode()}")
        except Exception: pass
EOF

echo
sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
apksigner=$(ls "$sdk"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)
if [ -z "$apksigner" ]; then
  echo "apksigner not found under $sdk/build-tools — verify the signature yourself before installing." >&2
  exit 0
fi
echo "signature:"
"$apksigner" verify --print-certs "$out"
echo
echo "Compare the cert digest above against a known-good fingerprint for this publisher,"
echo "then install with:  adb install $out"
