// SPDX-License-Identifier: GPL-2.0-or-later
// 精簡版 QEMU 啟動器 - 參考 Husk QemuRunner.swift，iOS 15 兼容
import Foundation

/// 最小 QEMU 運行器，只保留核心啟動邏輯
final class SimpleQemuRunner {
    static let shared = SimpleQemuRunner()
    private var thread: Thread?
    private(set) var isRunning = false
    
    /// 啟動 QEMU（Phase 0 Alpine，用於測試）
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        thread = Thread { [weak self] in
            self?.run()
        }
        thread?.name = "qemu-thread"
        thread?.start()
    }
    
    private func run() {
        let args = phase0Arguments()
        
        // 檢查必要文件
        let bundle = Bundle.main.bundlePath
        let kernel = "\(bundle)/vmlinuz-virt"
        let initrd = "\(bundle)/initramfs-virt"
        
        guard FileManager.default.fileExists(atPath: kernel) else {
            print("[qemu] 缺少 kernel: \(kernel)")
            isRunning = false
            return
        }
        guard FileManager.default.fileExists(atPath: initrd) else {
            print("[qemu] 缺少 initrd: \(initrd)")
            isRunning = false
            return
        }
        
        // 初始化顯示（軟件渲染，簡化）
        husk_display_init()
        
        // 轉換參數為 C 字符串（參考 QemuRunner.swift 1401-1415）
        var argv: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        argv.append(nil)
        
        print("[qemu] 調用 qemu_init，共 \(args.count) 個參數")
        argv.withUnsafeMutableBufferPointer { buf in
            qemu_init(Int32(args.count), buf.baseAddress)
        }
        print("[qemu] qemu_init 返回，進入 main_loop")
        
        // 進入主循環（不返回，直到 guest 關機）
        qemu_main_loop()
        
        print("[qemu] main_loop 返回")
        isRunning = false
    }
    
    /// Phase 0 參數（Alpine，參考 QemuRunner.swift phase0Arguments）
    /// 精簡版：去掉 GL 相關，只留基本啟動
    private func phase0Arguments() -> [String] {
        let bundle = Bundle.main.bundlePath
        
        return [
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
            "-nographic",
            // 軟件顯示（簡化，不用 virtio-gpu-gl）
            "-device", "virtio-gpu-pci",
        ]
    }
    
    func stop() {
        // 簡化版：不實現優雅關機
        isRunning = false
    }
}
