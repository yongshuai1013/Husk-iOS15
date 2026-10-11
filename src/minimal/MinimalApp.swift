// SPDX-License-Identifier: GPL-2.0-or-later
// Husk-iOS15 主界面 - 參考 Husk ContentView.swift，iOS 15 兼容
import SwiftUI

@main
struct MinimalApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

/// 主 Tab 視圖（參考 Husk ContentView 的 TabView）
/// iOS 15 用 TabView + NavigationView，不用 NavigationStack
struct MainTabView: View {
    var body: some View {
        TabView {
            // 首頁：APK 列表
            NavigationView {
                ApkListView()
            }
            .tabItem {
                Label("首頁", systemImage: "house.fill")
            }
            
            // QEMU 測試
            NavigationView {
                QemuView()
            }
            .tabItem {
                Label("QEMU", systemImage: "cpu.fill")
            }
            
            // 設置
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("設置", systemImage: "gearshape.fill")
            }
        }
    }
}

/// 設置頁（精簡版）
struct SettingsView: View {
    var body: some View {
        List {
            Section(header: Text("關於")) {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("0.1.0-iOS15")
                        .foregroundColor(.secondary)
                }
                NavigationLink("關於 Husk", destination: AboutView())
            }
            
            Section(header: Text("調試")) {
                NavigationLink("啟動 Alpine", destination: QemuView())
            }
        }
        .navigationTitle("設置")
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Husk iOS15 重構版")
                .font(.title2)
                .fontWeight(.bold)
            Text("QEMU 核心保留，UI 精簡為 iOS 15 兼容版本。")
                .foregroundColor(.secondary)
            Text("參考：Leviidev/Husk")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle("關於")
    }
}
