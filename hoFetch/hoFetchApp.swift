//
//  hoFetchApp.swift
//  hoFetch
//
//  Created by 新村彰啓 on 8/11/25.
//

import SwiftUI
import SwiftData

@main
struct hoFetchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Recording.self, AppSettings.self])
    }
}
