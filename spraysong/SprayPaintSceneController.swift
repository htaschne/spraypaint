//
//  SprayPaintSceneController.swift
//  spraysong
//
//  Created by Codex on 30/06/26.
//

import Combine
import RealityKit
import SwiftUI

@MainActor
final class SprayPaintSceneController: ObservableObject {
    let store = PaintStrokeManager()
    private let audioTrackManager = AudioTrackManager()
    private let paintRenderer = PaintTextureRenderer()

    @Published private(set) var canUndo = false

    private let root = Entity()
    private var wallEntity: ModelEntity?
    private var canEntities: [PaintColor: Entity] = [:]
    private var suppressNextWallTap = false

    func buildScene(in content: inout RealityViewContent) {
        root.name = "spraysong-root"
        root.position = SIMD3<Float>(0, 0, 0)
        audioTrackManager.loadTracks()

        let wall = makeWall()
        wallEntity = wall
        root.addChild(wall)

        addSprayCans()

        let fillLight = DirectionalLight()
        fillLight.name = "soft-fill-light"
        fillLight.light.intensity = 900
        fillLight.orientation = simd_quatf(angle: -.pi / 5, axis: SIMD3<Float>(1, 0, 0))
        root.addChild(fillLight)

        content.add(root)
        updateCanHighlights()
    }

    func handleTap(on entity: Entity, location: SIMD3<Float>) {
        if let color = paintColor(for: entity) {
            store.selectColor(color)
            updateCanHighlights()
            return
        }

        if isWall(entity) {
            if suppressNextWallTap {
                suppressNextWallTap = false
                return
            }

            paintSingleStamp(at: location, relativeTo: entity)
        }
    }

    func handlePaintDrag(on entity: Entity, location: SIMD3<Float>) {
        guard isWall(entity) else {
            return
        }

        suppressNextWallTap = true

        if store.currentStroke == nil {
            store.beginStroke()
        }

        let uv = wallUV(from: location, relativeTo: entity)
        guard let sample = store.addSample(at: uv) else {
            return
        }

        paintRenderer.draw(sample: sample, color: store.currentStroke?.color ?? store.activeColor)
        updateWallTexture()
    }

    func endPaintDrag() {
        guard store.commitCurrentStroke() != nil else {
            return
        }

        canUndo = store.canUndo
        updateAudioForCurrentCanvas()
    }

    func undoLastStroke() {
        guard store.removeLastStroke() != nil else {
            canUndo = false
            return
        }

        // Undo is texture-backed: clear the bitmap and replay all remaining committed strokes.
        paintRenderer.replay(strokes: store.strokes)
        updateWallTexture()
        suppressNextWallTap = false
        canUndo = store.canUndo
        updateAudioForCurrentCanvas()

        // TODO: Add redo support by keeping undone strokes and replaying them on demand.
    }

    private func makeWall() -> ModelEntity {
        let wallMesh = MeshResource.generateBox(
            width: SprayPaintConstants.wallWidth,
            height: SprayPaintConstants.wallHeight,
            depth: SprayPaintConstants.wallDepth,
            cornerRadius: 0.006
        )
        let wall = ModelEntity(
            mesh: wallMesh,
            materials: [makeWallMaterial()]
        )
        wall.name = SprayPaintConstants.wallName
        wall.position = SIMD3<Float>(0, 0.03, SprayPaintConstants.wallZ)
        wall.components.set(InputTargetComponent())
        wall.components.set(CollisionComponent(shapes: [
            .generateBox(
                width: SprayPaintConstants.wallWidth,
                height: SprayPaintConstants.wallHeight,
                depth: SprayPaintConstants.wallDepth
            )
        ]))

        return wall
    }

    private func makeWallMaterial() -> any RealityKit.Material {
        do {
            let texture = try paintRenderer.updateTexture()
            return UnlitMaterial(texture: texture)
        } catch {
            print("[SprayPaintSceneController] Failed to create paint texture: \(error)")
            return SimpleMaterial(
                color: PaintTextureRenderer.wallBaseColor,
                roughness: 0.55,
                isMetallic: false
            )
        }
    }

    private func addSprayCans() {
        let startX: Float = 0.64
        let spacing: Float = 0.13

        for (index, color) in PaintColor.allCases.enumerated() {
            let can = SprayCanFactory.makeSprayCan(color: color, isSelected: color == store.activeColor)
            can.position = SIMD3<Float>(startX + (Float(index) * spacing), -0.18, -0.08)
            canEntities[color] = can
            root.addChild(can)
        }

        // TODO: Attach the active can to the user's hand using RealityKit-level tracked input
        // or a lightweight hand anchor once the intended production interaction is chosen.
        // This POC intentionally avoids ARKit HandTrackingProvider in the first version.
    }

    private func updateCanHighlights() {
        for color in PaintColor.allCases {
            guard let can = canEntities[color] else { continue }
            let isSelected = color == store.activeColor
            SprayCanFactory.refreshSprayCan(can, color: color, isSelected: isSelected)
            can.position.y = isSelected ? -0.145 : -0.18
        }
    }

    private func paintColor(for entity: Entity) -> PaintColor? {
        firstMatchingAncestor(from: entity) { candidate in
            PaintColor.allCases.first { candidate.name.hasPrefix($0.entityName) }
        }
    }

    private func isWall(_ entity: Entity) -> Bool {
        firstMatchingAncestor(from: entity) { candidate in
            candidate.name == SprayPaintConstants.wallName ? true : nil
        } ?? false
    }

    private func wallUV(from location: SIMD3<Float>, relativeTo entity: Entity) -> SIMD2<Float> {
        guard let wallEntity else {
            return SIMD2<Float>(0.5, 0.5)
        }

        let local = wallEntity.convert(position: location, from: entity)
        let halfWidth = SprayPaintConstants.wallWidth / 2
        let halfHeight = SprayPaintConstants.wallHeight / 2
        let x = min(max(local.x, -halfWidth), halfWidth)
        let y = min(max(local.y, -halfHeight), halfHeight)
        let u = (x + halfWidth) / SprayPaintConstants.wallWidth
        let v = 1 - ((y + halfHeight) / SprayPaintConstants.wallHeight)

        return SIMD2<Float>(u, v)
    }

    private func paintSingleStamp(at location: SIMD3<Float>, relativeTo entity: Entity) {
        store.beginStroke()
        let uv = wallUV(from: location, relativeTo: entity)
        guard let sample = store.addSample(at: uv, force: true) else {
            store.cancelCurrentStroke()
            return
        }

        paintRenderer.draw(sample: sample, color: store.currentStroke?.color ?? store.activeColor)
        updateWallTexture()
        store.commitCurrentStroke()
        canUndo = true
        updateAudioForCurrentCanvas()
    }

    private func updateWallTexture() {
        do {
            let texture = try paintRenderer.updateTexture()
            wallEntity?.model?.materials = [UnlitMaterial(texture: texture)]
        } catch {
            print("[SprayPaintSceneController] Failed to update paint texture: \(error)")
        }
    }

    private func updateAudioForCurrentCanvas() {
        audioTrackManager.updateActiveColors(store.activeColorsOnCanvas)
    }

    private func firstMatchingAncestor<T>(from entity: Entity, match: (Entity) -> T?) -> T? {
        var candidate: Entity? = entity

        while let current = candidate {
            if let result = match(current) {
                return result
            }
            candidate = current.parent
        }

        return nil
    }
}
