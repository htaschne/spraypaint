//
//  SprayCanFactory.swift
//  spraysong
//
//  Created by Codex on 30/06/26.
//

import RealityKit
import UIKit

enum SprayCanFactory {
    static func makeSprayCan(color: PaintColor, isSelected: Bool) -> Entity {
        let can = Entity()
        can.name = color.entityName

        let body = ModelEntity(
            mesh: .generateCylinder(height: 0.18, radius: 0.035),
            materials: [bodyMaterial(for: color, isSelected: isSelected)]
        )
        body.name = "\(color.entityName)-body"
        body.components.set(InputTargetComponent())
        body.components.set(CollisionComponent(shapes: [.generateBox(width: 0.08, height: 0.2, depth: 0.08)]))

        let cap = ModelEntity(
            mesh: .generateCylinder(height: 0.045, radius: 0.029),
            materials: [UnlitMaterial(color: color.uiColor, applyPostProcessToneMap: false)]
        )
        cap.name = "\(color.entityName)-cap"
        cap.position = SIMD3<Float>(0, 0.112, 0)
        cap.components.set(InputTargetComponent())
        cap.components.set(CollisionComponent(shapes: [.generateBox(width: 0.065, height: 0.055, depth: 0.065)]))

        let nozzle = ModelEntity(
            mesh: .generateBox(width: 0.026, height: 0.018, depth: 0.034, cornerRadius: 0.004),
            materials: [SimpleMaterial(color: .white, roughness: 0.35, isMetallic: false)]
        )
        nozzle.name = "\(color.entityName)-nozzle"
        nozzle.position = SIMD3<Float>(0, 0.152, 0)
        nozzle.components.set(InputTargetComponent())
        nozzle.components.set(CollisionComponent(shapes: [.generateBox(width: 0.035, height: 0.026, depth: 0.044)]))

        let highlight = ModelEntity(
            mesh: .generateCylinder(height: 0.008, radius: isSelected ? 0.052 : 0.042),
            materials: [highlightMaterial(isSelected: isSelected)]
        )
        highlight.name = "\(color.entityName)-highlight"
        highlight.position = SIMD3<Float>(0, -0.115, 0)

        can.addChild(body)
        can.addChild(cap)
        can.addChild(nozzle)
        can.addChild(highlight)

        return can
    }

    static func refreshSprayCan(_ can: Entity, color: PaintColor, isSelected: Bool) {
        guard let body = can.findEntity(named: "\(color.entityName)-body") as? ModelEntity,
              let highlight = can.findEntity(named: "\(color.entityName)-highlight") as? ModelEntity else {
            return
        }

        body.model?.materials = [bodyMaterial(for: color, isSelected: isSelected)]
        highlight.model?.materials = [highlightMaterial(isSelected: isSelected)]
        highlight.scale = isSelected ? SIMD3<Float>(1.18, 1.18, 1.18) : SIMD3<Float>(1, 1, 1)
    }

    private static func bodyMaterial(for color: PaintColor, isSelected: Bool) -> SimpleMaterial {
        let tint = isSelected
            ? UIColor(red: 0.96, green: 0.96, blue: 0.90, alpha: 1.0)
            : UIColor(red: 0.80, green: 0.82, blue: 0.80, alpha: 1.0)
        return SimpleMaterial(color: tint, roughness: 0.45, isMetallic: true)
    }

    private static func highlightMaterial(isSelected: Bool) -> UnlitMaterial {
        let color = isSelected
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.28, green: 0.28, blue: 0.28, alpha: 1.0)
        return UnlitMaterial(color: color, applyPostProcessToneMap: false)
    }
}
