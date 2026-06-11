#!/usr/bin/env bash
# 03-settings.sh — apply the adb-scriptable settings, idempotently.
#
#   * --dry-run is the DEFAULT: reports what WOULD change, mutates nothing. --apply to mutate.
#   * Read-before-write: each setting is read first; matching values report ALREADY-OK.
#   * Currently controlled:
#       global audio_safe_volume_state = 1  — disables the EU loudness/"safe volume" warning
#         that re-arms on USB-C DACs (0=NOT_CONFIGURED 1=DISABLED 2=INACTIVE 3=ACTIVE).
#         NOTE: known to occasionally reset on reboot — re-run this script (or check
#         99-verify-all.sh, which flags it) if the warning comes back.
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

ensure_setting global audio_safe_volume_state 1 "safe-volume warning off"

totals
