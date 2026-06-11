#!/usr/bin/env bash
# 00-recon.sh — read-only snapshot of the device before/after the playbook. Mutates nothing.
#
#   * Records device identity, ColorOS/Android versions, package-state counts,
#     drift between config/debloat-list.json and the device's actual state,
#     dependency-trap package states, and the watched settings.
#   * Writes recon-YYYYMMDD-HHMMSS.md next to the repo root (gitignored — the
#     report contains your device serial).
#
# Usage: scripts/00-recon.sh
set -u
source "$(dirname "$0")/lib/common.sh"

need_adb
pm_load

OUT="$REPO_ROOT/recon-$(date +%Y%m%d-%H%M%S).md"
exec > >(tee "$OUT")

echo "# Device recon — $(date '+%Y-%m-%d %H:%M:%S')"
echo
echo "## Identity"
echo "- model:   $(adb shell getprop ro.product.model </dev/null | tr -d '\r')"
echo "- market:  $(adb shell getprop ro.vendor.oplus.market.name </dev/null | tr -d '\r')"
echo "- android: $(adb shell getprop ro.build.version.release </dev/null | tr -d '\r')"
echo "- coloros: $(adb shell getprop ro.build.version.oplusrom </dev/null | tr -d '\r')"
echo "- build:   $(adb shell getprop ro.build.display.id </dev/null | tr -d '\r')"
echo "- serial:  $(adb shell getprop ro.serialno </dev/null | tr -d '\r')  (report is gitignored for this reason)"
echo
echo "## Package-state counts"
total=$(grep -c . <<<"$_PM_ALL")
user=$(grep -c . <<<"$_PM_USER")
disabled=$(grep -c . <<<"$_PM_DISABLED" || true)
echo "- on device (incl. uninstalled-for-user): $total"
echo "- installed for user 0:                   $user"
echo "- uninstalled-for-user:                   $(( total - user ))"
echo "- disabled:                               $disabled"
echo
echo "## Drift vs config/debloat-list.json"
echo "Packages in the debloat list that are still installed for user 0 (candidates for 01-debloat.sh --apply):"
drift=0
while IFS= read -r pkg; do
  if pkg_installed_user "$pkg"; then
    echo "- $pkg"
    drift=$(( drift + 1 ))
  fi
done < <(debloat_pkgs)
[ "$drift" -eq 0 ] && echo "- none — device matches the list."
echo
echo "## Package-policy states (see config/keep-installed.json)"
for src in exceptions mustStayEnabled keepDisabled; do
  while IFS= read -r pkg; do
    if ! pkg_on_device "$pkg"; then state="ABSENT FROM DEVICE"
    elif ! pkg_installed_user "$pkg"; then state="uninstalled-for-user"
    elif pkg_disabled "$pkg"; then state="disabled"
    else state="installed + enabled"
    fi
    echo "- $pkg [$src]: $state"
  done < <(keep_pkgs "$src")
done
echo
echo "## Informational settings (not managed — audio_safe_volume_state does not persist across reboots)"
echo "- global audio_safe_volume_state: $(adb shell settings get global audio_safe_volume_state </dev/null | tr -d '\r')  (3 = warning armed, the post-reboot default)"
echo
echo "Report saved to: $OUT"
