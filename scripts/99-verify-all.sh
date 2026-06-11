#!/usr/bin/env bash
# 99-verify-all.sh — read-only verification of the whole playbook. Makes no changes.
#
#   * Re-reads every controlled state fresh from the device and prints a PASS/FAIL line
#     per check: the 176-package debloat list (aggregated; failures itemized), the
#     dependency-trap packages (installed + enabled), and the deliberately-disabled set.
#   * com.android.vending counts as PASS when uninstalled — the canonical state. If you
#     just ran the one-time camera-QR module download (README Phase 7) and it's still
#     installed, this flags it so you remember to uninstall it again.
#   * Exit code: 0 = all checks pass, 1 = mismatches found.
#
# Usage: scripts/99-verify-all.sh
set -u
source "$(dirname "$0")/lib/common.sh"

need_adb
pm_load

pass=0 fail=0
check() { # check <label> <got> <want>
  local label="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    pass=$(( pass + 1 ))
    printf '[PASS] %-58s got=%s\n' "$label" "$got"
  else
    fail=$(( fail + 1 ))
    printf '[FAIL] %-58s got=%s want=%s\n' "$label" "$got" "$want"
  fi
}
note() { printf '[ -- ] %-58s %s\n' "$1" "$2"; }

echo "==== Debloat list (config/debloat-list.json) ===="
declare -A KEEP=()
while IFS= read -r pkg; do KEEP[$pkg]=1; done < <(keep_pkgs exceptions)
while IFS= read -r pkg; do KEEP[$pkg]=1; done < <(keep_pkgs mustStayEnabled)
gone=0 absent=0 still=0
while IFS= read -r pkg; do
  [ -n "${KEEP[$pkg]:-}" ] && continue   # asserted in the next section instead
  if ! pkg_on_device "$pkg"; then
    absent=$(( absent + 1 ))
  elif pkg_installed_user "$pkg"; then
    still=$(( still + 1 ))
    check "debloated: $pkg" "installed" "uninstalled-for-user"
  else
    gone=$(( gone + 1 ))
  fi
done < <(debloat_pkgs)
check "debloat list: packages still installed for user 0" "$still" "0"
note  "debloat list detail" "$gone uninstalled-for-user, $absent absent from this build (ok)"

echo
echo "==== Dependency traps (config/keep-installed.json) ===="
for src in exceptions mustStayEnabled; do
  while IFS= read -r pkg; do
    if ! pkg_on_device "$pkg"; then state="absent"
    elif ! pkg_installed_user "$pkg"; then state="uninstalled-for-user"
    elif pkg_disabled "$pkg"; then state="disabled"
    else state="installed+enabled"
    fi
    check "$pkg" "$state" "installed+enabled"
  done < <(keep_pkgs "$src")
done

echo
echo "==== Deliberately disabled (keepDisabled) ===="
while IFS= read -r pkg; do
  if ! pkg_on_device "$pkg"; then state="absent"
  elif ! pkg_installed_user "$pkg"; then state="uninstalled-for-user"
  elif pkg_disabled "$pkg"; then state="disabled"
  else state="enabled"
  fi
  if [ "$state" = "disabled" ] || [ "$state" = "uninstalled-for-user" ]; then
    check "$pkg" "$state" "$state"
  else
    check "$pkg" "$state" "disabled"
  fi
done < <(keep_pkgs keepDisabled)

echo
echo "==== One-time packages ===="
if pkg_installed_user com.android.vending; then
  check "com.android.vending (re-uninstall after QR module cached)" "installed" "uninstalled-for-user"
else
  check "com.android.vending" "uninstalled-for-user" "uninstalled-for-user"
fi

echo
printf '==== RESULT: %d PASS, %d FAIL ====\n' "$pass" "$fail"
exit $(( fail > 0 ? 1 : 0 ))
