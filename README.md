# NotesDemo

**NotesDemo** is a SwiftUI-based iOS app that lets you take text notes and record audio memos right inside the app. Your recordings (in MP3 format) are automatically saved and can be played back from the Settings screen.

---

## Features

* **Text notes** organized into folders (Notes, Work, Personal)
* **Full‑screen audio recorder** overlay with a big pulsing red record/stop button
* **Automatic conversion** from M4A to MP3 using SwiftLAME
* **Playback UI** in Settings: play or stop any saved recording
* **Dark mode** support & simple Alerts toggle
* **"Back Door"** view for debugging: list of synced lines from `HiddenLineStore`

---

## Requirements

* Xcode 15+
* iOS 17+ SDK
* Swift 5.9

---

## Dependencies

* [SwiftLAME](https://github.com/hidden-spectrum/swiftlame) (added via Swift Package Manager)
* SwiftUI & AVFoundation (built‑in)

---

## Installation

1. Clone this repo:

   ```bash
   git clone https://github.com/your-username/NotesDemo.git
   cd NotesDemo
   ```
2. Open `NotesDemo.xcodeproj` in Xcode.
3. In Xcode, go to **File ➔ Add Packages…**, search for `https://github.com/hidden-spectrum/swiftlame`, and add **SwiftLAME** to the NotesDemo target.
4. Build & run on a simulator or device.

---

## Usage

1. **Text Notes**

   * Tap the **folder** icon in the top bar to switch folders.
   * Tap **+** to add a new note title.
   * Select a note to open its detail view and edit lines.

2. **Audio Recording**

   * Tap the **mic** button in the bottom toolbar.
   * A full-screen overlay will appear and start recording immediately.
   * Tap the red button again to stop; the recording is converted to MP3 and saved.

3. **Playback**

   * Go to **Settings** (tap the person icon).
   * Under **Recordings**, open the list of saved memos.
   * Tap the ▶️ or ■ button to play or stop each recording.

4. **Debug Back Door**

   * In Settings, tap **View All Synced Lines** to see `HiddenLineStore`’s contents.

---

## File Structure

```
NotesDemoApp.swift         // App entry: injects NoteStore, HiddenLineStore, RecordingStore
ContentView.swift          // Main UI: folders, notes list, bottom toolbar (Record/Search/Add)
RecordingStore.swift       // Model & store for Recording items
RecordingView.swift        // Full-screen record/convert overlay
SettingsView.swift         // Settings form + Recordings list + Back Door
HiddenLineStore.swift      // (existing) synced lines store & view
NoteStore.swift            // (existing) text notes data store
CircleButton.swift         // (existing) reusable circular button view
…                          // other helper files
```

---

## Contributing

Pull requests welcome! Feel free to open issues for bugs or feature requests.

---

## License

[MIT](LICENSE)
