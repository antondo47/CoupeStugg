//
//  Coupe_stuffApp.swift
//  Coupe stuff
//
//  Created by Do Ngoc Anh on 1/25/26.
//

import SwiftUI
import FirebaseCore

@main
struct Coupe_stuffApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(CoupleSyncService())
        }
    }
}
