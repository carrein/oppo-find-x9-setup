# ColorOS diagnostics cookbook

Non-root diagnostic commands that actually reveal something on ColorOS 15/16, collected while debugging the issues in [FIELD-NOTES.md](FIELD-NOTES.md). ColorOS hides most vendor state — this is the list of what *is* observable.

| Command / filter | Reveals |
|---|---|
| `adb logcat \| grep "OplusHansManager.*<uid>"` | HANS freeze state: `F enter` / `F exit` / `F stay=<seconds>` — the **only** non-root signal that ColorOS froze an app |
| logcat filter `ActivityTaskManager:I` while tapping a UI element | The exact intent fired (`START ... act=... pkg=... cmp=...`); a `cmp=` followed by silence and `result code=0` means the target package is missing for user 0 |
| `ActivityThread: Failed to find provider info for com.oplus.pantanal.ums.*` in logcat | Lockscreen widget picker inert because pantanal.ums is disabled — a deliberate state here, not a bug (FIELD-NOTES #1; the `statictis` typo is literal in the logs) |
| `DynamicModuleDownloader: Zapp module request failed: null` in logcat | A GMS dynamic-module download is blocked because `com.android.vending` is uninstalled (camera QR case) |
| `adb shell pm list packages -u` | Packages present on the system partition including uninstalled-for-user — the first check after any post-debloat weirdness |
| `adb shell pm list packages -d` | Disabled packages (the other debloat mechanism) |
| `adb shell dumpsys deviceidle whitelist` | AOSP battery-optimization whitelist — does **not** reflect HANS or the ColorOS "Restricted activity" toggle |
| `adb shell cmd appops get <pkg> RUN_ANY_IN_BACKGROUND` | AOSP background restriction — stays `allow` on ColorOS even when the app is UI-Restricted |
| `adb shell am get-standby-bucket <pkg>` | Standby bucket: 5 = EXEMPTED, 10 = ACTIVE, 45 = RESTRICTED — also unaffected by the ColorOS toggle |
| `adb shell dumpsys usagestats` (grep `appLaunchCount`) | Per-app launch counts; buckets are calendar-aligned (daily/weekly/month/yearly), **not** rolling |
| `adb shell dumpsys activity services <pkg>` | Whether a `RemoteViewsService` is bound — `(nothing)` while a list widget still renders = stale cached adapter (Lawnchair issue) |
| `dumpsys athenaservice` / `dumpsys oplus_freeze` / `oplus.hans.IHansComunication` | Locked or config-only without root — don't bother |
| `apksigner verify --print-certs <apk>` | Signature of a mirror-downloaded APK; compare digests before installing (see `scripts/fetch-apk.sh`) |
| `adb pair <ip>:<pairPort> <code>` then `adb connect <ip>:<connectPort>` | Wireless debugging (works fine over a tailnet); note the two ports differ |

## Heuristics

1. **Any "background doesn't run / observer doesn't fire / alarm doesn't trigger" symptom → suspect HANS first**, even when every AOSP-level check (deviceidle, appops, standby bucket) reports no restrictions. The fix is the ColorOS battery "Don't optimize" list, not the AOSP one.
2. **Any silent no-op when tapping a system-UI element → trace the intent** with the `ActivityTaskManager:I` filter and look for a hardcoded `cmp=` pointing at a package you debloated. ColorOS pins explicit components (camera→gallery, camera→GMS QR, Snap-Key→Translate) instead of using the resolver.
