//
//  CPM_GraphicApp.swift
//  CPM_Graphic
//
//  Created by 김형관 on 2/20/25.
//

import SwiftUI

@main
struct CPM_GraphicApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Activity.self)
    }
}
