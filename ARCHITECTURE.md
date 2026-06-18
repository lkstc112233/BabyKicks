# Baby Kicks — Architecture and Implementation Handoff

Last updated: June 18, 2026

## Product summary

Baby Kicks is a privacy-first iPhone application for recording fetal movement with one tap. It opens directly to a large central “Felt a move” control, stores every movement as a raw timestamp, offers lightweight derived insights, and can run a two-hour counting session in a Live Activity and the Dynamic Island.

The prototype deliberately keeps its source data minimal. Analysis is derived from raw events so future product decisions do not require changing or prematurely interpreting the underlying record.

This application is a personal tracking aid, not a medical device. Medical claims, thresholds, warnings, or clinical recommendations should not be introduced without appropriate clinical and regulatory review.

## Implemented behavior

### Track tab

- Opens as the primary tab.
- Presents a large, one-handed “Felt a move” button.
- Each successful tap inserts one row with the current timestamp.
- Uses haptic feedback to confirm a successful insert.
- Displays the number of movements recorded during the current calendar day.
- Includes a toggle that starts or stops a two-hour counting session.
- Displays the remaining session time while the session is active.

### Insights tab

- Displays today’s movement count and the all-time count.
- Charts daily movement totals for the most recent seven days.
- Shows inferred recent sessions.
- Inferred sessions are groups of raw events separated by less than two hours; a gap of two hours or more begins a new inferred session.
- The analysis layer is intentionally derived and replaceable. No analysis fields are persisted.

### Settings tab

- Exports CSV files compatible with Excel, Numbers, and Google Sheets.
- Supports these export ranges:
  - all time;
  - last 7 days;
  - last 30 days;
  - a custom inclusive calendar-date range.
- Custom export displays the number of matching movements before export.
- CSV rows are ordered chronologically and contain `id,timestamp`, with timestamps encoded using ISO 8601.
- “Delete all data” stops and dismisses the current Live Activity before deleting every event.
- Communicates that storage is local and cloud synchronization is disabled.

### Live Activity and Dynamic Island

- Starting a session creates a two-hour ActivityKit Live Activity.
- The Lock Screen presentation shows:
  - the countdown;
  - the number of movements in the active session.
- The compact Dynamic Island shows the movement icon and countdown.
- The expanded Dynamic Island shows:
  - session movement count;
  - countdown;
  - an interactive “Record movement” button.
- The Dynamic Island button uses `LiveActivityIntent` with `openAppWhenRun = false`, so it records without foregrounding the application.
- The intent is compiled into both the containing application and widget extension. This is required for iOS to discover and execute an interactive Live Activity intent correctly.
- Both the main-screen button and Dynamic Island button update the Live Activity count.
- The displayed count is session-only. It is recalculated from SQLite using the Live Activity’s `startedAt` time rather than trusting potentially stale in-memory state.
- When the app returns to the foreground, it reloads SQLite and reconciles the active session count with the Live Activity.
- Existing Live Activities retain the code/configuration from the installed build that created them. After changing Live Activity behavior, stop the old session and start a new one during testing.

## High-level architecture

```text
SwiftUI application
├── TrackView
│   ├── KickStore ────────────┐
│   └── SessionManager        │
├── InsightsView              ├── App Group SQLite database
└── SettingsView              │   baby-kicks.sqlite
    └── CSVDocument           │
                               │
Widget extension               │
├── BabyKicksLiveActivity      │
└── RecordKickIntent ──────────┘

ActivityKit content shared by both targets:
└── KickActivityAttributes
```

## Source layout

```text
BabyKicks/
├── BabyKicks/
│   ├── BabyKicksApp.swift
│   ├── Models/
│   │   └── KickEvent.swift
│   ├── Storage/
│   │   ├── KickDatabase.swift
│   │   └── KickStore.swift
│   ├── Session/
│   │   └── SessionManager.swift
│   ├── Export/
│   │   └── CSVDocument.swift
│   └── Views/
│       ├── AppTabView.swift
│       ├── TrackView.swift
│       ├── InsightsView.swift
│       └── SettingsView.swift
├── BabyKicksShared/
│   ├── KickActivityAttributes.swift
│   └── RecordKickIntent.swift
└── BabyKicksWidget/
    ├── BabyKicksWidgetBundle.swift
    └── BabyKicksLiveActivity.swift
```

`BabyKicksShared` has target membership in both the app and widget extension. In particular, `RecordKickIntent` must remain shared; moving it back into only the extension causes Dynamic Island taps not to execute the database mutation.

## Persistence

### Schema

The app uses Apple’s system SQLite library directly and creates exactly one application table:

```sql
CREATE TABLE IF NOT EXISTS kick_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp REAL NOT NULL
);
```

- `id` is an auto-incrementing SQLite integer.
- `timestamp` is a Unix timestamp stored as `REAL`.
- Raw events are the sole persisted source of truth.
- Session summaries and charts are calculated at read time.

### Storage location

The active database is stored in the local App Group container:

```text
group.com.photoncat.BabyKicks/baby-kicks.sqlite
```

