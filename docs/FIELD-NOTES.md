# OPPO Find X9 — Field Notes: Issues, Diagnostics & Mitigations

Reference log of issues encountered on OPPO Find X9 / X9 Ultra (ColorOS 15/16, Android 16) and what worked to debug or work around them. Everything in `scripts/` and the README's manual phases was derived from these entries.

Primary device: **Find X9 Ultra** (`CPH2841`, ColorOS V16.1.0, build `CPH2841_16.0.8.306(EX01)`, Android 16, SG / en-SG, security patch 2026-06-01 — `ro.vendor.oplus.market.name` reports *OPPO Find X9 Ultra*). Findings should port across the Find X9 series / ColorOS 15–16.

---

## 1. Lockscreen "Add widget" picker hangs forever — now a deliberate state

> **Canonical decision (updated 2026-07):** the owner uses neither lockscreen widgets nor Live Alerts, so the Pantanal stack is kept **disabled** (`keepDisabled` in `config/keep-installed.json`) and this hang is **expected, not a bug to fix**. `pantanal.ums` + `uiengine` are removal-blocked on ColorOS 16, so `pm disable-user` is the durable off-switch; `keyguard.style.widgets` is uninstalled-for-user. The mitigation below is retained for anyone who *does* want the surface back — move the three packages to `mustStayEnabled` and run `02`.

- **Symptom:** After Canta/Shizuku debloating, opening the lockscreen widget picker spins indefinitely with no error.
- **Diagnostics:**
  - `adb logcat` shows three `ActivityThread: Failed to find provider info for com.oplus.pantanal.ums.{statictis,track,card.configuration.provider}` lines (the "statictis" typo is literal) immediately before `PantaCard.Lock.PantanalClient: init`.
  - Picker is rendered inline inside `com.oplus.wallpapers/.themes.edit.ThemeEditActivity` via the PantanalClient SDK, not a separate Activity.
- **Root cause:** Picker depends on two packages that get disabled during debloating:
  - `com.oplus.pantanal.ums` — owns the widget catalog ContentProvider; without it `PantanalClient` inits with `loadTimeout=-1`. Also the shared "seedling" engine behind Fluid Cloud / Live Alerts, so disabling it turns off both surfaces at once.
  - `com.oplus.uiengine` — owns the Epona IPC bus used by Pantanal.
- **Mitigation (available, NOT applied by default — this re-enables lockscreen widgets + Live Alerts):**
  ```
  adb shell cmd package install-existing com.oplus.keyguard.style.widgets   # if uninstalled-for-user
  adb shell pm enable com.oplus.pantanal.ums
  adb shell pm enable com.oplus.uiengine
  adb shell pm enable com.oplus.keyguard.style.widgets
  adb shell am force-stop com.oplus.wallpapers
  ```
- **Note:** `com.oplus.keyguard.style.widgets` ("InspirationWidget") uses Pantanal — needed alongside the other two, but enabling it alone is not sufficient. Confirmed safe to keep disabled: `com.oplus.metis`, `com.daemon.shelper`, `com.oplus.omoji`, `com.coloros.ocs.opencapabilityservice`, `com.oplus.aimemory`, `com.heytap.pictorial`.

---

## 2. HANS freezes apps despite AOSP "Don't optimize" whitelist

- **Symptom:** Background apps (widgets, sync, alarms, observers) silently stop firing for 30+ minute stretches even after being whitelisted in Android's standard battery optimization screen.
- **Diagnostics:**
  - `dumpsys deviceidle whitelist` shows the app present.
  - Standby bucket = 5 (EXEMPTED), no appops restrictions — all AOSP-level diagnostics report "no restrictions."
  - Only signal is `adb logcat | grep "OplusHansManager.*<uid>"` showing `F enter` / `F exit` / `F stay=<seconds>` events.
  - Vendor dumpsys (`oplus_freeze`, `oplus.hans.IHansComunication`) is locked and inaccessible.
- **Root cause:** ColorOS `OplusHansManager` ("Hyper Application Network Sleeping") runs independently of the AOSP deviceidle whitelist. Only `impUids` entries with reason `visibleActivity` / `launcher` / `floatWindow` / `vpn` / `input` are HANS-exempt; everything else is freeze-eligible. Blocks non-wakeup AlarmManager, ContentObserver callbacks, broadcast delivery.
- **Mitigation:** Add the app to ColorOS battery management's **"Don't optimize"** list (this is a *separate* UI from AOSP battery optimization). This maps to the HANS exemption.
- **Originally discovered:** Etar calendar widget freezing at last-rendered state because Etar was HANS-frozen ~32 min per cycle.

---

## 3. Lawnchair caches collection-widget adapters

- **Symptom:** Collection widgets (Etar event list, anything backed by `ListView` / `GridView` / `AdapterViewFlipper`) display stale content even after the provider pushes fresh `RemoteViews`. Force-stopping the provider app doesn't help; sending APPWIDGET_UPDATE broadcasts only refreshes the parent layout, not the list rows.
- **Diagnostics:**
  - `dumpsys activity services <pkg>` shows `(nothing)` — no bound `RemoteViewsService`, but list still shows old items.
  - Manually broadcast `APPWIDGET_UPDATE` → outer layout refreshes, inner list does not.
