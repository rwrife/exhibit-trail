#if DEBUG
import UIKit

/// Debug-only UI-test seam. The system document picker cannot be driven by
/// XCUITest, so `-ExhibitUITestFixture` exposes a button that feeds a locally
/// generated PNG through the same import → validate → persist → render
/// pipeline as a user-picked file. Compiled out of Release builds; no network
/// or extra file access.
enum MapFixture {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-ExhibitUITestFixture") }

    static func pngData() -> Data {
        let size = CGSize(width: 600, height: 400)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.fill(CGRect(x: 40, y: 40, width: 200, height: 140))
            context.fill(CGRect(x: 320, y: 220, width: 240, height: 140))
        }
        return image.pngData() ?? Data()
    }
}
#endif
