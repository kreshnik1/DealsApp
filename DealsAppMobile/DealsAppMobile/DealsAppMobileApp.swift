//
//  DealsAppMobileApp.swift
//  DealsAppMobile
//
//  Created by Kushtrim Abdiu on 2026-06-06.
//

import SwiftUI

@main
struct DealsAppMobileApp: App {
    @State private var appState = AppState()
    private let appServices = AppServices.live

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appState)
                .environment(\.appServices, appServices)
        }
    }
}
