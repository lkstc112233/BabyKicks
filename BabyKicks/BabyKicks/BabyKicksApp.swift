//
//  BabyKicksApp.swift
//  BabyKicks
//
//  Created by PhotonCat on 6/18/26.
//

import SwiftUI

@main
struct BabyKicksApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = KickStore()
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environmentObject(store)
                .environmentObject(sessionManager)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    store.reload()
                    sessionManager.refreshFromLiveActivity()
                }
        }
    }
}