- **Root cause:** Lawnchair's `AppWidgetHost` caches the `RemoteViewsAdapter` connection. Even when the provider pushes a new `setRemoteAdapter` with the same intent, Lawnchair reuses the existing cached connection and never calls `onDataSetChanged` on the factory. Only `notifyAppWidgetViewDataChanged()` from the provider's *own running process* triggers a list-content refresh. Not broadcast-fixable.
- **Mitigation (pick one):**
  - (a) Keep the provider app alive with a live ContentObserver so it can call `notifyAppWidgetViewDataChanged` itself — requires HANS exemption (see #2).
  - (b) Physically reset the adapter: long-press widget → resize handle → drag and release.
  - (c) Remove and re-add the widget.
  - (d) Switch to a different launcher (stock OPPO, Niagara, KISS) — this is Lawnchair-specific caching behavior.

---

## 4. Camera preview thumbnail no-ops when OPPO gallery is uninstalled

- **Symptom:** Tapping the small preview thumbnail inside the Camera app (last-shot shortcut) silently does nothing — no chooser, no fallback, no toast.
- **Diagnostics:**
  - Filter logcat for `ActivityTaskManager:I` while tapping. You'll see:
    ```
    START ... act=com.android.camera.action.REVIEW typ=image/heic
              pkg=com.coloros.gallery3d
              cmp=com.coloros.gallery3d/com.oppo.gallery3d.app.ViewGallery
    ```
    followed by silence and `result code=0`.
  - `pm list packages -u` confirms the package exists on system partition but is uninstalled-for-user.
- **Root cause:** The Camera intent pins both `pkg` AND `cmp` to `com.coloros.gallery3d`. The explicit component bypasses the resolver entirely, so registering a different default gallery (Aves, Snapseed, etc.) does nothing. Cannot be remapped without root.
- **Mitigation (works, deliberately not applied):**
  ```
  adb shell cmd package install-existing com.coloros.gallery3d
  ```
  APK is still on the system partition, just removed per-user. OPPO Gallery is only invoked from the camera preview — won't take over as default elsewhere.
- **Canonical decision:** the broken preview is *accepted*. Reinstating OPPO Gallery was tried and reverted; the only other escape is a third-party camera app (generic `VIEW` intents), rejected as not worth the trust tradeoff. `com.coloros.gallery3d` stays in the debloat list and `99-verify-all.sh` expects it uninstalled.

---

## 5. Camera QR mode is hardcoded to the GMS barcode proxy

- **Symptom:** Camera's QR mode shows a GMS module-download dialog that fails, or does nothing, on a device with Play Store debloated.
- **Diagnostics:** logcat shows the camera launching `com.google.android.gms/.mlkit.barcode.ui.PlatformBarcodeScanningActivityProxy` by explicit component, then `DynamicModuleDownloader: Zapp module request failed: null` — the ML Kit Barcode UI module download is delivered through Play (`com.android.vending`), which is uninstalled.
- **Root cause:** Hardcoded `ComponentName`, not resolved through `queryIntentActivities` — cannot be remapped to a third-party scanner without root.
- **Mitigation (one-time):**
  ```
  adb shell cmd package install-existing com.android.vending
  # open Camera → QR mode once; the module downloads and stays cached
  adb shell pm uninstall --user 0 com.android.vending
  ```
- **Alternative:** route a third-party scanner (e.g. `com.secuso.privacyFriendlyCodeScanner`) from another surface — launcher, fingerprint quick-launch slots (`fp_ql_item_key_item_position_key_0..4` in secure settings), or a hardware key (see #6).

---

## 6. Hardware keys: Quick Button is remappable, Snap Key is not (directly)

- **Quick Button (right side, pressure-sensitive "Camera Control"):** emits standard `KEYCODE_CAMERA` (27). **Key Mapper** (`io.github.sds100.keymapper`, accessibility service) can intercept the press and launch an arbitrary app. ~95% reliable, even overnight (accessibility services are less aggressively frozen by HANS). Caveats: the Camera app may flash briefly before Key Mapper cancels it; the swipe and pressure channels are separate input streams Key Mapper cannot see — only the press is interceptable. **This is the recommended remap target.**
- **Snap Key (left side):** handled in vendor code below the input layer — emits no public keycode, so Button Mapper / Key Mapper see nothing. Settings offers only a preset list: AI Mind Space, Camera, Voice Recorder, Torch, Screenshot, Translate, Sound Mode, Do Not Disturb. No public root for the Find X9 series as of May 2026.
  - **Workaround — DND + Tasker indirection:** bind Snap Key to "Do Not Disturb"; a Tasker profile watches DND-on → launches the target app → immediately reverts DND. ~90% reliable with Tasker's **Run In Foreground** enabled (~70% without). The bottleneck is ColorOS process management (HANS + memory optimization), not Tasker — give Tasker the "Don't optimize" exemption (#2).
  - **"Translate" preset silent no-op:** the preset fires an explicit-component intent at OPPO/Breeno Translate; if that package is stripped (common on Global builds) the button does nothing — installing Google Translate doesn't help because the resolver never runs. Same hardcoded-component pattern as #4/#5.

---

## 7. IR Remote app is download-on-demand, not preinstalled

- **Symptom:** Find X9 has IR hardware (`android.hardware.consumerir`, `/dev/oplus_consumer_ir`) but no IR Remote app anywhere — absent even from `pm list packages -u`, so there is nothing for adb to enable.
- **Root cause:** The native app, `com.oplus.consumerIRApp` ("IR Remote", launcher activity `.navigation.LauncherActivity`), is fetched on demand from the OPPO App Market (`com.heytap.market`) on first use. Debloating the Market removes the delivery channel.
- **Red herrings:** `com.oplus.remotecontrol` is remote *assistance* (screen share, no launcher activity); `com.oplus.atlas` is a background service with zero activities. Neither holds `android.permission.TRANSMIT_IR` — the definitive identifier of the real IR app.
- **Mitigation (canonical):** sideload the APK via `scripts/fetch-apk.sh com.oplus.consumerIRApp` and verify the Oplus signature before `adb install` — it works because the app is first-party for this ROM, while third-party IR apps hit an IR-API block. `com.heytap.market` itself is deliberately kept **disabled** (`keepDisabled` in `config/keep-installed.json`): it phones home, and sideloading covers its only legitimate job.

---

## 8. Aurora Store: "expected url scheme http or https" on every install

- **Symptom:** Every download in Aurora Store fails instantly with `expected url scheme http or https but no scheme was found for ""`.
- **Root cause:** Stale/expired *anonymous session token* — the delivery response comes back with a blank download URL. Not an unknown-sources or network problem.
- **Mitigation:** Account → log out → log back in (anonymous). A misconfigured Settings → Network proxy/vending URL causes the same symptom — check it if relog doesn't fix it.
- **Diagnostic dead ends (don't repeat):** the error is a caught OkHttp exception rendered only in Aurora's UI — logcat shows nothing; `run-as com.aurora.store` is blocked on release builds, so prefs can't be read over adb.

---

## 9. ColorOS "Restricted activity" battery toggle is invisible to ADB

- Toggling Settings → Battery → [app] → "Restricted activity" changes **no** standard AOSP signal: `cmd appops get <pkg> RUN_ANY_IN_BACKGROUND` stays `allow`, the standby bucket stays 10 (ACTIVE, not 45 RESTRICTED), and the app is not added to any deviceidle list. Enforcement is HANS/Athena-internal (`dumpsys athenaservice` exposes only `config` without root).
- Practical consequence: you cannot script or verify this state — the Settings UI is the only source of truth, and the only ADB-visible proxies are behavioral (no jobs/alarms firing, no batterystats accrual over hours).

---

## 10. EU loudness warning cannot be durably disabled

- `adb shell settings put global audio_safe_volume_state 1` (values: 0=NOT_CONFIGURED, 1=DISABLED/user-dismissed, 2=INACTIVE, 3=ACTIVE) silences the EN 50332 "safe volume" warning that re-arms on USB-C DACs — but on ColorOS 16 the key **does not persist across reboots**: it returns to 3 (armed).
- **Canonical decision:** dropped from managed settings (`03-settings.sh` controls nothing because of this). Re-run the one-liner per boot if the warning bothers you that day; chasing persistence (device_config, props) wasn't worth it without root.

---

## 11. App launch counts for home-screen planning

- `adb shell dumpsys usagestats` → parse `package=… appLaunchCount=N` lines. Buckets are **calendar-aligned** (daily / weekly / calendar-month / yearly), not rolling — the yearly bucket is the best habitual-use signal. No rolling 30-day window exists without root (`/data/system/usagestats/` is permission-denied; `cmd usagestats` has no query-by-range).
- Exclude launchers (`app.lawnchair`, `com.android.launcher`) from the counts — recents/home invocations inflate them.

---

## Cross-cutting notes

- **Canta/Shizuku debloating side effects:** several issues here (#1, #4, #5, #7) are post-debloat regressions caused by removing packages with non-obvious dependencies. When debugging weird ColorOS behavior after debloating, always check `pm list packages -u` for both presence *and* per-user install state.
- **HANS is the silent killer:** any "background doesn't run / observer doesn't fire / alarm doesn't trigger" symptom should suspect HANS first, even when every AOSP whitelist check passes. Only `OplusHansManager` logcat lines expose the freeze state.
- **Silent no-op on a system-UI tap** → filter logcat for `ActivityTaskManager:I` and look for a hardcoded `cmp=` pointing at a debloated package.
- **`pm disable-user` vs `pm uninstall --user 0`:** two non-root debloat mechanisms — same end-state for callers, differing in app-data preservation (disable keeps it) and reversibility (`pm enable` vs `cmd package install-existing`). Uninstall-for-user may be undone by major OTAs — re-run `01-debloat.sh` + `99-verify-all.sh` after every ColorOS update.
