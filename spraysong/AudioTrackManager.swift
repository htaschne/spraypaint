//
//  AudioTrackManager.swift
//  spraysong
//
//  Created by Codex on 30/06/26.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioTrackManager: ObservableObject {
    enum Stem: String, CaseIterable {
        case bass
        case drums
        case piano
        case vocals

        var fileBaseName: String {
            switch self {
            case .bass:
                "hello-bass"
            case .drums:
                "hello-drums"
            case .piano:
                "hello-piano"
            case .vocals:
                "hello-vocals"
            }
        }
    }

    private var players: [Stem: AVAudioPlayer] = [:]
    private var activeStems: Set<Stem> = []
    private var isPlaybackActive = false

    func loadTracks() {
        guard players.isEmpty else {
            return
        }

        for stem in Stem.allCases {
            guard let url = trackURL(for: stem) else {
                print("[AudioTrackManager] Missing track for \(stem.rawValue): \(stem.fileBaseName)")
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = 0
                player.volume = 0
                player.prepareToPlay()
                players[stem] = player
                print("[AudioTrackManager] Loaded \(stem.rawValue) from \(url.lastPathComponent)")
            } catch {
                print("[AudioTrackManager] Failed to load \(stem.rawValue): \(error)")
            }
        }
    }

    func updateActiveColors(_ colors: Set<PaintColor>) {
        loadTracks()

        let nextActiveStems = Set(colors.map(\.stem))
        let colorNames = colors.map(\.rawValue).sorted().joined(separator: ", ")
        print("[AudioTrackManager] Active colors changed: [\(colorNames)]")

        guard !nextActiveStems.isEmpty else {
            activeStems = []
            muteAllStems()
            pauseAll(resetToBeginning: true)
            print("[AudioTrackManager] Canvas empty; paused all tracks")
            return
        }

        activeStems = nextActiveStems
        updateStemVolumes()
        playIfNeeded()
    }

    func playIfNeeded() {
        guard !isPlaybackActive else {
            return
        }

        let loadedPlayers = Array(players.values)
        guard let firstPlayer = loadedPlayers.first else {
            print("[AudioTrackManager] No loaded tracks available for playback")
            return
        }

        let startTime = firstPlayer.deviceCurrentTime + 0.12
        for player in loadedPlayers {
            player.play(atTime: startTime)
        }

        isPlaybackActive = true
        print("[AudioTrackManager] Playback started at shared device time \(startTime)")
    }

    func pauseAll(resetToBeginning: Bool = false) {
        for player in players.values {
            player.pause()
            if resetToBeginning {
                player.currentTime = 0
            }
        }
        isPlaybackActive = false
    }

    func stopAll() {
        for player in players.values {
            player.stop()
            player.currentTime = 0
            player.volume = 0
        }
        activeStems = []
        isPlaybackActive = false
        print("[AudioTrackManager] Stopped all tracks")
    }

    private func updateStemVolumes() {
        for stem in Stem.allCases {
            let volume: Float = activeStems.contains(stem) ? 1 : 0
            players[stem]?.volume = volume
            print("[AudioTrackManager] \(stem.rawValue) \(volume > 0 ? "unmuted" : "muted")")
        }
    }

    private func muteAllStems() {
        for stem in Stem.allCases {
            players[stem]?.volume = 0
            print("[AudioTrackManager] \(stem.rawValue) muted")
        }
    }

    private func trackURL(for stem: Stem) -> URL? {
        findTrackURL(for: stem, subdirectory: "tracks") ?? findTrackURL(for: stem, subdirectory: nil)
    }

    private func findTrackURL(for stem: Stem, subdirectory: String?) -> URL? {
        Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: subdirectory)?
            .first { $0.deletingPathExtension().lastPathComponent == stem.fileBaseName }
    }
}
