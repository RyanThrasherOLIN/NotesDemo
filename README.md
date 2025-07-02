````markdown
# NotesDemo

**NotesDemo** is a SwiftUI-based iOS app that lets you take text notes (organized into folders) and record audio memos right inside the app. Recordings are automatically converted to MP3 and can be played back from the Settings screen.

---

## Features

- **Text notes** organized into folders: *Notes*, *Work*, *Personal*  
- **Line-by-line sync** to your backend via `HiddenLineStore`  
- **Full-screen audio recorder** overlay with pulsing record/stop button  
- **M4A → MP3 conversion** using SwiftLAME  
- **Playback UI** in Settings; play or stop saved memos  
- **Dark mode** & **Alerts** toggles  
- **“Back Door”** debug view of all synced lines  

---

## Requirements

- Xcode 15+  
- iOS 17+ SDK  
- Swift 5.9  

---

## Dependencies

- [SwiftLAME](https://github.com/hidden-spectrum/swiftlame) (via SwiftPM)  
- SwiftUI & AVFoundation (built-in)  

---

## Installation

1. **Clone the repo**  
   ```bash
   git clone https://github.com/your-username/NotesDemo.git
   cd NotesDemo
````

2. **Open in Xcode**

   ```bash
   open NotesDemo.xcodeproj
   ```

3. **Add SwiftLAME**
   In Xcode → **File → Add Packages…**, enter
   `https://github.com/hidden-spectrum/swiftlame` → Add to **NotesDemo** target.

4. **Build & Run**
   Select a simulator or device and hit ▶️.

---

## Usage

1. **Text Notes**

   * Tap the **folder** icon in the top bar to switch folders.
   * Tap **+** to add a new note title.
   * Select a note to open its detail view and edit lines.

2. **Audio Recording**

   * Tap the **mic** button in the bottom toolbar.
   * A full-screen overlay appears and starts recording immediately.
   * Tap the red button again to stop; the recording is converted to MP3 and saved.

3. **Playback**

   * Go to **Settings** (tap the person icon).
   * Under **Recordings**, open the list of saved memos.
   * Tap the ▶️ or ■ button to play or stop each recording.

4. **Debug Back Door**

   * In Settings, tap **View All Synced Lines** to see all lines synced by `HiddenLineStore`.

---

## File Layout

```
NotesDemo
├── App
│   └── NotesDemoApp.swift
│
├── Models
│   └── Recording.swift
│
├── Stores
│   ├── NoteStore.swift
│   ├── RecordingStore.swift
│   └── HiddenLineStore.swift
│
├── Views
│   ├── Core
│   │   ├── ContentView.swift
│   │   ├── NoteDetailView.swift
│   │   └── SettingsView.swift
│   │
│   ├── Overlays
│   │   ├── AddNoteOverlay.swift
│   │   ├── FolderOverlay.swift
│   │   ├── SearchOverlay.swift
│   │   ├── RecordingView.swift
│   │   └── SyncedLinesView.swift
│   │
│   └── Components
│       └── CircleButton.swift
│
├── Navigation
│   └── NavigationStackHandler.swift
│
└── Resources
    ├── Assets.xcassets
    └── LaunchScreen.storyboard
```

---

## Data Flow: Creating a Text Note

```text
┌────────────────────────┐
│   AddNoteOverlay.swift │   1. User enters a title and taps Save
└──────────────┬─────────┘
               │ calls onSubmit(title)
               ▼
┌────────────────────────┐
│     NoteStore.swift    │   2. addNote(title:, folder:)
│ • create Note(id, title, [])
│ • append to notesByFolder
│ • POST /add_note → server
└──────────────┬─────────┘
               │
               │  (local UI updates immediately)
               ▼
┌────────────────────────┐
│  ContentView.swift     │   3. List bound to notesByFolder shows new note
└──────────────┬─────────┘
               │
               │  (network)
               ▼
     POST /add_note → Your Backend
     • Payload: { device_id, note, folder, notebook }
     • Server persists note
```

1. **AddNoteOverlay.swift** presents a text field and Save/Cancel buttons.
2. **NoteStore.swift** immediately updates its `notesByFolder` and sends the new note to the server.
3. **ContentView\.swift** observes `notesByFolder` and renders the new note without delay.
4. The server receives and stores the note for that device ID, ready to be fetched on next launch.

---

## Retrieving Notes on Launch

In **NotesDemoApp.swift**:

```swift
.task { store.fetchUserNotes() }
```

* **NoteStore.fetchUserNotes()**

  * GETs `/get_user_notes?device_id=…`
  * Decodes server response into `[ServerNote]`
  * Maps to local `[Note]` and updates `notesByFolder` on the main thread

* **ContentView** then displays the fetched notes automatically.

---

## Line-by-Line Sync

Whenever you press Return in **NoteDetailView\.swift**:

```swift
hiddenStore.sync(lines, folder: folder, notebook: draftTitle)
```

* **HiddenLineStore** computes unseen lines and POSTs each to `/add_note`.
* Successfully synced lines are added to `syncedLines` so duplicates are skipped.

---

## Contributing

Pull requests and issues welcome!

---

## License

[MIT](LICENSE)

```
```
