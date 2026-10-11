// SPDX-License-Identifier: GPL-2.0-or-later
// APK 列表 - 點擊後傳遞到 QEMU 視圖
import SwiftUI
import Foundation

struct ApkInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
}

struct ApkListView: View {
    @State private var apks: [ApkInfo] = []
    
    var body: some View {
        List(apks) { apk in
            NavigationLink(destination: QemuView(apk: apk)) {
                VStack(alignment: .leading) {
                    Text(apk.name)
                        .font(.headline)
                    Text(apk.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .navigationTitle("APK 列表")
        .onAppear(perform: scanApks)
    }
    
    private func scanApks() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)
            apks = files
                .filter { $0.pathExtension.lowercased() == "apk" }
                .map { ApkInfo(name: $0.lastPathComponent, path: $0.path) }
        } catch {
            apks = []
        }
    }
}
