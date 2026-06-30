//
//  ContentView.swift
//  spraysong
//
//  Created by Agatha Schneider on 30/06/26.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @StateObject private var sceneController = SprayPaintSceneController()

    var body: some View {
        RealityView { content in
            sceneController.buildScene(in: &content)
        }
        .overlay(alignment: .topLeading) {
            Button {
                sceneController.undoLastStroke()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!sceneController.canUndo)
            .padding(24)
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    let location = value.convert(value.location3D, from: .local, to: value.entity)
                    sceneController.handleTap(on: value.entity, location: location)
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .targetedToAnyEntity()
                .onChanged { value in
                    let location = value.convert(value.location3D, from: .local, to: value.entity)
                    sceneController.handlePaintDrag(on: value.entity, location: location)
                }
                .onEnded { _ in
                    sceneController.endPaintDrag()
                }
        )
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
}
