// SPDX-License-Identifier: GPL-2.0-or-later
// APK 列表 - 精簡版，參考 Husk TranslationLayer.swift
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
            NavigationLink(apk.name, destination: QemuView())
        }
        .navigationTitle("APK 列表")
        .onAppear(perform: scanApks)
    }
    
    private func scanApks() {
        // 掃描 Documents 目錄下的 .apk 文件
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
