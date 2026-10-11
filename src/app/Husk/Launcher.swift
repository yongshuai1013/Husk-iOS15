// SPDX-License-Identifier: GPL-2.0-or-later
// 簡化版啟動器 - iOS 15，美觀
import SwiftUI

struct Launcher: View {
    @State private var searchText = ""
    @State private var apps: [AppItem] = []
    
    var filtered: [AppItem] {
        if searchText.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(filtered) { app in
                        NavigationLink(destination: AppDetailView(app: app)) {
                            AppCard(app: app)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Husk")
            .searchable(text: $searchText, prompt: "搜索應用")
            .onAppear(perform: loadApps)
        }
    }
    
    private func loadApps() {
        // TODO: 從掃描結果加載
        apps = []
    }
}

struct AppItem: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let iconName: String
}

struct AppCard: View {
    let app: AppItem
    
    var body: some View {
        VStack(spacing: 12) {
            // 圖標
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: app.iconName)
                        .font(.title)
                        .foregroundColor(.white)
                )
            
            // 名稱
            Text(app.name)
                .font(.headline)
                .lineLimit(1)
            
            Text(app.bundleId)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct AppDetailView: View {
    let app: AppItem
    
    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: app.iconName)
                        .font(.largeTitle)
                        .foregroundColor(.white)
                )
            
            Text(app.name)
                .font(.title)
                .bold()
            
            Text(app.bundleId)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: launch) {
                Label("啟動", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func launch() {
        // TODO: 啟動 QEMU
    }
}
