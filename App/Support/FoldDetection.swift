import SwiftUI

extension GeometryProxy {
    /// The left and right edges of a vertical fold crossing this view, as on
    /// the iPhone Duo's inner display held open in landscape. Nil on a
    /// single screen, or when the fold runs across rather than down.
    /// Inactive folds count: the device lying flat still has two screens.
    var verticalFold: ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        for region in reservedRegions(kind: .division, options: [.includeInactive]) {
            let frame = region.frame
            guard frame.height > frame.width, frame.minX > 0, frame.maxX < size.width else { continue }
            return frame.minX...max(frame.minX, frame.maxX)
        }
        return nil
    }
}
