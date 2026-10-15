// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import Compression

/// Manages the Java runtime (Dalvik) needed for .java games.
/// Downloaded from GitHub on first use, stored in Documents.
@MainActor
final class JavaRuntime: ObservableObject {
    static let shared = JavaRuntime()
    
    enum State: Equatable {
        case missing
        case downloading
        case ready
        case failed(String)
    }
    
    @Published private(set) var state: State = .missing
    
    /// java-runtime.tar.gz 下載地址
    static let downloadURL = "https://raw.githubusercontent.com/yongshuai1013/Husk-iOS15/main/assets/java-runtime.tar.gz"
    
    /// Path to the java-runtime directory in Documents
    static var runtimePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("java-runtime").path
    }
    
    /// Check if runtime is already downloaded
    var isReady: Bool {
        let fm = FileManager.default
        let path = Self.runtimePath
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
        
        state = .downloading
        guard let url = URL(string: Self.downloadURL) else {
            state = .failed("URL 錯誤")
            return false
        }
        
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try Self.extractTarGz(tempURL, to: docs)
            state = .ready
            return isReady
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }
    
    /// 解壓 tar.gz 到指定目錄
    private static func extractTarGz(_ src: URL, to dst: URL) throws {
        let data = try Data(contentsOf: src)
        // Gunzip
        let decompressed = try decompressGzip(data)
        // Parse tar
        try extractTar(decompressed, to: dst)
    }
    
    private static func decompressGzip(_ data: Data) throws -> Data {
        // Use Compression framework
        let bufferSize = 1024 * 1024
        var output = Data()
        try data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) in
            guard let srcBase = srcPtr.baseAddress else { return }
            var stream = compression_stream()
            var status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard status != COMPRESSION_STATUS_ERROR else {
                throw NSError(domain: "JavaRuntime", code: 1, userInfo: [NSLocalizedDescriptionKey: "解壓初始化失敗"])
            }
            defer { compression_stream_destroy(&stream) }
            
            stream.src_ptr = srcBase.assumingMemoryBound(to: UInt8.self)
            stream.src_size = data.count
            
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }
            
            repeat {
                stream.dst_ptr = dstBuffer
                stream.dst_size = bufferSize
                status = compression_stream_process(&stream, 0)
                let count = bufferSize - stream.dst_size
                output.append(dstBuffer, count: count)
            } while status == COMPRESSION_STATUS_OK
            
            if status != COMPRESSION_STATUS_END {
                throw NSError(domain: "JavaRuntime", code: 2, userInfo: [NSLocalizedDescriptionKey: "解壓失敗"])
            }
        }
        return output
    }
    
    private static func extractTar(_ data: Data, to dst: URL) throws {
        let fm = FileManager.default
        var offset = 0
        let blockSize = 512
        
        while offset + blockSize <= data.count {
            let header = data[offset..<offset+blockSize]
            // Check for end (two zero blocks)
            if header.allSatisfy({ $0 == 0 }) {
                break
            }
            
            // File name (100 bytes, null-terminated)
            let nameData = header[0..<100]
            guard let name = String(bytes: nameData.prefix(while: { $0 != 0 }), encoding: .utf8) else {
                offset += blockSize
                continue
            }
            
            // File size (12 bytes octal, at offset 124)
            let sizeData = header[124..<136]
            let sizeStr = String(bytes: sizeData.prefix(while: { $0 != 0 && $0 != 32 }), encoding: .utf8) ?? "0"
            let size = Int(sizeStr.trimmingCharacters(in: .whitespaces), radix: 8) ?? 0
            
            // Type flag (at offset 156): '0' or '\0' = file, '5' = directory
            let typeFlag = header[156]
            
            offset += blockSize
            
            if typeFlag == 53 { // '5' = directory
                let dirURL = dst.appendingPathComponent(name)
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
            } else if size > 0 {
                let fileURL = dst.appendingPathComponent(name)
                let parent = fileURL.deletingLastPathComponent()
                try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                let fileData = data[offset..<offset+size]
                try fileData.write(to: fileURL)
            }
            
            // Skip to next header (round up to 512)
            offset += (size + blockSize - 1) / blockSize * blockSize
        }
    }
}
