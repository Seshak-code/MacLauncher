import SwiftUI

@Observable
final class TileFrameRegistry {
    var frames: [FocusPosition: CGRect] = [:]

    func nearestPosition(to point: CGPoint) -> FocusPosition? {
        guard !frames.isEmpty else { return nil }
        
        return frames.min(by: {
            let distA = distance($0.value.center, point)
            let distB = distance($1.value.center, point)
            return distA < distB
        })?.key
    }
    
    func distance(toPosition position: FocusPosition, from point: CGPoint) -> CGFloat? {
        guard let rect = frames[position] else { return nil }
        return distance(rect.center, point)
    }

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
