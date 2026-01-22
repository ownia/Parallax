import Metal
import MetalKit
import CoreImage
import AppKit

/// Metal-accelerated image processing for Screen Capture and OCR Recognition
class MetalAccelerator {
    static let shared = MetalAccelerator()
    
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let ciContext: CIContext?
    
    /// Check if Metal is available on this system
    var isAvailable: Bool {
        return device != nil && commandQueue != nil && ciContext != nil
    }
    
    private init() {
        // Initialize Metal device and command queue
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = device?.makeCommandQueue()
        
        // Create CIContext with Metal device for GPU-accelerated image processing
        if let device = device {
            // Optimized settings for OCR preprocessing
            self.ciContext = CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                .cacheIntermediates: true,  // Cache intermediate results
                .priorityRequestLow: false,  // High priority for better performance
                .useSoftwareRenderer: false  // Force GPU rendering
            ])
        } else {
            self.ciContext = nil
        }
        
        if isAvailable {
            print("[Metal] Accelerator initialized")
            print("[Metal] Device: \(device?.name ?? "Unknown")")
        } else {
            print("[!] Metal not available, using CPU fallback")
        }
    }
    
    // MARK: - Screen Capture Optimization
    
    /// Convert CGDisplayCreateImage result to optimized format for OCR
    /// This reduces memory usage and improves OCR performance
    func optimizeScreenCapture(_ cgImage: CGImage) -> CGImage? {
        guard isAvailable, let ciContext = ciContext else {
            return cgImage
        }
        
        let inputImage = CIImage(cgImage: cgImage)
        
        // For large screenshots, downsample if necessary
        // OCR doesn't need full retina resolution
        let maxDimension: CGFloat = 3840  // 4K max
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        var outputImage = inputImage
        
        if width > maxDimension || height > maxDimension {
            let scale = min(maxDimension / width, maxDimension / height)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            outputImage = outputImage.transformed(by: transform)
        }
        
        // Render using Metal
        let extent = outputImage.extent
        return ciContext.createCGImage(outputImage, from: extent)
    }
    
    // MARK: - OCR Recognition Optimization
    
    /// Preprocess image for OCR using Metal acceleration
    /// Applies sharpening and contrast enhancement to improve text recognition
    func preprocessForOCR(_ cgImage: CGImage) -> CGImage? {
        guard isAvailable, let ciContext = ciContext else {
            return cgImage
        }
        
        let inputImage = CIImage(cgImage: cgImage)
        var outputImage = inputImage
        
        // 1. Sharpen for better text clarity (most important for OCR)
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(outputImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.5, forKey: kCIInputSharpnessKey)  // Increased from 0.4
            if let result = sharpenFilter.outputImage {
                outputImage = result
            }
        }
        
        // 2. Enhance contrast for better text/background separation
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(outputImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.15, forKey: kCIInputContrastKey)  // Slight contrast boost
            contrastFilter.setValue(1.0, forKey: kCIInputSaturationKey)
            contrastFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
            if let result = contrastFilter.outputImage {
                outputImage = result
            }
        }
        
        // Render using Metal (GPU accelerated)
        let extent = outputImage.extent
        return ciContext.createCGImage(outputImage, from: extent)
    }
    
    // MARK: - Combined Optimization (Screen Capture + OCR Preprocessing)
    
    /// Optimized pipeline: capture optimization + OCR preprocessing in one pass
    /// This is more efficient than calling both functions separately
    func optimizeForOCR(_ cgImage: CGImage) -> CGImage? {
        let inputImage = CIImage(cgImage: cgImage)
        var outputImage = inputImage
        
        // Step 1: Downsample if needed (for large retina screenshots)
        // This is the MAIN optimization - reduces memory and OCR processing time
        let maxDimension: CGFloat = 3840
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        let needsDownsampling = width > maxDimension || height > maxDimension
        
        if needsDownsampling {
            let scale = min(maxDimension / width, maxDimension / height)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            outputImage = outputImage.transformed(by: transform)
        }
        
        // Step 2 & 3: Apply filters ONLY if Metal is available AND image is large
        // For small images, CPU-GPU transfer overhead > computation benefit
        let shouldUseFilters = isAvailable && (width * height) > (2560 * 1440)
        
        if shouldUseFilters {
            guard let ciContext = ciContext else {
                return cgImage
            }
            
            // Sharpen for text clarity
            if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
                sharpenFilter.setValue(outputImage, forKey: kCIInputImageKey)
                sharpenFilter.setValue(0.5, forKey: kCIInputSharpnessKey)
                if let result = sharpenFilter.outputImage {
                    outputImage = result
                }
            }
            
            // Enhance contrast
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(outputImage, forKey: kCIInputImageKey)
                contrastFilter.setValue(1.15, forKey: kCIInputContrastKey)
                contrastFilter.setValue(1.0, forKey: kCIInputSaturationKey)
                contrastFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
                if let result = contrastFilter.outputImage {
                    outputImage = result
                }
            }
            
            // Render using Metal
            let extent = outputImage.extent
            return ciContext.createCGImage(outputImage, from: extent)
        } else {
            // For small images or no Metal, use CPU rendering
            if needsDownsampling {
                let context = CIContext(options: [.useSoftwareRenderer: true])
                let extent = outputImage.extent
                return context.createCGImage(outputImage, from: extent)
            } else {
                // No processing needed
                return cgImage
            }
        }
    }
}
