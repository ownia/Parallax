import Foundation
import os.signpost

/// Performance profiling module for debug mode
/// Tracks resource consumption for OCR, translation, and rendering operations
class PerformanceProfiler {
    static let shared = PerformanceProfiler()
    
    // MARK: - Configuration
    
    /// Enable/disable profiling (only active in DEBUG builds)
    #if DEBUG
    private(set) var isEnabled = true
    #else
    private(set) var isEnabled = false
    #endif
    
    /// Maximum entries per operation to prevent unbounded memory growth
    private let maxEntriesPerOperation = 100
    
    // MARK: - OS Signpost for Instruments
    
    private let log = OSLog(subsystem: "com.parallax.app", category: "Performance")
    private lazy var ocrSignpost = OSSignpostID(log: log)
    private lazy var translationSignpost = OSSignpostID(log: log)
    private lazy var renderSignpost = OSSignpostID(log: log)
    
    // MARK: - Metrics Storage
    
    private var metrics: [String: [MetricEntry]] = [:]
    private let metricsLock = NSLock()
    
    private init() {
        #if DEBUG
        metrics.reserveCapacity(Operation.allCases.count)
        #endif
    }
    
    // MARK: - Public API
    
    /// Start profiling an operation
    func begin(_ operation: Operation) -> ProfileToken? {
        guard isEnabled else { return nil }
        
        let token = ProfileToken(
            operation: operation,
            startTime: CFAbsoluteTimeGetCurrent(),
            startMemory: getCurrentMemoryUsage()
        )
        
        emitSignpostBegin(for: operation)
        return token
    }
    
    /// End profiling an operation
    func end(_ token: ProfileToken?) {
        guard isEnabled, let token = token else { return }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getCurrentMemoryUsage()
        
        let duration = endTime - token.startTime
        let memoryDelta = endMemory - token.startMemory
        
        emitSignpostEnd(for: token.operation)
        
        let entry = MetricEntry(
            timestamp: Date(),
            duration: duration,
            memoryUsage: endMemory,
            memoryDelta: memoryDelta,
            metadata: token.metadata
        )
        
        metricsLock.lock()
        if metrics[token.operation.rawValue] == nil {
            metrics[token.operation.rawValue] = []
        }
        metrics[token.operation.rawValue]?.append(entry)
        
        // Limit entries to prevent unbounded memory growth
        if let count = metrics[token.operation.rawValue]?.count, count > maxEntriesPerOperation {
            metrics[token.operation.rawValue]?.removeFirst(count - maxEntriesPerOperation)
        }
        metricsLock.unlock()
        
        logMetric(operation: token.operation, entry: entry)
    }
    
    // MARK: - Private Helpers
    
    private func emitSignpostBegin(for operation: Operation) {
        let signpostID: OSSignpostID
        switch operation {
        case .ocrRecognition, .screenCapture:
            signpostID = ocrSignpost
        case .translationOnline, .translationOffline, .translationBatch:
            signpostID = translationSignpost
        case .overlayRender:
            signpostID = renderSignpost
        }
        os_signpost(.begin, log: log, name: "Operation", signpostID: signpostID, "%{public}s", operation.rawValue)
    }
    
    private func emitSignpostEnd(for operation: Operation) {
        let signpostID: OSSignpostID
        switch operation {
        case .ocrRecognition, .screenCapture:
            signpostID = ocrSignpost
        case .translationOnline, .translationOffline, .translationBatch:
            signpostID = translationSignpost
        case .overlayRender:
            signpostID = renderSignpost
        }
        os_signpost(.end, log: log, name: "Operation", signpostID: signpostID)
    }
    
    private func logMetric(operation: Operation, entry: MetricEntry) {
        let durationMs = entry.duration * 1000
        let memoryDeltaStr = formatBytes(entry.memoryDelta)
        let memoryStr = formatBytes(entry.memoryUsage)
        
        print("[Profiler] \(operation.rawValue): \(String(format: "%.2f", durationMs))ms | Memory: \(memoryStr) (Δ\(memoryDeltaStr))")
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let absBytes = abs(bytes)
        let sign = bytes < 0 ? "-" : "+"
        
        if absBytes < 1024 {
            return "\(sign)\(absBytes) B"
        } else if absBytes < 1024 * 1024 {
            return "\(sign)\(String(format: "%.2f", Double(absBytes) / 1024)) KB"
        } else {
            return "\(sign)\(String(format: "%.2f", Double(absBytes) / (1024 * 1024))) MB"
        }
    }
}

// MARK: - Supporting Types

extension PerformanceProfiler {
    enum Operation: String, CaseIterable {
        case screenCapture = "Screen Capture"
        case ocrRecognition = "OCR Recognition"
        case translationOnline = "Translation (Online)"
        case translationOffline = "Translation (Offline)"
        case translationBatch = "Translation (Batch)"
        case overlayRender = "Overlay Render"
    }
    
    class ProfileToken {
        let operation: Operation
        let startTime: CFAbsoluteTime
        let startMemory: Int64
        var metadata: [String: Any] = [:]
        
        init(operation: Operation, startTime: CFAbsoluteTime, startMemory: Int64) {
            self.operation = operation
            self.startTime = startTime
            self.startMemory = startMemory
        }
        
        func addMetadata(key: String, value: Any) {
            metadata[key] = value
        }
    }
    
    struct MetricEntry {
        let timestamp: Date
        let duration: TimeInterval
        let memoryUsage: Int64
        let memoryDelta: Int64
        let metadata: [String: Any]
    }
}
