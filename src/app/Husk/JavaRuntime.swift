// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

/// Manages the Java runtime (Dalvik) needed for .java games.
/// Downloaded from GitHub releases on first use, stored in Documents.
@MainActor
final class JavaRuntime: ObservableObject {
    static let shared = JavaRuntime()
    
    enum State: Equatable {
        case missing
        case downloading(progress: Double)
        case ready
        case failed(String)
    }
    
    @Published private(set) var state: State = .missing
    
    /// GitHub release tag holding the java-runtime.zip
    static let releaseTag = "java-runtime-v1"
    static let assetName = "java-runtime.zip"
    
    /// Path to the java-runtime directory in Documents
    static var runtimePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("java-runtime").path
    }
    
    /// Check if runtime is already downloaded
    var isReady: Bool {
        let fm = FileManager.default
        let path = Self.runtimePath
        // Check for a key file
        return fm.fileExists(atPath: path + "/com.android.art/javalib/core-oj.jar")
    }
    
    /// Ensure runtime is available, downloading if needed
    func ensureAvailable() async -> Bool {
        if isReady {
            if case .missing = state {
                state = .ready
            }
            return true
        }
        
        // Download
        state = .downloading(progress: 0)
        let urlString = "https://github.com/yongshuai1013/Husk-iOS15/releases/download/\(Self.releaseTag)/\(Self.assetName)"
        guard let url = URL(string: urlString) else {
            state = .failed("URL 錯誤")
            return false
        }
        
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url) { [weak self] bytesWritten, totalBytes in
                // Progress callback (iOS 15 doesn't have async bytes, use delegate instead)
            }
            // Unzip to Documents
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try self.unzip(tempURL, to: docs)
            state = .ready
            return isReady
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }
    
    private func unzip(_ zipURL: URL, to destination: URL) throws {
        // Use system unzip via Process (simpler than writing a zip parser)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(domain: "JavaRuntime", code: 1, userInfo: [NSLocalizedDescriptionKey: "解壓失敗"])
        }
    }
}
