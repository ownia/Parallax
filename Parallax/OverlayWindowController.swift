import AppKit

class OverlayWindowController {
    private var overlayWindow: NSWindow?
    private var currentScreen: NSScreen?
    var isVisible: Bool { overlayWindow?.isVisible ?? false }
    
    /// Font cache to avoid recreating fonts of the same size
    private var fontCache: [CGFloat: NSFont] = [:]
    private let fontCacheLock = NSLock()
    
    func show(with blocks: [TextBlock], on screen: NSScreen? = nil) {
        let profilerToken = PerformanceProfiler.shared.begin(.overlayRender)
        profilerToken?.addMetadata(key: "blockCount", value: blocks.count)
        
        hide()
        
        let targetScreen = screen ?? NSScreen.main
        guard let targetScreen = targetScreen else { return }
        
        let screenFrame = targetScreen.frame
        let scaleFactor = targetScreen.backingScaleFactor
        
        // Pre-calculate all display blocks with rendering info
        let displayBlocks = blocks.map { block -> DisplayBlock in
            createDisplayBlock(from: block, scaleFactor: scaleFactor, screenHeight: screenFrame.height)
        }
        
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false
        
        let contentView = OverlayContentView(frame: window.contentView!.bounds, displayBlocks: displayBlocks)
        window.contentView = contentView
        
        window.orderFrontRegardless()
        overlayWindow = window
        currentScreen = targetScreen
        
        PerformanceProfiler.shared.end(profilerToken)
    }
    
    /// Update translations without re-capturing screen
    func updateTranslations(_ blocks: [TextBlock]) {
        guard let window = overlayWindow, let screen = currentScreen else { return }
        
        let screenFrame = screen.frame
        let scaleFactor = screen.backingScaleFactor
        
        // Pre-calculate all display blocks with rendering info
        let displayBlocks = blocks.map { block -> DisplayBlock in
            createDisplayBlock(from: block, scaleFactor: scaleFactor, screenHeight: screenFrame.height)
        }
        
        // Update content view
        let contentView = OverlayContentView(frame: window.contentView!.bounds, displayBlocks: displayBlocks)
        window.contentView = contentView
    }
    
    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        currentScreen = nil
    }
    
    /// Get or create a font of the specified size (with caching)
    private func getFont(size: CGFloat) -> NSFont {
        // Round font size to reduce cache entries
        let roundedSize = round(size)
        
        fontCacheLock.lock()
        defer { fontCacheLock.unlock() }
        
        if let cachedFont = fontCache[roundedSize] {
            return cachedFont
        }
        
        let font = NSFont(name: "PingFang SC", size: roundedSize) ?? NSFont.systemFont(ofSize: roundedSize)
        fontCache[roundedSize] = font
        return font
    }
    
    private func createDisplayBlock(from block: TextBlock, scaleFactor: CGFloat, screenHeight: CGFloat) -> DisplayBlock {
        // Convert pixel coordinates to screen coordinates
        let x = block.rect.origin.x / scaleFactor
        let y = screenHeight - (block.rect.origin.y / scaleFactor) - (block.rect.height / scaleFactor)
        let originalWidth = block.rect.width / scaleFactor
        let originalHeight = block.rect.height / scaleFactor
        
        // Calculate font size based on original height
        let fontSize = min(max(originalHeight * 0.75, 11), 26)
        let font = getFont(size: fontSize)
        
        // Set text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        // Calculate actual text size needed
        let maxWidth = max(originalWidth, 200)
        let textSize = block.text.boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        ).size
        
        // Expand rect to fit text
        let padding: CGFloat = 6
        let finalWidth = max(originalWidth, textSize.width + padding * 2)
        let finalHeight = max(originalHeight, textSize.height + padding)
        
        // Adjust Y position if height increased (expand downward)
        let finalY = y - (finalHeight - originalHeight)
        
        let rect = NSRect(x: x, y: finalY, width: finalWidth, height: finalHeight)
        
        return DisplayBlock(rect: rect, text: block.text, attributes: attributes, padding: padding)
    }
    
    /// Clear font cache
    func clearFontCache() {
        fontCacheLock.lock()
        fontCache.removeAll()
        fontCacheLock.unlock()
    }
}

/// Pre-calculated display block with all rendering info
struct DisplayBlock {
    let rect: NSRect
    let text: String
    let attributes: [NSAttributedString.Key: Any]
    let padding: CGFloat
}

class OverlayContentView: NSView {
    private let displayBlocks: [DisplayBlock]
    
    /// Pre-created background color to avoid recreating in draw()
    private let backgroundColor = NSColor(white: 0, alpha: 0.88)
    
    init(frame: NSRect, displayBlocks: [DisplayBlock]) {
        self.displayBlocks = displayBlocks
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        for block in displayBlocks {
            // Only draw blocks that intersect with dirtyRect for better performance
            guard block.rect.intersects(dirtyRect) else { continue }
            
            // Draw semi-transparent black background
            backgroundColor.setFill()
            let backgroundPath = NSBezierPath(roundedRect: block.rect, xRadius: 4, yRadius: 4)
            backgroundPath.fill()
            
            // Draw text with padding
            let textRect = block.rect.insetBy(dx: block.padding, dy: block.padding / 2)
            block.text.draw(in: textRect, withAttributes: block.attributes)
        }
    }
}
