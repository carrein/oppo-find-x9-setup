# Removed packages — full inventory

Everything this playbook takes off the device, split by Canta's two mechanisms. **Generated from `config/debloat-list.json` + `config/keep-installed.json`** — the JSON is the source of truth; this file is the readable companion. It is checked against a live device by `scripts/99-verify-all.sh`. Regenerate after editing either config:

```
scripts/gen-removed-packages.sh
```

Reference device: **Find X9 Ultra** (`CPH2841`, ColorOS V16.1.0, build `CPH2841_16.0.8.306`, Android 16, SG). Package availability varies by region/build — absent packages report `NOT-FOUND` harmlessly and are simply skipped.

**Totals: 175 uninstalled-for-user + 10 disabled = 185.**

---

## Disabled — `pm disable-user --user 0`

Data preserved, reversible with `pm enable`. Kept disabled instead of uninstalled because the app data should survive, or because the package is removal-blocked on ColorOS 16 and disable is the only durable off-switch. Source: the `keepDisabled` set in `config/keep-installed.json`.

| Package | Why it's kept disabled |
|---|---|
| `com.heytap.market` | OPPO App Market — phones home and is the storefront surface; disabled (not uninstalled) so app data survives. Its one legitimate job, delivering download-on-demand first-party apps (IR Remote, com.oplus.consumerIRApp), is covered by scripts/fetch-apk.sh sideloading with Oplus-signature verification instead. |
| `com.oplus.pantanal.ums` | Widget-catalog ContentProvider AND the Pantanal 'seedling' engine shared with Fluid Cloud / Live Alerts (the dynamic-island capsule). Deliberately disabled: the owner uses neither lockscreen widgets nor Live Alerts. Removal-BLOCKED on ColorOS 16, so pm disable-user is the only durable off-switch. Re-enable (02-regression-fixes.sh, after moving back to mustStayEnabled) ONLY if you start using either surface — otherwise the lockscreen 'Add widget' picker hangs forever with no error (FIELD-NOTES #1). |
| `com.oplus.uiengine` | Epona IPC bus behind Pantanal. Disabled alongside pantanal.ums for the same reason (lockscreen widgets + Live Alerts unused); enabling one without the other still hangs the widget picker. |
| `com.oplus.keyguard.style.widgets` | Lockscreen widget plugin ('InspirationWidget' in logs) that talks to Pantanal. Currently uninstalled-for-user on the reference device and kept out of the active set — lockscreen widgets are unused. keepDisabled accepts uninstalled-for-user as a valid off-state; if an OTA re-enables it, 01-debloat.sh disables it again. |
| `com.android.chrome` | Google Chrome. Kept disabled (data preserved) rather than uninstalled-for-user, by owner preference. Moved OUT of debloat-list.json so re-runs of 01-debloat.sh disable-and-keep instead of uninstalling. |
| `com.heytap.htms` | HeyTap Mobile Services — HeyTap account/push/telemetry surface that phones home; disabled (data preserved). |
| `com.oplus.aiunit` | On-device AI inference unit (OPPO AI features); disabled — unused, and part of the AI-surface reduction. |
| `com.oplus.cosa` | COSA (connectivity / game-network optimization service); disabled — unused. |
| `com.oplus.pay` | OPPO Pay wallet service; disabled — unused, phones home. |
| `com.oplus.themestore` | Theme Store — storefront that phones home; disabled (data preserved). |

> **Note:** `com.oplus.keyguard.style.widgets` is currently **uninstalled-for-user** on the reference device (a stronger off-state than disabled); `keepDisabled` accepts disabled *or* uninstalled-for-user as a valid "not active" state.

---

## Uninstalled-for-user — `pm uninstall --user 0`

The Canta export in `config/debloat-list.json`. The APK stays on the system partition, so any package comes back with `adb shell cmd package install-existing <pkg>`; the target's app data is wiped. Grouped by vendor:

### Google / GMS (42)
`com.android.hotwordenrollment.okgoogle` · `com.android.hotwordenrollment.xgoogle` · `com.google.ambient.streaming` · `com.google.android.accessibility.switchaccess` · `com.google.android.adservices.api` · `com.google.android.aicore` · `com.google.android.apps.bard` · `com.google.android.apps.messaging` · `com.google.android.apps.nbu.files` · `com.google.android.apps.photos` · `com.google.android.apps.restore` · `com.google.android.apps.safetyhub` · `com.google.android.apps.tachyon` · `com.google.android.apps.wellbeing` · `com.google.android.apps.work.clouddpc` · `com.google.android.as` · `com.google.android.as.oss` · `com.google.android.contacts` · `com.google.android.federatedcompute` · `com.google.android.feedback` · `com.google.android.gm` · `com.google.android.gms.location.history` · `com.google.android.gms.supervision` · `com.google.android.googlequicksearchbox` · `com.google.android.healthconnect.controller` · `com.google.android.inputmethod.latin` · `com.google.android.marvin.talkback` · `com.google.android.odad` · `com.google.android.ondevicepersonalization.services` · `com.google.android.onetimeinitializer` · `com.google.android.overlay.modules.healthfitness.forframework` · `com.google.android.partnersetup` · `com.google.android.printservice.recommendation` · `com.google.android.projection.gearhead` · `com.google.android.setupwizard` · `com.google.android.syncadapters.calendar` · `com.google.android.tts` · `com.google.android.youtube` · `com.google.ar.core` · `com.google.ar.lens` · `com.google.mainline.adservices` · `com.google.mainline.telemetry`

### Oplus (58)
`com.oplus.accesscard` · `com.oplus.account` · `com.oplus.aiassistant` · `com.oplus.aicall` · `com.oplus.aimemory` · `com.oplus.aiwriter` · `com.oplus.ambient.livealert` · `com.oplus.android.overlay.aifunction.cicletosearch` · `com.oplus.android.overlay.aifunction.common` · `com.oplus.android.overlay.gmsconfig.common` · `com.oplus.aod` · `com.oplus.apprecover` · `com.oplus.atlas` · `com.oplus.blacklistapp` · `com.oplus.bttestmode` · `com.oplus.calendar` · `com.oplus.callrecorder` · `com.oplus.contentportal` · `com.oplus.customize.coreapp` · `com.oplus.dfs` · `com.oplus.dmp` · `com.oplus.eid` · `com.oplus.encryption` · `com.oplus.engineercamera` · `com.oplus.engineermode` · `com.oplus.engineernetwork` · `com.oplus.eyeprotect` · `com.oplus.games` · `com.oplus.healthservice` · `com.oplus.lfeh` · `com.oplus.linker` · `com.oplus.location` · `com.oplus.locationproxy` · `com.oplus.logkit` · `com.oplus.mediaturbo` · `com.oplus.melody` · `com.oplus.metis` · `com.oplus.multiapp` · `com.oplus.nas` · `com.oplus.ndsf` · `com.oplus.obrain` · `com.oplus.omoji` · `com.oplus.onetrace` · `com.oplus.overlay.aicore` · `com.oplus.postmanservice` · `com.oplus.powermonitor` · `com.oplus.qualityprotect` · `com.oplus.remotecontrol` · `com.oplus.sandbox.runtime` · `com.oplus.sauhelper` · `com.oplus.securityguard` · `com.oplus.securitykeyboard` · `com.oplus.smartengine` · `com.oplus.statistics.rom` · `com.oplus.stdsp` · `com.oplus.upgradeguide` · `com.oplus.vip` · `com.oplus.wifibackuprestore`

### ColorOS (23)
`com.coloros.accessibilityassistant` · `com.coloros.activation` · `com.coloros.calculator` · `com.coloros.childrenspace` · `com.coloros.colordirectservice` · `com.coloros.compass2` · `com.coloros.filemanager` · `com.coloros.floatassistant` · `com.coloros.gallery3d` · `com.coloros.karaoke` · `com.coloros.ocrscanner` · `com.coloros.ocs.opencapabilityservice` · `com.coloros.operationManual` · `com.coloros.oshare` · `com.coloros.phonemanager` · `com.coloros.scenemode` · `com.coloros.securepay` · `com.coloros.smartsidebar` · `com.coloros.soundrecorder` · `com.coloros.systemclone` · `com.coloros.video` · `com.coloros.weather.service` · `com.coloros.weather2`

### HeyTap / OPPO (8)
`com.heytap.accessory` · `com.heytap.browser` · `com.heytap.cloud` · `com.heytap.mcs` · `com.heytap.music` · `com.heytap.mydevices` · `com.heytap.pictorial` · `com.oppo.quicksearchbox`

### Facebook (3)
`com.facebook.appmanager` · `com.facebook.services` · `com.facebook.system`

### Microsoft (3)
`com.microsoft.appmanager` · `com.microsoft.deviceintegrationservice` · `com.microsoftsdk.crossdeviceservicebroker`

### Qualcomm (12)
`com.qti.dcf` · `com.qti.qcc` · `com.qualcomm.atfwd` · `com.qualcomm.location` · `com.qualcomm.qti.devicestatisticsservice` · `com.qualcomm.qti.powersavemode` · `com.qualcomm.qti.qms.service.trustzoneaccess` · `com.qualcomm.qti.uimGbaApp` · `com.qualcomm.qti.xrcb` · `com.qualcomm.qti.xrvd.service` · `com.qualcomm.uimremoteclient` · `com.qualcomm.uimremoteserver`

### AOSP / system (21)
`com.android.DeviceAsWebcam` · `com.android.apps.tag` · `com.android.bookmarkprovider` · `com.android.calllogbackup` · `com.android.cts.ctsshim` · `com.android.devicediagnostics` · `com.android.dreams.basic` · `com.android.egg` · `com.android.email.partnerprovider` · `com.android.microdroid.empty_payload` · `com.android.providers.partnerbookmarks` · `com.android.role.notes.enabled` · `com.android.systemui.accessibility.accessibilitymenu` · `com.android.systemui.overlay.fingerprint.anim.ccyh` · `com.android.systemui.overlay.fingerprint.anim.jslz` · `com.android.systemui.overlay.fingerprint.anim.xklc` · `com.android.theme.font.notoserifsource` · `com.android.traceur` · `com.android.vending` · `com.android.virtualization.terminal` · `com.android.wallpaperbackup`

### Other (5)
`android.autoinstalls.config.oppo` · `com.aiunit.aon` · `com.daemon.shelper` · `com.ted.number` · `com.wapi.wapicertmanage`
