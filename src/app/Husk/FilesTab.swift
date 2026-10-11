// SPDX-License-Identifier: GPL-2.0-or-later
// 簡化版文件瀏覽器 - iOS 15 兼容
import SwiftUI

struct FilesTab: View {
    var body: some View {
        NavigationView {
            DirectoryView(path: "/", title: "Files")
        }
    }
}

struct DirectoryView: View {
    let path: String
    let title: String
    
    @State private var items: [String] = []
    
    var body: some View {
        List(items, id: \.self) { item in
            let fullPath = (path as NSString).appendingPathComponent(item)
            if isDirectory(fullPath) {
                NavigationLink(destination: DirectoryView(path: fullPath, title: item)) {
                    Label(item, systemImage: "folder")
                }
            } else {
                Label(item, systemImage: "doc")
            }
        }
        .navigationTitle(title)
        .onAppear(perform: load)
    }
    
    private func load() {
        items = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }
    
    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
