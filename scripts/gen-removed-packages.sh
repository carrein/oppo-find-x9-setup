#!/usr/bin/env bash
# gen-removed-packages.sh — regenerate docs/removed-packages.md from the config files.
#
#   * Pure function of config/debloat-list.json (the uninstall-for-user set) and
#     config/keep-installed.json (the keepDisabled set). Reads NOTHING from a device,
#     so the generated doc always matches canon — run it after editing either config.
#   * Groups the uninstall list by vendor and lists the disabled set with its reasons.
#   * No adb, no root; python3 stdlib only.
#
# Usage: scripts/gen-removed-packages.sh
set -u
source "$(dirname "$0")/lib/common.sh"   # REPO_ROOT, DEBLOAT_LIST, KEEP_LIST

OUT="$REPO_ROOT/docs/removed-packages.md"
python3 - "$DEBLOAT_LIST" "$KEEP_LIST" "$OUT" <<'PY'
import json, sys
debloat_path, keep_path, out_path = sys.argv[1:4]
debloat = sorted(a["packageName"] for a in json.load(open(debloat_path))["apps"])
kd = json.load(open(keep_path))["keepDisabled"]

def grp(p):
    if p.startswith(("com.google.", "com.android.hotwordenrollment")): return "Google / GMS"
    if p.startswith("com.coloros."): return "ColorOS"
    if p.startswith("com.oplus."): return "Oplus"
    if p.startswith(("com.heytap.", "com.oppo.")): return "HeyTap / OPPO"
    if p.startswith("com.facebook."): return "Facebook"
    if p.startswith(("com.microsoft", "com.microsoftsdk")): return "Microsoft"
    if p.startswith(("com.qualcomm.", "com.qti.")): return "Qualcomm"
    if p.startswith("com.android."): return "AOSP / system"
    return "Other"

order = ["Google / GMS", "Oplus", "ColorOS", "HeyTap / OPPO", "Facebook",
         "Microsoft", "Qualcomm", "AOSP / system", "Other"]
groups = {k: [] for k in order}
for p in debloat:
    groups[grp(p)].append(p)

L = []
def w(s=""): L.append(s)

w("# Removed packages — full inventory")
w()
w("Everything this playbook takes off the device, split by Canta's two mechanisms. "
  "**Generated from `config/debloat-list.json` + `config/keep-installed.json`** — the JSON is the "
  "source of truth; this file is the readable companion. It is checked against a live device by "
  "`scripts/99-verify-all.sh`. Regenerate after editing either config:")
w()
w("```")
w("scripts/gen-removed-packages.sh")
w("```")
w()
w("Reference device: **Find X9 Ultra** (`CPH2841`, ColorOS V16.1.0, build `CPH2841_16.0.8.306`, "
  "Android 16, SG). Package availability varies by region/build — absent packages report `NOT-FOUND` "
  "harmlessly and are simply skipped.")
w()
w(f"**Totals: {len(debloat)} uninstalled-for-user + {len(kd)} disabled = {len(debloat) + len(kd)}.**")
w()
w("---")
w()
w("## Disabled — `pm disable-user --user 0`")
w()
w("Data preserved, reversible with `pm enable`. Kept disabled instead of uninstalled because the app "
  "data should survive, or because the package is removal-blocked on ColorOS 16 and disable is the only "
  "durable off-switch. Source: the `keepDisabled` set in `config/keep-installed.json`.")
w()
w("| Package | Why it's kept disabled |")
w("|---|---|")
for e in kd:
    reason = e["reason"].replace("|", "\\|")
    w(f"| `{e['packageName']}` | {reason} |")
w()
w("> **Note:** `com.oplus.keyguard.style.widgets` is currently **uninstalled-for-user** on the reference "
  "device (a stronger off-state than disabled); `keepDisabled` accepts disabled *or* uninstalled-for-user "
  "as a valid \"not active\" state.")
w()
w("---")
w()
w("## Uninstalled-for-user — `pm uninstall --user 0`")
w()
w("The Canta export in `config/debloat-list.json`. The APK stays on the system partition, so any package "
  "comes back with `adb shell cmd package install-existing <pkg>`; the target's app data is wiped. "
  "Grouped by vendor:")
w()
for k in order:
    if groups[k]:
        w(f"### {k} ({len(groups[k])})")
        w(" · ".join(f"`{p}`" for p in groups[k]))
        w()

open(out_path, "w").write("\n".join(L).rstrip() + "\n")
print(f"wrote {out_path}: {len(debloat)} uninstalled + {len(kd)} disabled = {len(debloat) + len(kd)}")
PY