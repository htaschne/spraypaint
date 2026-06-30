//
//  PaintModels.swift
//  spraysong
//
//  Created by Codex on 30/06/26.
//

import Combine
import Foundation
import UIKit

enum PaintColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case purple

    var id: Self { self }

    var displayName: String {
        switch self {
        case .yellow:
            "Yellow"
        case .green:
            "Green"
        case .blue:
            "Blue"
        case .purple:
            "Purple"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .yellow:
            UIColor(red: 1.0, green: 0.84, blue: 0.12, alpha: 1.0)
        case .green:
            UIColor(red: 0.10, green: 0.74, blue: 0.32, alpha: 1.0)
        case .blue:
            UIColor(red: 0.10, green: 0.38, blue: 1.0, alpha: 1.0)
        case .purple:
            UIColor(red: 0.64, green: 0.22, blue: 0.95, alpha: 1.0)
        }
    }

    var entityName: String {
        "spray-can-\(rawValue)"
    }

    var stem: AudioTrackManager.Stem {
        switch self {
        case .yellow:
            .bass
        case .green:
            .drums
        case .blue:
            .piano
        case .purple:
            .vocals
        }
    }
}

struct PaintStroke: Identifiable {
    let id: UUID
    let color: PaintColor
    var samples: [PaintSample]

    init(
        id: UUID = UUID(),
        color: PaintColor,
        samples: [PaintSample] = []
    ) {
        self.id = id
        self.color = color
        self.samples = samples
    }
}

struct PaintSample {
    let uv: SIMD2<Float>
    let radius: Float
    let opacity: Float
    let seed: UInt64
}

@MainActor
final class PaintStrokeManager: ObservableObject {
    // Ordered, committed gesture-level stroke history. Undo removes only the last stroke.
    @Published private(set) var strokes: [PaintStroke] = []
    @Published var activeColor: PaintColor = .yellow

    private(set) var currentStroke: PaintStroke?
    private var lastSampleUV: SIMD2<Float>?
    private var lastSampleTime: TimeInterval = 0

    var canUndo: Bool {
        !strokes.isEmpty
    }

    var activeColorsOnCanvas: Set<PaintColor> {
        Set(strokes.map(\.color))
    }

    func selectColor(_ color: PaintColor) {
        activeColor = color
    }

    func beginStroke() {
        guard currentStroke == nil else {
            return
        }

        currentStroke = PaintStroke(color: activeColor)
        lastSampleUV = nil
        lastSampleTime = 0
    }

    // Adds a sampled stamp to the current in-progress stroke. UV values are normalized wall coordinates.
    @discardableResult
    func addSample(
        at uv: SIMD2<Float>,
        radius: Float? = nil,
        opacity: Float = 0.82,
        force: Bool = false
    ) -> PaintSample? {
        guard currentStroke != nil else {
            return nil
        }

        let clampedUV = SIMD2<Float>(
            min(max(uv.x, 0), 1),
            min(max(uv.y, 0), 1)
        )

        let now = Date.timeIntervalSinceReferenceDate
        if !force,
           let lastSampleUV,
           distance(from: lastSampleUV, to: clampedUV) < SprayPaintConstants.sampleMinUVSpacing {
            return nil
        }

        if !force,
           lastSampleTime > 0,
           now - lastSampleTime < SprayPaintConstants.sampleMinInterval {
            return nil
        }

        let sampleRadius = radius ?? SprayPaintConstants.stampRadiusUV
        let sample = PaintSample(
            uv: clampedUV,
            radius: sampleRadius,
            opacity: opacity,
            seed: UInt64.random(in: UInt64.min...UInt64.max)
        )
        currentStroke?.samples.append(sample)
        lastSampleUV = clampedUV
        lastSampleTime = now

        return sample
    }

    // Commits one pinch/click-drag as one undoable PaintStroke. Empty gestures are discarded.
    @discardableResult
    func commitCurrentStroke() -> PaintStroke? {
        guard let stroke = currentStroke, !stroke.samples.isEmpty else {
            cancelCurrentStroke()
            return nil
        }

        strokes.append(stroke)
        cancelCurrentStroke()
        return stroke
    }

    func cancelCurrentStroke() {
        currentStroke = nil
        lastSampleUV = nil
        lastSampleTime = 0
    }

    // Undo is model-first. The texture renderer clears and replays the remaining strokes after this returns.
    func removeLastStroke() -> PaintStroke? {
        guard canUndo else {
            return nil
        }

        cancelCurrentStroke()
        return strokes.removeLast()
    }

    private func distance(from lhs: SIMD2<Float>, to rhs: SIMD2<Float>) -> Float {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return sqrt((dx * dx) + (dy * dy))
    }
}

enum SprayPaintConstants {
    static let wallName = "paint-wall"
    static let wallWidth: Float = 1.15
    static let wallHeight: Float = 0.72
    static let wallDepth: Float = 0.035
    static let wallZ: Float = -0.32
    static let stampRadiusUV: Float = 0.065
    static let sampleMinUVSpacing: Float = 0.018
    static let sampleMinInterval: TimeInterval = 0.035
}
