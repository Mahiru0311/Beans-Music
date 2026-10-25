import AVFoundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum CustomCoverMediaKind: Equatable {
    case image
    case gif
    case video
}

enum CustomCoverMedia {
    static func kind(for url: URL) -> CustomCoverMediaKind {
        if url.pathExtension.lowercased() == "gif" {
            return .gif
        }
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .movie) {
            return .video
        }
        return .image
    }


    static func previewImage(at url: URL) -> UIImage? {
        switch kind(for: url) {
        case .image, .gif:
            return UIImage(contentsOfFile: url.path)
        case .video:
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            return try? UIImage(cgImage: generator.copyCGImage(at: .zero, actualTime: nil))
        }
    }

    /// System media surfaces expect square artwork. Normalize video frames before handing them
    /// to Now Playing so portrait source dimensions do not leak into the compact artwork layout.
    static func systemArtworkImage(at url: URL) -> UIImage? {
        guard let source = previewImage(at: url) else { return nil }
        let normalized = CoProfileHeaderWallpaper.normalizedImage(source)
        let sourceSize = normalized.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return normalized }

        let side = min(max(sourceSize.width, sourceSize.height), 1600)
        let targetSize = CGSize(width: side, height: side)
        let scale = max(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let origin = CGPoint(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            normalized.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }


    static func animatedGIF(at url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(contentsOfFile: url.path) }

        let frameLimit = min(count, 120)
        var images: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<frameLimit {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue
                ?? 0.08
            duration += max(delay, 0.04)
        }
        guard !images.isEmpty else { return nil }
        return UIImage.animatedImage(with: images, duration: max(duration, 0.08 * Double(images.count)))
    }
}

final class CustomSongCoverStore: ObservableObject {
    static let shared = CustomSongCoverStore()

    @Published private(set) var revision = 0

    private struct Entry: Codable, Equatable {
        let filename: String
        let sourceCoverURL: String?
        let videoAudioEnabled: Bool?
    }

    private let legacyDefaultsKey = "co.player.customSongCovers.v1"
    private let defaultsKey = "co.player.customSongCovers.v2"
    private let directory: URL
    private var entries: [String: Entry]

