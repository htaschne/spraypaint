//
//  spraysongApp.swift
//  spraysong
//
//  Created by Agatha Schneider on 30/06/26.
//

import SwiftUI

@main
struct spraysongApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 2.25, height: 1.05, depth: 0.9, in: .meters)
    }
}
