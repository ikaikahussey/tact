import SwiftUI
import UIKit

/// The Tact brand type: Helvetica Neue, at the sizes of the system text
/// styles, scaling with Dynamic Type.
enum TactType {
    static let regular = "HelveticaNeue"
    static let bold = "HelveticaNeue-Bold"

    /// Point size at the default Dynamic Type setting, and whether the style
    /// is set in bold.
    static func metrics(for style: Font.TextStyle) -> (size: CGFloat, isBold: Bool) {
        switch style {
        case .largeTitle:  return (34, true)
        case .title:       return (28, true)
        case .title2:      return (22, true)
        case .title3:      return (20, true)
        case .headline:    return (17, true)
        case .body:        return (17, false)
        case .callout:     return (16, false)
        case .subheadline: return (15, false)
        case .footnote:    return (13, false)
        case .caption:     return (12, false)
        case .caption2:    return (11, false)
        @unknown default:  return (17, false)
        }
    }

    /// Sets navigation bar titles in Helvetica Neue Bold, scaled with Dynamic Type.
    static func applyNavigationBarAppearance() {
        let appearance = UINavigationBar.appearance()
        if let title = UIFont(name: bold, size: metrics(for: .headline).size) {
            appearance.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title)]
        }
        if let largeTitle = UIFont(name: bold, size: metrics(for: .largeTitle).size) {
            appearance.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: largeTitle)]
        }
    }
}

extension Font {
    /// Helvetica Neue at the size of `style`, scaling with Dynamic Type.
    static func tact(_ style: Font.TextStyle) -> Font {
        let metrics = TactType.metrics(for: style)
        return .custom(metrics.isBold ? TactType.bold : TactType.regular, size: metrics.size, relativeTo: style)
    }

    /// Helvetica Neue Bold at a fixed size, for labels sized to fit a shape.
    static func tactBold(size: CGFloat) -> Font {
        .custom(TactType.bold, fixedSize: size)
    }
}
