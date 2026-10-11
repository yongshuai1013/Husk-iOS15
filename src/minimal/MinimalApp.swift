// SPDX-License-Identifier: GPL-2.0-or-later
// Husk-iOS15 最小重構版 - iOS 15 兼容
import SwiftUI

@main
struct MinimalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("啟動 Alpine (測試)", destination: QemuView())
                NavigationLink("關於", destination: AboutView())
            }
            .navigationTitle("Husk iOS15")
        }
        // iOS 15 用 NavigationView，不用 NavigationStack
    }
}

struct AboutView: View {
    var body: some View {
        Text("Husk iOS 15 重構版\nQEMU 核心保留，UI 精簡")
            .padding()
    }
}