    private init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CoCustomSongCovers", isDirectory: true)
        entries = Self.loadEntries(defaultsKey: defaultsKey, legacyDefaultsKey: legacyDefaultsKey)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        pruneMissingFiles()
    }

    func url(for song: Song?) -> URL? {
        guard let song, var entry = entries[song.identityKey] else { return nil }
        let url = directory.appendingPathComponent(entry.filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if entry.sourceCoverURL == nil, let sourceCoverURL = song.coverURL?.absoluteString {
            entry = Entry(
                filename: entry.filename,
                sourceCoverURL: sourceCoverURL,
                videoAudioEnabled: entry.videoAudioEnabled
            )
            entries[song.identityKey] = entry
            persist()
        }
        return url
    }

    func resolvedURL(for sourceURL: URL?) -> URL? {
        guard let sourceURL else { return nil }
        let sourceKey = Self.sourceCoverKey(for: sourceURL)
        guard let entry = entries.values.first(where: { entry in
            guard let storedURL = entry.sourceCoverURL else { return false }
            return storedURL == sourceURL.absoluteString
                || Self.sourceCoverKey(for: storedURL) == sourceKey
        }) else {
            return sourceURL
        }
        let customURL = directory.appendingPathComponent(entry.filename)
        return FileManager.default.fileExists(atPath: customURL.path) ? customURL : sourceURL
    }

    func isStoredCover(_ url: URL?) -> Bool {
        guard let url, url.isFileURL else { return false }
        return entries.values.contains { $0.filename == url.lastPathComponent }
    }

    func hasCover(for song: Song?) -> Bool {
        url(for: song) != nil
    }

    func isVideoCover(for song: Song?) -> Bool {
        guard let url = url(for: song) else { return false }
        return CustomCoverMedia.kind(for: url) == .video
    }

    func videoAudioEnabled(for url: URL?) -> Bool {
        guard let url else { return false }
        return entries.values.first(where: { $0.filename == url.lastPathComponent })?.videoAudioEnabled ?? false
    }

    func setVideoAudioEnabled(_ enabled: Bool, for song: Song?) {
        guard let song, let entry = entries[song.identityKey] else { return }
        entries[song.identityKey] = Entry(
            filename: entry.filename,
            sourceCoverURL: entry.sourceCoverURL,
            videoAudioEnabled: enabled
        )
        persist()
        revision &+= 1
        NotificationCenter.default.post(name: .coCustomSongCoverDidChange, object: song.identityKey)
    }

    func removeCover(for song: Song?) {
        guard let song, let entry = entries.removeValue(forKey: song.identityKey) else { return }
        let url = directory.appendingPathComponent(entry.filename)
        try? FileManager.default.removeItem(at: url)
        CoImageFileCache.remove(url.path)
        persist()
        revision &+= 1
        NotificationCenter.default.post(name: .coCustomSongCoverDidChange, object: song.identityKey)
    }

    private static func loadEntries(defaultsKey: String, legacyDefaultsKey: String) -> [String: Entry] {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            return decoded
        }
        let legacy = UserDefaults.standard.dictionary(forKey: legacyDefaultsKey) as? [String: String] ?? [:]
        return legacy.mapValues { Entry(filename: $0, sourceCoverURL: nil, videoAudioEnabled: false) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func pruneMissingFiles() {
        let retained = entries.filter { _, entry in
            FileManager.default.fileExists(atPath: directory.appendingPathComponent(entry.filename).path)
        }
        guard retained != entries else { return }
        entries = retained
        persist()
    }

    private static func sourceCoverKey(for url: URL) -> String {
        sourceCoverKey(for: url.absoluteString)
    }

    private static func sourceCoverKey(for rawURL: String) -> String {
        guard var components = URLComponents(string: rawURL),
              let host = components.host?.lowercased() else {
            return rawURL
        }
        components.query = nil
        components.fragment = nil
        var path = components.percentEncodedPath
        // QQ's cover host encodes requested dimensions in the path, while the album id remains stable.
        path = path.replacingOccurrences(
            of: "R[0-9]+x[0-9]+M",
            with: "RM",
            options: .regularExpression
        )
        return host + path
    }

}

extension Notification.Name {
    static let coCustomSongCoverDidChange = Notification.Name("co.customSongCoverDidChange")
}

struct CustomCoverMediaView: UIViewRepresentable {
    let url: URL
    let isMuted: Bool

    func makeUIView(context: Context) -> CustomCoverMediaUIView {
        let view = CustomCoverMediaUIView()
        view.configure(url: url, isMuted: isMuted)
        return view
    }

    func updateUIView(_ uiView: CustomCoverMediaUIView, context: Context) {
        uiView.configure(url: url, isMuted: isMuted)
    }
}

final class CustomCoverMediaUIView: UIView {
    private let imageView = UIImageView()
    private let videoHost = UIView()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var videoLayer: AVPlayerLayer?
    private var currentURL: URL?
    private var currentKind: CustomCoverMediaKind?
    private var activeObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        videoHost.clipsToBounds = true
        addSubview(imageView)
        addSubview(videoHost)
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resumePlaybackIfNeeded()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            player?.pause()
        } else {
            resumePlaybackIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.transform = .identity
        videoHost.transform = .identity
        imageView.frame = bounds
        videoHost.frame = bounds
        videoLayer?.frame = videoHost.bounds
    }

    func configure(url: URL, isMuted: Bool) {
        let kind = CustomCoverMedia.kind(for: url)
        guard currentURL != url || currentKind != kind || (kind == .video && player == nil) else {
            player?.isMuted = isMuted
            resumePlaybackIfNeeded()
            return
        }
        currentURL = url
        currentKind = kind
        imageView.stopAnimating()
        imageView.image = nil
        player?.pause()
        player = nil
        looper = nil
        videoLayer = nil
        videoHost.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        switch kind {
        case .image:
            imageView.isHidden = false
            videoHost.isHidden = true
            imageView.image = UIImage(contentsOfFile: url.path)
        case .gif:
            imageView.isHidden = false
            videoHost.isHidden = true
            imageView.image = CustomCoverMedia.animatedGIF(at: url)
            imageView.startAnimating()
        case .video:
            imageView.isHidden = true
            videoHost.isHidden = false
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer()
            player.isMuted = isMuted
            player.actionAtItemEnd = .none
            player.automaticallyWaitsToMinimizeStalling = false
            self.player = player
            looper = AVPlayerLooper(player: player, templateItem: item)
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            videoHost.layer.addSublayer(layer)
            videoLayer = layer
            player.playImmediately(atRate: 1.0)
        }
        setNeedsLayout()
    }

    private func resumePlaybackIfNeeded() {
        guard currentKind == .video, window != nil else { return }
        player?.playImmediately(atRate: 1.0)
    }
}
