# spraysong

A visionOS 26.0 SwiftUI + RealityKit proof-of-concept for spatial spray painting in a volumetric window.

The app presents a neutral wall in front of the user and four spray cans to the right. Pinch or tap a can to select yellow, green, blue, or purple. Pinch, tap, or click-drag the wall to paint into a single dynamic wall texture.

## Requirements

- Xcode 26.0 or newer with the visionOS 26.0 SDK
- Apple Vision Pro running visionOS 26.0, or the visionOS simulator
- A valid Apple developer team selected for signing

## Simulator Testing

- Click a spray can to select it.
- Click the wall to paint a single spray stamp.
- Click-drag across the wall to paint one continuous stroke made from multiple spray stamps.
- Click Undo to remove the most recent stroke.
- The same targeted SwiftUI/RealityKit gestures support look-and-pinch on Apple Vision Pro.

## Run On Apple Vision Pro

1. Open `spraysong.xcodeproj` in Xcode.
2. Select the `spraysong` scheme.
3. Select your paired Apple Vision Pro as the run destination.
4. Confirm the signing team for the `spraysong` target.
5. Build and run.

The app uses a volumetric `WindowGroup`, not an `ImmersiveSpace`. It should appear as a bounded spatial volume in front of the user; stepping back should make the volume boundaries perceptible.

## Audio Stems

Place the four isolated song stems in `spraysong/tracks` so they are copied into the app bundle:

- `hello-bass.wav`
- `hello-drums.wav`
- `hello-piano.wav`
- `hello-vocals.wav`

Color mapping:

- Yellow = bass
- Green = drums
- Blue = piano
- Purple = vocals

The app uses `AVAudioPlayer` instances as synchronized stems. When the first committed paint color appears, all loaded stems start together on the same playback clock, with inactive stems muted. Adding another color unmutes its stem at the current shared timestamp rather than starting it from the beginning. Undo recomputes the colors still present in the committed stroke list and mutes stems whose colors are no longer present. When the canvas is empty, all stems pause and reset to the beginning.

## Texture-Backed Painting

The wall uses one dynamic bitmap canvas texture generated at runtime. Each drag gesture creates one `PaintStroke` containing normalized UV samples, opacity, radius, and a random seed for every spray stamp. While the gesture moves, the app draws deterministic noisy circular dot patterns into the in-memory bitmap and replaces the wall texture.

Paint does not create persistent RealityKit particle or disc entities. The scene stays lightweight: wall entity, spray cans, lighting, and SwiftUI controls.

Undo works at stroke level:

1. Remove the newest committed stroke from memory.
2. Clear the bitmap canvas.
3. Replay all remaining strokes from their stored UV samples and seeds.
4. Replace the wall texture and recompute active audio colors.

## Current Limitations

- Spray cans do not physically attach to or follow the user's hand yet.
- Spray marks are bitmap dot stamps, not a real particle simulation.
- Undo currently replays all remaining strokes instead of using pixel diffs or snapshots.
- Paint strokes are stored only in memory and disappear when the app closes.
- There is no timeline scrubber, redo, clear wall, persistence, or export UI yet.
- The wall and can layout are fixed for a first-pass hardware prototype.

## Future TODOs

- Optimize undo with pixel diffs or periodic bitmap snapshots instead of replaying all strokes.
- Add more realistic spray texture, pressure, distance, and nozzle behavior.
- Fade tracks in and out instead of hard mute/unmute changes.
- Add better hand attachment for the selected can using RealityKit-level tracked input, or hand anchors if the interaction model requires it.
- Add persistence and export for paint strokes.
- Add redo and clear-wall controls.
- Add richer can affordances, hover feedback, and audio/haptic feedback.
