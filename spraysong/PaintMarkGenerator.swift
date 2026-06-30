//
//  PaintMarkGenerator.swift
//  spraysong
//
//  Created by Codex on 30/06/26.
//

import CoreGraphics
import Foundation
import RealityKit
import UIKit

@MainActor
final class PaintTextureRenderer {
    private let width: Int
    private let height: Int
    private let bytesPerPixel = 4
    private let bytes: UnsafeMutableRawPointer
    private let context: CGContext
    private var textureResource: TextureResource?

    private let textureOptions = TextureResource.CreateOptions(
        semantic: .color,
        mipmapsMode: .none
    )

    init(width: Int = 1024, height: Int = 1024) {
        self.width = width
        self.height = height

        let byteCount = width * height * bytesPerPixel
        let allocatedBytes = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 64)
        allocatedBytes.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)

        guard let createdContext = CGContext(
            data: allocatedBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            allocatedBytes.deallocate()
            fatalError("Failed to create paint canvas context")
        }

        bytes = allocatedBytes
        context = createdContext
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        clear()
    }

    deinit {
        bytes.deallocate()
    }

    func clear() {
        context.setBlendMode(.copy)
        context.setFillColor(PaintTextureRenderer.wallBaseColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setBlendMode(.normal)
    }

    func draw(sample: PaintSample, color: PaintColor) {
        var random = SeededRandomNumberGenerator(seed: sample.seed)
        let radiusPixels = max(8, CGFloat(sample.radius) * CGFloat(min(width, height)))
        let dotCount = max(42, Int(radiusPixels * 1.7))
        let center = CGPoint(
            x: CGFloat(sample.uv.x) * CGFloat(width),
            y: CGFloat(sample.uv.y) * CGFloat(height)
        )

        for _ in 0..<dotCount {
            let angle = CGFloat(random.nextFloat(in: 0...(2 * .pi)))
            let falloff = pow(CGFloat(random.nextFloat(in: 0...1)), 1.9)
            let distance = radiusPixels * falloff
            let dotRadius = CGFloat(random.nextFloat(in: 1.4...4.8)) * (1.1 - (falloff * 0.35))
            let edgeFade = 1 - min(max(falloff, 0), 1)
            let alpha = CGFloat(sample.opacity) * (0.18 + (edgeFade * 0.58))

            let dotCenter = CGPoint(
                x: center.x + (cos(angle) * distance),
                y: center.y + (sin(angle) * distance)
            )
            let rect = CGRect(
                x: dotCenter.x - dotRadius,
                y: dotCenter.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )

            context.setFillColor(color.uiColor.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: rect)
        }
    }

    func replay(strokes: [PaintStroke]) {
        clear()

        for stroke in strokes {
            for sample in stroke.samples {
                draw(sample: sample, color: stroke.color)
            }
        }
    }

    @discardableResult
    func updateTexture() throws -> TextureResource {
        let image = makeImage()

        if let textureResource {
            try textureResource.replace(withImage: image, options: textureOptions)
            return textureResource
        }

        let generatedTexture = try TextureResource(
            image: image,
            withName: "spray-paint-canvas",
            options: textureOptions
        )
        textureResource = generatedTexture
        return generatedTexture
    }

    private func makeImage() -> CGImage {
        guard let image = context.makeImage() else {
            fatalError("Failed to create paint canvas image")
        }

        return image
    }

    static let wallBaseColor = UIColor(red: 0.86, green: 0.86, blue: 0.82, alpha: 1.0)
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        let unit = Float(next() >> 40) / 16_777_215
        return range.lowerBound + ((range.upperBound - range.lowerBound) * unit)
    }
}
