#!/usr/bin/env bash
# 03-settings.sh — apply the adb-scriptable settings, idempotently.
#
#   * --dry-run is the DEFAULT: reports what WOULD change, mutates nothing. --apply to mutate.
#   * Read-before-write: each setting is read first; matching values report ALREADY-OK.
#   * Currently controlled: NOTHING — this is a scaffold for future settings.
#       global audio_safe_volume_state = 1 (EU loudness-warning kill) was controlled here
#       and verified by 99 until real-device experience showed it does NOT persist across
#       reboots on ColorOS 16 — chasing it is churn, so it was dropped from canon.
#       The one-liner if you want it for the current boot anyway:
#         adb shell settings put global audio_safe_volume_state 1
#
# Usage: scripts/03-settings.sh [--dry-run|--apply]
set -u
source "$(dirname "$0")/lib/common.sh"

parse_apply "$@"
need_adb

ensure_setting() { # ensure_setting <namespace> <key> <want> <label>
  local ns="$1" key="$2" want="$3" label="$4" cur
  cur=$(adb shell settings get "$ns" "$key" </dev/null | tr -d '\r')
  if [ "$cur" = "$want" ]; then
    report ALREADY-OK settings "$label" "$ns $key=$cur"
  elif [ "$DRY" -eq 1 ]; then
    report WOULD-APPLY settings "$label" "$ns $key: $cur -> $want"
  else
    adb shell settings put "$ns" "$key" "$want" </dev/null >/dev/null 2>&1
    cur=$(adb shell settings get "$ns" "$key" </dev/null | tr -d '\r')
    if [ "$cur" = "$want" ]; then
      report APPLIED settings "$label" "$ns $key=$want"
    else
      report SKIPPED settings "$label" "did not verify: got $cur"
    fi
  fi
}

# no settings currently controlled — see header. ensure_setting stays for the next one:
#   ensure_setting <namespace> <key> <want> <label>
echo "no settings under management (audio_safe_volume_state dropped — does not persist; see header)"

totals