The app and widget extension require access to the same file because a Live Activity intent may execute outside the application process. App Groups provide local process-to-process storage sharing; they do not enable iCloud or multi-device synchronization.

Both targets include the `group.com.photoncat.BabyKicks` application-group entitlement.

### Migration

Earlier prototype builds stored the database under the app’s Application Support directory. On first access after upgrading, `KickDatabase` copies that legacy database into the App Group container if:

- the App Group database does not already exist; and
- the legacy database exists.

The legacy file is left intact as a conservative fallback. The App Group copy becomes authoritative after migration.

### Concurrency

- The app-side `KickDatabase` opens SQLite with `SQLITE_OPEN_FULLMUTEX` and serializes calls with `NSLock`.
- The Live Activity intent independently opens the same App Group database with `SQLITE_OPEN_FULLMUTEX`.
- Each write is a single SQLite insert.
- Session counts use a bounded `COUNT(*)` query from the Live Activity start time through the current time.

## Application state

### `KickStore`

`KickStore` is the main-actor observable facade used by SwiftUI. It:

- loads all events in reverse chronological order;
- records a movement;
- publishes today and all-time values;
- deletes all events;
- derives inferred sessions;
- reloads when the application becomes active, picking up writes made by the Live Activity intent.

`recordKick()` reports whether persistence succeeded. The main UI updates the Live Activity only after a successful database insert.

### `SessionManager`

`SessionManager` owns ActivityKit lifecycle and the local representation of the active session. It:

- creates a two-hour Live Activity;
- stores the expected end date in `UserDefaults`;
- updates the ActivityKit content after app-originated movements;
- recalculates the session count from SQLite;
- reconciles state when the app becomes active;
- ends all matching Live Activities when stopped or when all data is deleted.

The Live Activity attributes contain immutable `startedAt` and `endsAt` values. Its mutable content state contains the current session movement count and the most recent movement time.

## Live Activity interaction flow

### Movement recorded in the app

1. `TrackView` asks `KickStore` to insert the event.
2. If insertion succeeds, `SessionManager.registerKick()` runs.
3. The manager counts database events between the activity’s `startedAt` and now.
4. ActivityKit receives the new content state.
5. Lock Screen and Dynamic Island presentations refresh.

### Movement recorded in Dynamic Island

1. The expanded Dynamic Island invokes `RecordKickIntent`.
2. iOS runs the intent without opening the application.
3. The intent inserts a timestamp into the App Group SQLite database.
4. It counts events between each active Live Activity’s `startedAt` and now.
5. It updates the ActivityKit content state with that exact session count.
6. The main app reloads the database the next time it becomes active.

## Export semantics

CSV export filters the already loaded raw events:

- “All time” includes every row.
- Preset ranges use a rolling timestamp cutoff of 7 or 30 days before export.
- Custom ranges operate on local calendar days. The selected ending date is inclusive by filtering up to, but not including, the start of the following day.
- An empty range still produces a valid CSV containing the header.

## iCloud clarification

The live SQLite database should not be placed directly in iCloud Drive. File-level synchronization can conflict with SQLite journal or WAL files and does not provide record-level conflict resolution.

If multi-device synchronization is added later:

- keep SQLite local;
- give events stable UUIDs;
- synchronize records through CloudKit;
- define conflict and deletion semantics;
- preserve an offline-first local source of truth.

No CloudKit container or iCloud database entitlement is currently used.

## Build configuration and device setup

- App bundle identifier: `com.photoncat.BabyKicks`
- Widget bundle identifier: `com.photoncat.BabyKicks.widget`
- App Group: `group.com.photoncat.BabyKicks`
- Live Activities are enabled with `NSSupportsLiveActivities`.
- The widget extension is embedded in the containing application.
- Automatic signing is configured for the existing development team.

Before installing on a physical device, the App Group must exist in the Apple Developer account and be enabled for both App IDs/provisioning profiles. Dynamic Island behavior must be tested on a supported iPhone. Lock Screen Live Activities can be tested on other supported devices.

## Verification completed

The project has been repeatedly validated with a clean, unsigned generic-device build:

```sh
xcodebuild \
  -project BabyKicks/BabyKicks.xcodeproj \
  -scheme BabyKicks \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/BabyKicksDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

The final build completed successfully for both the app and widget extension. Xcode also generated `Metadata.appintents` for the containing application after `RecordKickIntent` was moved into shared target membership.

Physical-device QA is still required for:

- App Group provisioning;
- recording from the expanded Dynamic Island while the app is closed;
- rapid repeated intent taps;
- activity expiration at two hours;
- upgrade migration with an existing legacy database;
- accessibility and larger text sizes.

## Known constraints and next work

1. Add automated SQLite insert, migration, deletion, and date-range tests.
2. Add integration coverage for app-originated and intent-originated writes.
3. Add tests around session boundaries and daylight-saving/calendar transitions.
4. Consider an explicit session table only if manual naming, historical session metadata, or non-inferred sessions become product requirements.
5. Add medically reviewed onboarding language and support guidance.
6. Add a polished app icon and localization before release.
