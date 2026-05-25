import SwiftUI
import AppKit

extension Color {
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >>  8) & 0xFF) / 255,
            blue:  Double( value        & 0xFF) / 255
        )
    }

    var rgbComponents: (Double, Double, Double) {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        let r = nsColor.redComponent
        let g = nsColor.greenComponent
        let b = nsColor.blueComponent
        return (r, g, b)
    }

    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        let r = Int(clamp(nsColor.redComponent) * 255)
        let g = Int(clamp(nsColor.greenComponent) * 255)
        let b = Int(clamp(nsColor.blueComponent) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func clamp(_ val: CGFloat) -> CGFloat {
        max(0, min(1, val))
    }
}
