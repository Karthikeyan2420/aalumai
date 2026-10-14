# Privacy & permissions

## Privacy model

AALUMAI is **offline-first and account-free**.

- All data lives in a single local SQLite database (`aalumai.sqlite`) in the
  app's documents directory on your device.
- There is **no server, no sign-in, no cloud sync, and no analytics/telemetry.**
- The app does not transmit your data anywhere. Networking is only used by the
  platform plugins you explicitly invoke (e.g. none for core features).
- Data leaves the device only when **you** choose to:
  - **Backup** — a snapshot is written to your device's documents directory.
  - **CSV export** — a transactions file is written to your documents directory.
  - **Restore** — you pick a backup file to load.
- **Note lock** stores only a salted **hash** of your PIN in the platform secure
  store (`flutter_secure_storage` / Android Keystore-backed storage). The PIN
  itself is never stored in the database.

> To fully erase all data, clear the app's storage from Android settings
> (uninstalling the app also removes its database and preferences).

## Android permissions

Declared in `android/app/src/main/AndroidManifest.xml`:

| Permission | Why it is requested |
| --- | --- |
| `POST_NOTIFICATIONS` | Show task/habit/event reminders and alarms (Android 13+). |
| `SCHEDULE_EXACT_ALARM` | Fire alarms at the exact minute. |
| `USE_EXACT_ALARM` | Exact alarms for alarm-clock-style use. |
| `RECEIVE_BOOT_COMPLETED` | Re-arm scheduled alarms after a reboot. |
| `WAKE_LOCK` | Wake the device when an alarm fires. |
| `VIBRATE` | Vibrate alarms/reminders when enabled. |
| `READ_MEDIA_AUDIO` | Scan user-chosen folders for music files (Android 13+). |
| `READ_EXTERNAL_STORAGE` (≤ API 32) | Same, on older Android versions. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Keep music playing in the background with a media notification. |
| `RECORD_AUDIO` | Speech-to-text pronunciation practice in the learning module. |
| `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` | Optional location tagging on notes. |

### Runtime behaviour

- Permissions are requested **at the moment the related feature is used**, not
  on first launch (except notifications, which are requested when enabled in
  Settings or when already enabled).
- If a permission is denied, the feature degrades gracefully with an honest
  message; nothing crashes.
- Location is used only for the optional note-tagging feature and can be denied
  without affecting anything else.

## Manifest receivers

`flutter_local_notifications` requires two receivers so scheduled notifications
survive reboots and can be delivered:

- `ScheduledNotificationReceiver`
- `ScheduledNotificationBootReceiver` (listens for `BOOT_COMPLETED`,
  `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`)

`audio_service` additionally registers a foreground `AudioService` (media
browser service) and a `MediaButtonReceiver` so lock-screen / headset controls
reach the music player.

## Platform notes

- The core app (habits, tasks, calendar, notes, money, savings, debts, fitness,
  meals, learning content, settings) works with **no permissions at all**.
- Music, alarms, notifications, speech and location are the only features that
  touch permissions, and each is optional.
