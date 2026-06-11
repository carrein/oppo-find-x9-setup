#!/usr/bin/env bash
# 01-debloat.sh — uninstall-for-user-0 every package in config/debloat-list.json, idempotently.
#
#   * --dry-run is the DEFAULT: reports what WOULD change, mutates nothing. --apply to mutate.
#   * Idempotent: reads current state first; already-gone packages report ALREADY-OK.
#   * Dependency traps listed in config/keep-installed.json are SKIPPED, never uninstalled
#     (removing them breaks the camera preview / lockscreen widgets — see that file's reasons).
#   * Uses `pm uninstall --user 0` (Canta's mechanism): APK stays on the system partition,
#     reversible with `cmd package install-existing <pkg>`. App data of the target is wiped.
#   * Packages absent from this build/region report NOT-FOUND and are skipped, never guessed.
#
# Run order on a fresh device:  00-recon.sh  →  01-debloat.sh --dry-run  →  01-debloat.sh --apply
#                               →  02-regression-fixes.sh --apply  →  03-settings.sh --apply
#                               →  manual phases (README 4–7)  →  99-verify-all.sh
#
# Usage: scripts/01-debloat.sh [--dry-run|--apply]
set -u
source "$(dirname "$0")/lib/common.sh"

parse_apply "$@"
need_adb
pm_load

# exception set: in the debloat list but load-bearing (camera preview etc.)
declare -A KEEP=()
while IFS= read -r pkg; do KEEP[$pkg]=1; done < <(keep_pkgs exceptions)
while IFS= read -r pkg; do KEEP[$pkg]=1; done < <(keep_pkgs mustStayEnabled)

while IFS= read -r pkg; do
  if [ -n "${KEEP[$pkg]:-}" ]; then
    report SKIPPED debloat "$pkg" "dependency trap — see config/keep-installed.json"
  elif ! pkg_on_device "$pkg"; then
    report NOT-FOUND debloat "$pkg" "not on this build/region"
  elif ! pkg_installed_user "$pkg"; then
    report ALREADY-OK debloat "$pkg" "already uninstalled for user 0"
  elif [ "$DRY" -eq 1 ]; then
    report WOULD-APPLY debloat "$pkg" "pm uninstall --user 0"
  else
    out=$(adb shell pm uninstall --user 0 "$pkg" </dev/null 2>&1 | tr -d '\r')
    if [ "$out" = "Success" ] && ! pkg_installed_user_live "$pkg"; then
      report APPLIED debloat "$pkg"
    else
      report SKIPPED debloat "$pkg" "did not verify: $out"
    fi
  fi
done < <(debloat_pkgs)

totals
echo
echo "Next: scripts/02-regression-fixes.sh --apply  (restores the dependency traps debloating breaks)"
