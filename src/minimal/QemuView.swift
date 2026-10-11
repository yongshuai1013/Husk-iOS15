// SPDX-License-Identifier: GPL-2.0-or-later
// QEMU 啟動視圖 - 接收 APK 參數
import SwiftUI

struct QemuView: View {
    var apk: ApkInfo? = nil
    
    @State private var isRunning = false
    @State private var log = ""
    
    var body: some View {
        VStack {
            // 顯示選中的 APK
            if let apk = apk {
                Text("APK: \(apk.name)")
                    .font(.headline)
                    .padding(.top)
                Text(apk.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("測試模式：Alpine")
                    .font(.headline)
                    .padding(.top)
            }
            
            ScrollView {
                Text(log)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            
            Button(isRunning ? "運行中..." : "啟動") {
                if !isRunning {
                    isRunning = true
                    log += "啟動中...\n"
                    if let apk = apk {
                        log += "APK: \(apk.path)\n"
                        // TODO: 翻譯層啟動 APK
                    }
                    SimpleQemuRunner.shared.start()
                    log += "QEMU 線程已啟動\n"
                }
            }
            .disabled(isRunning)
            .padding()
        }
        .navigationTitle(apk?.name ?? "QEMU 測試")
    }
}
