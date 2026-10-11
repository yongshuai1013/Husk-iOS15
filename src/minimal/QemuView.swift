// SPDX-License-Identifier: GPL-2.0-or-later
// 最小 QEMU 啟動器 - 參考 Husk QemuRunner.swift
import SwiftUI
import Foundation

struct QemuView: View {
    @State private var isRunning = false
    @State private var log = "準備啟動...\n"
    
    var body: some View {
        VStack {
            Text(log)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            
            Button(isRunning ? "運行中..." : "啟動 QEMU") {
                if !isRunning {
                    isRunning = true
                    startQemu()
                }
            }
            .disabled(isRunning)
            .padding()
        }
        .navigationTitle("QEMU")
    }
    
    private func startQemu() {
        log += "啟動 QEMU 線程...\n"
        Thread.detachNewThread {
            runQemu()
        }
    }
    
    private func runQemu() {
        // 參考 Husk QemuRunner.swift phase0Arguments()
        let bundle = Bundle.main.bundlePath
        let args = [
            "qemu-system-aarch64",
            "-M", "virt",
            "-cpu", "cortex-a72",
            "-smp", "4",
            "-m", "1024",
            "-accel", "tcg,tb-size=256,thread=multi,split-wx=on",
            "-kernel", "\(bundle)/vmlinuz-virt",
            "-initrd", "\(bundle)/initramfs-virt",
            "-append", "console=ttyAMA0",
            "-nic", "none",
            "-nographic"
        ]
        
        // 轉換為 C 參數（參考 QemuRunner.swift 1401-1415）
        var argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        argv.append(nil)
        
        argv.withUnsafeMutableBufferPointer { buf in
            qemu_init(Int32(args.count), buf.baseAddress)
        }
        // qemu_init 返回後
        qemu_main_loop()
        // qemu_main_loop 不返回，直到 guest 關機
    }
}
