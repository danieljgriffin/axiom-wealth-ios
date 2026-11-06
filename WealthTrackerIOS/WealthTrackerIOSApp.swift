//
//  WealthTrackerIOSApp.swift
//  WealthTrackerIOS
//
//  Created by Daniel Griffin on 29/11/2025.
//

import SwiftUI

@main
struct WealthTrackerIOSApp: App {
    var body: some Scene {
        WindowGroup {
            if AppConfig.apiToken.isEmpty {
                ContentUnavailableView(
                    "API key required",
                    systemImage: "lock",
                    description: Text("Set the private API key in the Xcode project, then build the app again.")
                )
            } else {
                ContentView()
            }
        }
    }
}
