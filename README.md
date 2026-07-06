# OPPO Find X9 (ColorOS) Privacy & Setup Playbook

A complete, ordered, **self-verifying** procedure to take an OPPO Find X9 from stock ColorOS to a debloated, privacy-first daily driver **without root** — Canta-grade debloat (175 packages) with the dependency traps excepted, the post-debloat regressions triaged (fixed where wanted, deliberately accepted where not), ColorOS's background-freezer (HANS) tamed, hardware keys remapped, and apps sourced without a Google account. Hand this (and `scripts/`) to a person or an agent and run it top-to-bottom.

Every scriptable change is idempotent (safe to re-run; already-correct state reports `ALREADY-OK`) and reversible without reflashing — the APKs stay on the system partition, so `cmd package install-existing` undoes any removal. `scripts/99-verify-all.sh` re-reads the entire controlled state fresh from the device and prints a PASS/FAIL table — nothing is assumed, it's *checked*.

> **Scope & portability.** Verified on the **Find X9 Ultra** (`CPH2841`, ColorOS V16.1.0, build `CPH2841_16.0.8.306(EX01)`, Android 16, SG / en-SG, security patch 2026-06-01 — the unit's own `ro.vendor.oplus.market.name` reports *OPPO Find X9 Ultra*). The debloat list in `config/debloat-list.json` is this device's Canta export — package availability varies by region/build, and missing packages report `NOT-FOUND` harmlessly, so it ports across the Find X9 series. The scripts are plain bash + adb + python3 (stdlib only); no jq, no root, no Magisk, and no bash 4 — they run on macOS's stock bash 3.2.

> **No-root caveat (read this).** There is no public root for the Find X9 series. Everything here works within `adb shell` privileges. Some ColorOS state is simply unreachable — the "Restricted activity" battery toggle can be neither set nor read over adb, and HANS exemptions are UI-only. Those steps are flagged 🖥️ and verified behaviorally, not programmatically.

> **Governing principles:** ① **Nothing phones home that doesn't have to** — HeyTap/Google/Facebook/Microsoft preloads are uninstalled-for-user, not merely disabled. ② **Every change is reversible without a reflash** — uninstall-for-user keeps the APK on the system partition; `config/keep-installed.json` records every dependency trap and every deliberately-disabled package so a re-run never breaks the camera and never silently re-enables what you turned off. ③ **Verify, don't assume** — and when background behavior breaks anyway, suspect HANS first, because every AOSP-level check will lie to you.

---

## 0. How to use this

**Legend:** 🔒 adb mutating (`--apply`) · 👤 read-only · 🖥️ on-device UI (not scriptable) · 🟧 personal choice (your launcher/apps may differ).

Prerequisites: `adb` (platform-tools) on the PATH, `python3`, USB or wireless debugging authorized (`adb pair <ip>:<port> <code>` → `adb connect <ip>:<port>` — the ports differ). With multiple devices attached, `export ANDROID_SERIAL=<serial>`.

**Run order:** `00-recon.sh` (👤 snapshot) → `01-debloat.sh --dry-run` (👤 preview) → `01-debloat.sh --apply` (🔒) → `02-regression-fixes.sh --apply` (🔒) → `03-settings.sh --apply` (🔒) → manual phases 4–7 (🖥️) → `99-verify-all.sh` (👤 PASS/FAIL).

`--dry-run` is the **default** for every mutating script — nothing changes until you pass `--apply`. Every action logs one of **`APPLIED` / `ALREADY-OK` / `NOT-FOUND` / `SKIPPED` / `WOULD-APPLY`**, and `APPLIED` is only reported after the new state is re-read from the device. Recon reports are written to gitignored `recon-*.md` (they contain your serial).

### 🚫 Hard safety rules — never violate (each caused real breakage)

1. **The Pantanal lockscreen/Live-Alert stack (`com.oplus.pantanal.ums`, `com.oplus.uiengine`, `com.oplus.keyguard.style.widgets`) is deliberately disabled in this canon** — it uses neither lockscreen widgets nor Live Alerts. If you *do* use either, keep all three enabled: move them back to `mustStayEnabled` in `config/keep-installed.json` and run `02`. Turned off (as here), the lockscreen "Add widget" picker spins forever with no error and nothing in the UI tells you why — that hang is expected, not a bug (FIELD-NOTES #1).
2. **Never expect the Camera preview thumbnail to work without `com.coloros.gallery3d`.** The Camera pins both `pkg` and `cmp` to it — with it debloated (the canonical state here), the tap is a silent no-op and no default-gallery setting can help. That's a known, accepted cost, not a bug to chase (see [docs/FIELD-NOTES.md](docs/FIELD-NOTES.md) #4).
3. **Never trust the AOSP battery-optimization whitelist on ColorOS.** HANS freezes apps independently of it. The ColorOS battery "Don't optimize" list is a *separate* UI and the only exemption that counts.
4. **Never install a mirror-downloaded APK without `apksigner verify --print-certs`** and comparing the digest against a known-good publisher fingerprint. `scripts/fetch-apk.sh` refuses to install for exactly this reason.
5. **Never debug post-debloat weirdness without checking `pm list packages -u` first.** Half the "broken features" are explicit-component intents aimed at a package that's uninstalled-for-user.

---

## Phase 0 — Recon 👤 `scripts/00-recon.sh`

Read-only snapshot: device identity (model, ColorOS/Android versions), package-state counts, drift between `config/debloat-list.json` and the device's actual state, dependency-trap status, watched settings. Run it first on a fresh device and again any time the device feels "off" — the drift section tells you exactly what an OTA quietly re-installed.

**✅ Verify:** the report lists each `mustStayEnabled` package as `installed + enabled` (that set is currently empty), the `keepDisabled` set as `disabled` or `uninstalled-for-user`, and the drift section matches your expectations.

## Phase 1 — Debloat 🔒 `scripts/01-debloat.sh`

Uninstalls-for-user-0 every package in `config/debloat-list.json` — a real Find X9 Ultra's Canta export, 175 packages of HeyTap cloud/browser/music/ads, OPPO AI surfaces, Google apps and telemetry mainline modules, Facebook/Microsoft preloads, and Qualcomm test scaffolding. For the full removed-package inventory — both mechanisms, grouped by vendor and annotated — see [docs/removed-packages.md](docs/removed-packages.md).

| What | How it's handled |
|---|---|
| Dependency-trap exceptions (`config/keep-installed.json`) | `SKIPPED` with the reason, never uninstalled |
| `keepDisabled` set (`config/keep-installed.json` — HeyTap Market, the Pantanal stack, Chrome, and other phone-home surfaces) | `pm disable-user --user 0` — data preserved, reversible with `pm enable` |
| Packages not on your build/region | `NOT-FOUND`, harmless |
| Already-debloated packages | `ALREADY-OK` (idempotent re-runs) |
| Everything else | `pm uninstall --user 0`, re-checked, then `APPLIED` |

App data of removed packages is wiped (Canta semantics); the APKs stay on the system partition, so any package comes back with `adb shell cmd package install-existing <pkg>`.

> **⚠️ OTA behavior.** Major ColorOS updates re-install some uninstalled-for-user packages. Re-run `01` + `99` after every update.

**✅ Verify:** `scripts/01-debloat.sh` (dry-run) reports only `ALREADY-OK` / `SKIPPED` / `NOT-FOUND`.

## Phase 2 — Regression fixes 🔒 `scripts/02-regression-fixes.sh`

Restores what debloating breaks — learned the hard way, documented in [docs/FIELD-NOTES.md](docs/FIELD-NOTES.md). **Currently a no-op scaffold:** the one automated fix it used to carry (the lockscreen widget-picker restore) was retired when the Pantanal stack moved to `keepDisabled` — see below. The script still runs and reports `Totals:` with nothing to do; it stays numbered so re-enabling a surface later has a home.

> **Deliberately NOT fixed / accepted as-is.** Three regressions are known, fixable, and left broken on purpose:
> - **Lockscreen "Add widget" picker hangs** — `pantanal.ums` + `uiengine` + `keyguard.style.widgets` are deliberately disabled (lockscreen widgets + Live Alerts unused). To restore: move those three back to `mustStayEnabled` in `config/keep-installed.json` and run `02 --apply` (FIELD-NOTES #1).
> - **Camera preview thumbnail** stays a silent no-op — fixing it means reinstating OPPO Gallery (tried, reverted; FIELD-NOTES #4).
> - **IR Remote** has no on-device delivery channel because `com.heytap.market` stays disabled — sideload it with `scripts/fetch-apk.sh com.oplus.consumerIRApp` instead (FIELD-NOTES #7).

**One-time, manual** 🔒+🖥️ — camera **QR mode** uses a hardcoded GMS barcode proxy whose module downloads through the Play Store:

```bash
adb shell cmd package install-existing com.android.vending
# on the phone: open Camera → QR mode once (module downloads and stays cached)
adb shell pm uninstall --user 0 com.android.vending
```

**✅ Verify:** Camera → QR mode scans. (The preview thumbnail and the lockscreen "Add widget" picker staying dead is expected — see above.)

## Phase 3 — Settings 🔒 `scripts/03-settings.sh`

A scaffold, currently managing **nothing** — kept so future adb-scriptable settings have a numbered home with read-before-write semantics already built.

> **⚠️ Negative result worth keeping.** `global audio_safe_volume_state = 1` (kills the EU loudness warning that re-arms on USB-C DACs) was managed here until real-device experience showed it **does not persist across reboots** on ColorOS 16. Dropped from canon; the per-boot one-liner is `adb shell settings put global audio_safe_volume_state 1` (FIELD-NOTES #10).

**✅ Verify:** nothing to verify — the script reports `no settings under management`.

## Phase 4 — App sourcing without Google 🖥️ 🟧 `scripts/fetch-apk.sh`

- **Aurora Store** (anonymous login) for Play-only apps. If every download fails with *"expected url scheme http or https"*, the anonymous session token is stale — Account → log out → log back in. The error never reaches logcat; don't go looking.
- **`scripts/fetch-apk.sh <package.id>`** pulls an APK straight from the APKPure CDN (works when the web mirrors 403), decodes the CDN's declared filename/package so you can confirm the right app, and runs `apksigner verify --print-certs`. It **never installs** — compare the cert digest, then `adb install` yourself.
- **IR Remote:** `scripts/fetch-apk.sh com.oplus.consumerIRApp` — first-party Oplus signature (DN `O=Oplus, CN=AndroidTeam, OU=OSTeam, L=DongGuan, C=CN`); sideloading works because it's first-party for this ROM, while third-party IR apps hit an IR-API block. This is the **canonical** delivery path — `com.heytap.market` stays disabled.

**✅ Verify:** Aurora installs an app; `fetch-apk.sh` output shows the expected package id and a cert digest you recognize.

## Phase 5 — Background execution: HANS exemptions 🖥️

ColorOS's **HANS** freezer (`OplusHansManager`) silently freezes background apps for 30+ minute stretches — alarms, ContentObservers, and broadcasts just stop — *regardless* of the AOSP battery-optimization whitelist. There is no adb knob.

On the phone, add to **Settings → Battery → (app) → "Don't optimize"** (the ColorOS list, *not* the AOSP "unrestricted" screen): every app that must run in the background — calendar/widget providers (e.g. Etar), Tasker, Key Mapper, sync clients.

The separate **"Restricted activity"** toggle is invisible to adb in both directions — no script can set or verify it; check it by hand if an app still freezes.

**✅ Verify:** behaviorally — `adb logcat | grep "OplusHansManager.*<uid>"` shows no `F enter` for the exempted app's uid while it idles in the background.

## Phase 6 — Hardware keys 🖥️ 🟧

- **Quick Button (right, "Camera Control")** — emits `KEYCODE_CAMERA` (27). Install **Key Mapper**, enable its accessibility service, give it the Phase-5 exemption, record the press as a trigger → "Open App". ~95% reliable, even overnight. The Camera may flash briefly before the remap fires; only the press (not swipe/pressure) is interceptable. **Remap this one first.**
- **Snap Key (left)** — no public keycode (vendor-handled below the input layer); locked to a preset list. Workaround: bind it to **Do Not Disturb**, then a Tasker profile on DND-on → launch target app → revert DND. ~90% reliable with Tasker's *Run In Foreground* enabled, ~70% without. Don't bother with key-event interceptors — they see nothing.
- **Snap Key "Translate" preset** silently no-ops on builds where Breeno Translate is stripped — hardcoded component, not your debloat's fault.

**✅ Verify:** press each key 10×; Quick Button should land ≥9, Snap Key ≥8 with the phone awake.

## Phase 7 — Launcher & widgets 🖥️ 🟧

- **Lockscreen widgets** are intentionally off in this canon — the Pantanal stack (`pantanal.ums`/`uiengine`/`keyguard.style.widgets`) is kept disabled because neither lockscreen widgets nor Live Alerts are used, so the "Add widget" picker hangs (expected). To turn the surface back on, move those three back to `mustStayEnabled` and run `02`.
- **Lawnchair users:** collection widgets (event lists etc.) cache their `RemoteViewsAdapter` — fresh data won't render until the provider itself calls `notifyAppWidgetViewDataChanged()`. Either keep the provider alive (Phase-5 exemption + its own ContentObserver), or nudge the widget physically (long-press → drag a resize handle), or use a launcher without this cache (stock, Niagara, KISS).

**✅ Verify:** home-screen list widget shows an item created a minute ago after the provider refreshes. (Lockscreen widgets are intentionally disabled here — see above.)

## ✅ Verify everything `scripts/99-verify-all.sh`

Read-only; re-reads the full controlled state and prints `[PASS]`/`[FAIL]` per check — all 175 debloat-list packages (aggregated, failures itemized), the dependency-trap sets (`exceptions` + `mustStayEnabled`, currently empty) `installed+enabled`, the `keepDisabled` set not enabled (disabled or uninstalled-for-user both pass), `com.android.vending` back off after the QR one-time. Exits non-zero on any mismatch, so it works in a cron/CI hook.

---

## Caveats

- **The list is a snapshot.** `config/debloat-list.json` reflects one device on one firmware. New firmware ships new bloat — re-run `00-recon.sh` after updates and extend the list deliberately, not blindly.
- **`pm uninstall --user 0` wipes the target's app data.** Fine for bloat; if you want data-preserving removal for an experiment, use `pm disable-user --user 0` instead (reverse: `pm enable`).
- **Some breakage is chosen.** The camera preview thumbnail (needs OPPO Gallery back) and the loudness-warning suppression (doesn't survive reboot) are documented, fixable, and deliberately left broken. Don't "fix" them without re-reading FIELD-NOTES #4 and #10.
- **HANS wins eventually.** Even exempted apps get frozen occasionally (~90–95% reliability ceilings on the key remaps). That's the platform, not a config error.
- **ColorOS hides vendor state.** `dumpsys` for HANS/Athena is locked without root; some verifications here are necessarily behavioral. See [docs/diagnostics-cookbook.md](docs/diagnostics-cookbook.md) for what *is* observable.

## Layout

```
oppo-find-x9-setup/
├── README.md                    this playbook
├── config/
│   ├── debloat-list.json        canonical Canta export · 175 packages
│   └── keep-installed.json      package-state policy · dependency traps + the deliberately-disabled set, with a reason each
├── docs/
│   ├── removed-packages.md      readable inventory · 175 uninstalled + 10 disabled, grouped (generated)
│   ├── FIELD-NOTES.md           the issues log this playbook was distilled from
│   └── diagnostics-cookbook.md  non-root ColorOS diagnostics that actually work
└── scripts/
    ├── lib/common.sh            adb guard · status vocabulary · cached pm reads
    ├── 00-recon.sh              👤 snapshot + drift report
    ├── 01-debloat.sh            🔒 the list, minus the traps
    ├── 02-regression-fixes.sh   🔒 restores what debloating breaks (now a no-op scaffold)
    ├── 03-settings.sh           🔒 settings scaffold (currently none survive reboot)
    ├── fetch-apk.sh             APKPure CDN pull + signature check (never installs)
    ├── gen-removed-packages.sh  regenerate docs/removed-packages.md from config (no device)
    └── 99-verify-all.sh         👤 PASS/FAIL · exit 1 on mismatch
LICENSE (MIT)
```

*Distilled from a real device's debugging history. Package availability varies by region and firmware; verify every APK signature yourself. No warranty — read each script before pointing it at your phone.*
