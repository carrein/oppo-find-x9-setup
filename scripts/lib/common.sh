#!/usr/bin/env bash
# common.sh — shared helpers for the oppo-find-x9-setup scripts. Source, don't run.
#
#   * Status vocabulary: APPLIED / ALREADY-OK / NOT-FOUND / SKIPPED / WOULD-APPLY
#   * Package-state reads are cached per run (one `pm list packages` per flavor);
#     post-apply re-checks always hit the device live so APPLIED means verified.
#   * JSON is parsed with python3 (stdlib only) — no jq dependency.
set -u

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$LIB_DIR/../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/config"
DEBLOAT_LIST="$CONFIG_DIR/debloat-list.json"
KEEP_LIST="$CONFIG_DIR/keep-installed.json"

# Status tallies live in per-status scalar vars (COUNT_APPLIED, COUNT_ALREADY_OK, …)
# rather than an associative array: macOS ships bash 3.2, which has no `declare -A`.
report() { # report STATUS SECTION NAME [DETAIL]
  local st="$1" section="$2" name="$3" detail="${4:-}"
  local var="COUNT_${st//-/_}"
  eval "$var=\$(( \${$var:-0} + 1 ))"
  printf '[%-11s] %s :: %s%s\n' "$st" "$section" "$name" "${detail:+ :: $detail}"
}

totals() {
  local out="Totals:" k var v
  for k in APPLIED ALREADY-OK WOULD-APPLY SKIPPED NOT-FOUND; do
    var="COUNT_${k//-/_}"
    eval "v=\${$var:-}"
    [ -n "$v" ] && out+=" $k=$v"
  done
  printf '\n%s\n' "$out"
}

need_adb() {
  command -v adb >/dev/null 2>&1 || { echo "adb not found in PATH — install Android platform-tools" >&2; exit 2; }
  local n
  n=$(adb devices | awk 'NR>1 && $2=="device"' | wc -l | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    echo "no authorized adb device — connect (USB or 'adb pair' + 'adb connect') and retry" >&2; exit 2
  fi
  if [ "$n" -gt 1 ] && [ -z "${ANDROID_SERIAL:-}" ]; then
    echo "multiple adb devices — export ANDROID_SERIAL=<serial> to pick one" >&2; exit 2
  fi
}

# ---- cached package-state reads (call pm_load once after need_adb) -----------
_PM_ALL="" _PM_USER="" _PM_DISABLED=""
pm_load() {
  _PM_ALL=$(adb shell pm list packages -u </dev/null | tr -d '\r')       # present on device, incl. uninstalled-for-user
  _PM_USER=$(adb shell pm list packages </dev/null | tr -d '\r')         # installed for user 0 (incl. disabled)
  _PM_DISABLED=$(adb shell pm list packages -d </dev/null | tr -d '\r')  # disabled
}
pkg_on_device()      { grep -Fqx "package:$1" <<<"$_PM_ALL"; }
pkg_installed_user() { grep -Fqx "package:$1" <<<"$_PM_USER"; }
pkg_disabled()       { grep -Fqx "package:$1" <<<"$_PM_DISABLED"; }

# live (uncached) check — use to verify right after a mutation
pkg_installed_user_live() {
  adb shell pm list packages --user 0 "$1" </dev/null | tr -d '\r' | grep -Fqx "package:$1"
}
pkg_disabled_live() {
  adb shell pm list packages -d "$1" </dev/null | tr -d '\r' | grep -Fqx "package:$1"
}

# ---- config readers -----------------------------------------------------------
debloat_pkgs() { # the 176-package Canta export
  python3 -c 'import json,sys
for a in json.load(open(sys.argv[1]))["apps"]: print(a["packageName"])' "$DEBLOAT_LIST"
}
keep_pkgs() { # keep_pkgs exceptions|mustStayEnabled
  python3 -c 'import json,sys
for e in json.load(open(sys.argv[1]))[sys.argv[2]]: print(e["packageName"])' "$KEEP_LIST" "$1"
}

# ---- arg parsing: dry-run is the DEFAULT --------------------------------------
parse_apply() {
  DRY=1
  local a
  for a in "$@"; do
    case "$a" in
      --apply)   DRY=0 ;;
      --dry-run) DRY=1 ;;
      -h|--help) sed -n '2,${/^#/!q;s/^# \{0,1\}//p;}' "$0"; exit 0 ;;
      *) echo "unknown arg: $a (use --dry-run | --apply)" >&2; exit 2 ;;
    esac
  done
  [ "$DRY" -eq 1 ] && echo "DRY-RUN (default) — nothing will change; pass --apply to mutate." && echo
}
