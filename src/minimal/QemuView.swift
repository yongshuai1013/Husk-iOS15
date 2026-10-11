// SPDX-License-Identifier: GPL-2.0-or-later
// QEMU 啟動視圖 - iOS 15 兼容
import SwiftUI

struct QemuView: View {
    @State private var isRunning = false
    @State private var log = "準備啟動...\n"
    
    var body: some View {
        VStack {
            ScrollView {
                Text(log)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            
            Button(isRunning ? "運行中..." : "啟動 Alpine") {
                if !isRunning {
                    isRunning = true
                    log += "啟動中...\n"
                    SimpleQemuRunner.shared.start()
                    log += "QEMU 線程已啟動\n"
                }
            }
            .disabled(isRunning)
            .padding()
        }
        .navigationTitle("QEMU 測試")
    }
}
