import Foundation
import SwiftUI

enum TranslationError: Error {
    case networkError(String)
    case parseError
    case rateLimited
    case offlineUnavailable(String)
}

class TranslationService {
    static let shared = TranslationService()
    
    /// Maximum concurrent requests
    private let maxConcurrentRequests = 5
    
    /// Translation cache, key format: "text_targetLang_mode"
    private var translationCache: [String: String] = [:]
    private let cacheLock = NSLock()
    
    /// Maximum cache entries to prevent unbounded memory growth
    private let maxCacheSize = 500
    
    private init() {}
    
    /// Check if offline translation is available on this system
    static var isOfflineAvailable: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }
    
    /// Translate text blocks in batch
    func translate(blocks: [TextBlock], to targetLang: String, completion: @escaping ([TextBlock], Bool) -> Void) {
        let mode = Settings.shared.translationMode
        
        if mode == .offline && Self.isOfflineAvailable {
            translateOfflineWrapper(blocks: blocks, to: targetLang, completion: completion)
        } else {
            if mode == .offline {
                print("[!] Offline translation requires macOS 15.0+, falling back to online")
            }
            translateOnline(blocks: blocks, to: targetLang, completion: completion)
        }
    }
    
    // MARK: - Offline Translation Wrapper
    
    private func translateOfflineWrapper(blocks: [TextBlock], to targetLang: String, completion: @escaping ([TextBlock], Bool) -> Void) {
        if #available(macOS 15.0, *) {
            translateOffline(blocks: blocks, to: targetLang, completion: completion)
        }
    }
    
    // MARK: - Online Translation (Google API)
    
    func translateOnline(blocks: [TextBlock], to targetLang: String, completion: @escaping ([TextBlock], Bool) -> Void) {
        var translatedBlocks: [TextBlock] = Array(repeating: TextBlock(rect: .zero, text: ""), count: blocks.count)
        var hasError = false
        let lock = NSLock()
        
        let group = DispatchGroup()
        
        // Use OperationQueue for better QoS handling
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = maxConcurrentRequests
        queue.qualityOfService = .userInitiated
        
        for (index, block) in blocks.enumerated() {
            group.enter()
            
            queue.addOperation { [weak self] in
                guard let self = self else {
                    group.leave()
                    return
                }
                
                let semaphore = DispatchSemaphore(value: 0)
                
                self.translateText(block.text, to: targetLang) { result in
                    lock.lock()
                    switch result {
                    case .success(let translatedText):
                        translatedBlocks[index] = TextBlock(rect: block.rect, text: translatedText)
                    case .failure(let error):
                        print("[!] Translation error: \(error)")
                        translatedBlocks[index] = TextBlock(rect: block.rect, text: block.text)
                        hasError = true
                    }
                    lock.unlock()
                    semaphore.signal()
                }
                
                semaphore.wait()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(translatedBlocks, !hasError)
        }
    }
    
    // MARK: - Online Translation Helper
    
    private func translateText(_ text: String, to targetLang: String, completion: @escaping (Result<String, TranslationError>) -> Void) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            completion(.success(text))
            return
        }
        
        let cacheKey = "\(trimmedText)_\(targetLang)_online"
        cacheLock.lock()
        if let cached = translationCache[cacheKey] {
            cacheLock.unlock()
            completion(.success(cached))
            return
        }
        cacheLock.unlock()
        
        guard let encodedText = trimmedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(.networkError("Failed to encode text")))
            return
        }
        
        let urlString = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=\(targetLang)&dt=t&q=\(encodedText)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.networkError("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 429 {
                    completion(.failure(.rateLimited))
                    return
                }
                if httpResponse.statusCode != 200 {
                    completion(.failure(.networkError("HTTP \(httpResponse.statusCode)")))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(.networkError("No data received")))
                return
            }
            
            let result = self?.parseTranslationResponse(data, originalText: text) ?? text
            self?.addToCache(key: cacheKey, value: result)
            completion(.success(result))
        }.resume()
    }
    
    private func parseTranslationResponse(_ data: Data, originalText: String) -> String {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [Any],
               let translations = json.first as? [Any] {
                var result = ""
                
                for item in translations {
                    if let translationArray = item as? [Any],
                       !translationArray.isEmpty,
                       let translatedText = translationArray[0] as? String {
                        result += translatedText
                    }
                }
                
                if !result.isEmpty {
                    return result
                }
            }
        } catch {}
        
        return originalText
    }
    
    // MARK: - Cache Management
    
    func addToCache(key: String, value: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if translationCache.count >= maxCacheSize {
            translationCache.removeAll(keepingCapacity: true)
        }
        translationCache[key] = value
    }
    
    func getCached(key: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return translationCache[key]
    }
    
    func clearCache() {
        cacheLock.lock()
        translationCache.removeAll()
        cacheLock.unlock()
    }
    
    func invalidateOfflineSession() {
        // Reserved for future use
    }
}
