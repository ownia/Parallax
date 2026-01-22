import Vision
import AppKit

class OCRService {
    static let shared = OCRService()
    
    // Cached configuration to avoid repeated array allocation
    private let recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant", "ja", "ko"]
    
    private init() {}
    
    /// Recognize text in an image
    /// - Parameter image: The image to recognize
    /// - Returns: Array of recognized text blocks
    func recognizeText(in image: CGImage) -> [TextBlock] {
        let profilerToken = PerformanceProfiler.shared.begin(.ocrRecognition)
        profilerToken?.addMetadata(key: "imageSize", value: "\(image.width)x\(image.height)")
        
        // Optimize image with Metal acceleration if available
        let processedImage: CGImage
        if Settings.shared.useMetalAcceleration && MetalAccelerator.shared.isAvailable {
            // Use combined optimization (more efficient than separate calls)
            processedImage = MetalAccelerator.shared.optimizeForOCR(image) ?? image
            profilerToken?.addMetadata(key: "acceleration", value: "Metal")
        } else {
            processedImage = image
            profilerToken?.addMetadata(key: "acceleration", value: "CPU")
        }
        
        var results: [TextBlock] = []
        
        // Use processed image dimensions for coordinate conversion
        let imageWidth = CGFloat(processedImage.width)
        let imageHeight = CGFloat(processedImage.height)
        
        // Calculate scale factor if image was resized
        let scaleX = CGFloat(image.width) / imageWidth
        let scaleY = CGFloat(image.height) / imageHeight
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("[!] OCR error: \(error.localizedDescription)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            // Pre-allocate array capacity to avoid dynamic resizing
            results.reserveCapacity(observations.count)
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                
                // Vision returns normalized coordinates (0.0-1.0), origin at bottom-left
                // Need to convert to pixel coordinates, origin at top-left
                let boundingBox = observation.boundingBox
                
                // Convert to processed image coordinates
                let x = boundingBox.origin.x * imageWidth
                let w = boundingBox.size.width * imageWidth
                let h = boundingBox.size.height * imageHeight
                let y = (1 - boundingBox.origin.y - boundingBox.size.height) * imageHeight
                
                // Scale back to original image coordinates
                let rect = CGRect(
                    x: x * scaleX,
                    y: y * scaleY,
                    width: w * scaleX,
                    height: h * scaleY
                )
                results.append(TextBlock(rect: rect, text: topCandidate.string))
            }
        }
        
        // Use accurate mode for better recognition results
        request.recognitionLevel = .accurate
        // Support multiple languages (use cached array to avoid repeated allocation)
        request.recognitionLanguages = recognitionLanguages
        // Use GPU acceleration if available
        request.usesCPUOnly = false
        
        let handler = VNImageRequestHandler(cgImage: processedImage, options: [:])
        
        do {
            // perform() is synchronous and returns after completion
            // No need for additional semaphore to wait
            try handler.perform([request])
        } catch {
            print("[!] OCR request failed: \(error.localizedDescription)")
        }
        
        profilerToken?.addMetadata(key: "blocksFound", value: results.count)
        PerformanceProfiler.shared.end(profilerToken)
        
        return results
    }
}
