// SPDX-License-Identifier: GPL-2.0-or-later
// 簡化版 JIT 設置 - iOS 15，美觀
import SwiftUI

struct JITSetupView: View {
    @State private var currentStep = 0
    
    let steps = [
        JITStep(title: "配對設備", description: "使用 StikJIT 配對你的設備", icon: "cable.connector"),
        JITStep(title: "導入文件", description: "導入配對文件", icon: "doc.badge.plus"),
        JITStep(title: "連接", description: "連接到設備啟用 JIT", icon: "wifi"),
        JITStep(title: "完成", description: "JIT 已啟用，可以運行了", icon: "checkmark.circle.fill"),
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 進度指示器
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(idx <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 6)
                    }
                }
                .padding()
                
                // 當前步驟內容
                VStack(spacing: 20) {
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(steps[currentStep].title)
                        .font(.title2)
                        .bold()
                    
                    Text(steps[currentStep].description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 40)
                
                Spacer()
                
                // 按鈕
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("上一步") {
                            currentStep -= 1
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(currentStep == steps.count - 1 ? "完成" : "下一步") {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("JIT 設置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct JITStep {
    let title: String
    let description: String
    let icon: String
}
