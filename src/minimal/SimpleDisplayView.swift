// SPDX-License-Identifier: GPL-2.0-or-later
// 精簡版顯示視圖 - 參考 Husk HuskGLView.swift
// iOS 15 兼容，使用軟件幀緩衝（簡化版）
import SwiftUI
import UIKit

/// 簡化顯示視圖：用 UIImageView 顯示 QEMU 的幀緩衝
/// 參考 Husk 的 husk_display_lock_frame/unlock_frame
struct SimpleDisplayView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // 定時從 QEMU 獲取幀並顯示
        // 實際實現需要定時器，這裡是框架
    }
}

/// QEMU 顯示視圖（帶啟動按鈕）
struct QemuDisplayView: View {
    @State private var isRunning = false
    
    var body: some View {
        VStack {
            // 顯示區域
            SimpleDisplayView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 控制按鈕
            HStack {
                Button(isRunning ? "停止" : "啟動") {
                    if !isRunning {
                        isRunning = true
                        SimpleQemuRunner.shared.start()
                    }
                }
                .padding()
            }
        }
        .navigationTitle("QEMU 顯示")
    }
}
