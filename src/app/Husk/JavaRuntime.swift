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
    @Published var downloadProgress: Double = 0.0
    
    /// java-runtime.tar.gz 下載地址
    static let downloadURL = "https://raw.githubusercontent.com/yongshuai1013/Husk-iOS15/main/assets/java-runtime.tar.zlib"
    
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
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 600
            let session = URLSession(configuration: config)
            let (bytes, response) = try await session.bytes(from: url)
            let total = response.expectedContentLength
            var data = Data()
            data.reserveCapacity(Int(total > 0 ? total : 40_000_000))
            for try await byte in bytes {
                data.append(byte)
                if total > 0 {
                    await MainActor.run {
                        self.downloadProgress = Double(data.count) / Double(total)
                    }
                }
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("java-runtime.tar.zlib")
            try data.write(to: tempURL)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try Self.extractArchive(tempURL, to: docs)
            state = .ready
            return isReady
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }
    
    /// Import java-runtime.tar.gz from a local file (e.g. via Files app)
    func importFromFile(_ fileURL: URL) async -> Bool {
        state = .downloading
        downloadProgress = 0
        do {
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            // Copy to temp first (in case it's not directly readable)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("java-runtime-import.tar.gz")
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: tempURL)
            await MainActor.run { self.downloadProgress = 0.5 }
            try Self.extractArchive(tempURL, to: docs)
            await MainActor.run { self.downloadProgress = 1.0 }
            try? FileManager.default.removeItem(at: tempURL)
            state = .ready
            return isReady
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }
    
    /// 解壓 tar.gz 到指定目錄
    private static func extractArchive(_ src: URL, to dst: URL) throws {
        let data = try Data(contentsOf: src)
        let tarData: Data
        if data.count >= 2 && data[0] == 0x78 && data[1] == 0x9C {
            // zlib 格式：直接解
            tarData = try zlibDecompress(data)
        } else if data.count >= 2 && data[0] == 0x1F && data[1] == 0x8B {
            // 舊版 tar.gz 已不再支援，請下載新的 java-runtime.tar.zlib
            throw NSError(domain: "JavaRuntime", code: 7, userInfo: [NSLocalizedDescriptionKey: "這是舊版 tar.gz，請下載新的 java-runtime.tar.zlib 再導入"])
        } else {
            // 假定已經是原始 tar
            tarData = data
        }
        try extractTar(tarData, to: dst)
    }

    /// zlib (RFC1950) 解壓：COMPRESSION_ZLIB 直接處理
    private static func zlibDecompress(_ data: Data) throws -> Data {
        let bufferSize = 1024 * 1024
        var output = Data()
        var ok = false
        data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) in
            guard let srcBase = srcPtr.baseAddress else { return }
            var dummy: UInt8 = 0
            var stream = compression_stream(
                dst_ptr: withUnsafeMutablePointer(to: &dummy) { $0 },
                dst_size: 0,
                src_ptr: withUnsafePointer(to: &dummy) { $0 },
                src_size: 0,
                state: nil
            )
            guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) != COMPRESSION_STATUS_ERROR else { return }
            defer { compression_stream_destroy(&stream) }
            stream.src_ptr = srcBase.assumingMemoryBound(to: UInt8.self)
            stream.src_size = data.count
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }
            var status: compression_status
            repeat {
                stream.dst_ptr = dstBuffer
                stream.dst_size = bufferSize
                status = compression_stream_process(&stream, 0)
                let count = bufferSize - stream.dst_size
                if count > 0 { output.append(dstBuffer, count: count) }
                if status == COMPRESSION_STATUS_ERROR { break }
            } while status == COMPRESSION_STATUS_OK
            ok = (status == COMPRESSION_STATUS_END)
        }
        guard ok else {
            throw NSError(domain: "JavaRuntime", code: 2, userInfo: [NSLocalizedDescriptionKey: "解壓失敗"])
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
