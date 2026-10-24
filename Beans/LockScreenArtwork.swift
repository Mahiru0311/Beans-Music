import AVFoundation
import CryptoKit
import MediaPlayer
import UIKit

/// Supplies the local animated cover that iOS can use on the Lock Screen.
/// Beans 2.0.3 exposes a lease and a video directory; this implementation preserves
/// a private copy of each movie and uses a stable artwork identifier.
final class CoLockScreenArtwork {
    static let enabledKey = "co.lockScreenImmersiveArtwork.enabled"

    private var entries: [String: [String: MPMediaItemAnimatedArtwork]] = [:]
    private var pending = Set<String>()
    var onReady: (() -> Void)?

    func artwork(sourceURL: URL) -> [String: MPMediaItemAnimatedArtwork] { [:] }

    private static func crop(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let scale = max(size.width / max(1, image.size.width), size.height / max(1, image.size.height))
            let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
    }
}
