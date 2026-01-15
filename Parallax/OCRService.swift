import Vision
import AppKit

class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    /// Recognize text in an image
    /// - Parameter image: The image to recognize
    /// - Returns: Array of recognized text blocks
    func recognizeText(in image: CGImage) -> [TextBlock] {
        var results: [TextBlock] = []
        
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        
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
                
                let x = boundingBox.origin.x * imageWidth
                let w = boundingBox.size.width * imageWidth
                let h = boundingBox.size.height * imageHeight
                let y = (1 - boundingBox.origin.y - boundingBox.size.height) * imageHeight
                
                let rect = CGRect(x: x, y: y, width: w, height: h)
                results.append(TextBlock(rect: rect, text: topCandidate.string))
            }
        }
        
        // Use accurate mode for better recognition results
        request.recognitionLevel = .accurate
        // Support multiple languages
        request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant", "ja", "ko"]
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        
        do {
            // perform() is synchronous and returns after completion
            // No need for additional semaphore to wait
            try handler.perform([request])
        } catch {
            print("[!] OCR request failed: \(error.localizedDescription)")
        }
        
        return results
    }
}
