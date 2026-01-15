import Foundation

struct TextBlock {
    let rect: CGRect
    let text: String
    
    init(rect: CGRect, text: String) {
        self.rect = rect
        self.text = text
    }
}
