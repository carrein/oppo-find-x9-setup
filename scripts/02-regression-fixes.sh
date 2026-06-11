#!/usr/bin/env bash
# 02-regression-fixes.sh — restore the packages that debloating breaks, idempotently.
#
#   * --dry-run is the DEFAULT: reports what WOULD change, mutates nothing. --apply to mutate.
#   * Ensures every package in config/keep-installed.json (both 'exceptions' and
#     'mustStayEnabled') is installed for user 0 AND enabled:
#       uninstalled-for-user  →  cmd package install-existing <pkg>
#       disabled              →  pm enable <pkg>
#   * Fixes covered: camera last-shot preview thumbnail (com.coloros.gallery3d) and the
#     lockscreen 'Add widget' picker hang (pantanal.ums + uiengine + keyguard.style.widgets).
#   * Force-stops com.oplus.wallpapers once if any lockscreen-widget package changed —
#     the picker is rendered inside that process and caches the broken state.
#
# Usage: scripts/02-regression-fixes.sh [--dry-run|--apply]
set -u
source "$(dirname "$0")/lib/common.sh"

parse_apply "$@"
need_adb
pm_load

restart_wallpapers=0

ensure_active() { # ensure_active <pkg>
  local pkg="$1" out
  if ! pkg_on_device "$pkg"; then
    report NOT-FOUND regression-fix "$pkg" "not on this build/region"
    return
  fi
  if ! pkg_installed_user "$pkg"; then
    if [ "$DRY" -eq 1 ]; then
      report WOULD-APPLY regression-fix "$pkg" "cmd package install-existing"
    else
      out=$(adb shell cmd package install-existing "$pkg" </dev/null 2>&1 | tr -d '\r')
      if pkg_installed_user_live "$pkg"; then
        report APPLIED regression-fix "$pkg" "install-existing"
        restart_wallpapers=1
      else
        report SKIPPED regression-fix "$pkg" "did not verify: $out"
      fi
    fi
  elif pkg_disabled "$pkg"; then
    if [ "$DRY" -eq 1 ]; then
      report WOULD-APPLY regression-fix "$pkg" "pm enable"
    else
      adb shell pm enable "$pkg" </dev/null >/dev/null 2>&1
      if ! pkg_disabled_live "$pkg"; then
        report APPLIED regression-fix "$pkg" "pm enable"
        restart_wallpapers=1
      else
        report SKIPPED regression-fix "$pkg" "did not verify"
      fi
    fi
  else
    report ALREADY-OK regression-fix "$pkg" "installed + enabled"
  fi
}

for src in exceptions mustStayEnabled; do
  while IFS= read -r pkg; do ensure_active "$pkg"; done < <(keep_pkgs "$src")
done

if [ "$restart_wallpapers" -eq 1 ]; then
  adb shell am force-stop com.oplus.wallpapers </dev/null >/dev/null 2>&1
  report APPLIED regression-fix com.oplus.wallpapers "force-stop (lockscreen widget picker caches broken state)"
fi

totals
