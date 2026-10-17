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
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("java-runtime.tar.gz")
            try data.write(to: tempURL)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try Self.extractTarGz(tempURL, to: docs)
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
            try Self.extractTarGz(tempURL, to: docs)
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
    private static func extractTarGz(_ src: URL, to dst: URL) throws {
        let data = try Data(contentsOf: src)
        // Gunzip
        let decompressed = try decompressGzip(data)
        // Parse tar
        try extractTar(decompressed, to: dst)
    }
    
    private static func decompressGzip(_ data: Data) throws -> Data {
        // 解析 gzip 頭，取出 deflate 數據，用 libz 的 raw inflate 解壓
        guard data.count > 18 else {
            throw NSError(domain: "JavaRuntime", code: 3, userInfo: [NSLocalizedDescriptionKey: "文件太小，不是有效的 gzip"])
        }
        guard data[0] == 0x1F && data[1] == 0x8B else {
            throw NSError(domain: "JavaRuntime", code: 4, userInfo: [NSLocalizedDescriptionKey: "不是 gzip 格式（魔數不對）"])
        }
        let flags = data[3]
        var headerSize = 10
        if flags & 0x04 != 0 {
            guard data.count > headerSize + 2 else {
                throw NSError(domain: "JavaRuntime", code: 5, userInfo: [NSLocalizedDescriptionKey: "gzip 頭損壞"])
            }
            let xlen = Int(data[headerSize]) | (Int(data[headerSize + 1]) << 8)
            headerSize += 2 + xlen
        }
        if flags & 0x08 != 0 {
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        if flags & 0x10 != 0 {
            while headerSize < data.count && data[headerSize] != 0 { headerSize += 1 }
            headerSize += 1
        }
        if flags & 0x02 != 0 { headerSize += 2 }
        guard data.count > headerSize + 8 else {
            throw NSError(domain: "JavaRuntime", code: 6, userInfo: [NSLocalizedDescriptionKey: "gzip 數據不完整"])
        }
        let deflateData = data[headerSize..<(data.count - 8)]
        
        // 用 Compression 框架解 raw deflate：構造一個最小的 zlib 流
        // zlib 頭 78 9C + deflate + Adler32（我們計算正確的）
        // 為了得到正確的 Adler32，先用不驗證的方式解一次
        // 簡化：直接嘗試用 zlib 包裝解，如果失敗則報錯
        var zlibData = Data([0x78, 0x9C])
        zlibData.append(contentsOf: deflateData)
        
        let bufferSize = 1024 * 1024
        var output = Data()
        let result: Int32 = zlibData.withUnsafeBytes { srcPtr in
            guard let srcBase = srcPtr.baseAddress else { return -1 }
            var dummy: UInt8 = 0
            var stream = compression_stream(
                dst_ptr: withUnsafeMutablePointer(to: &dummy) { $0 },
                dst_size: 0,
                src_ptr: withUnsafePointer(to: &dummy) { $0 },
                src_size: 0,
                state: nil
            )
            guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) != COMPRESSION_STATUS_ERROR else {
                return -1
            }
            defer { compression_stream_destroy(&stream) }
            stream.src_ptr = srcBase.assumingMemoryBound(to: UInt8.self)
            stream.src_size = zlibData.count
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }
            var status: compression_status
            repeat {
                stream.dst_ptr = dstBuffer
                stream.dst_size = bufferSize
                status = compression_stream_process(&stream, 0)
                let count = bufferSize - stream.dst_size
                if count > 0 {
                    output.append(dstBuffer, count: count)
                }
                // 如果遇到數據錯誤，嘗試忽略 Adler32 繼續
                if status == COMPRESSION_STATUS_ERROR {
                    break
                }
            } while status == COMPRESSION_STATUS_OK
            return status == COMPRESSION_STATUS_END ? 0 : Int32(status)
        }
        guard result == 0 else {
            throw NSError(domain: "JavaRuntime", code: 2, userInfo: [NSLocalizedDescriptionKey: "解壓失敗 (\(result))"])
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
