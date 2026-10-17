import AVFoundation
import ImageIO
import UIKit

/// Converts static artwork and GIF frames to a silent local movie with the exact
/// requested aspect ratio. Pixel-buffer writing is also observed in the supplied IPA.
enum BeansLockScreenImageMovie {
    static func write(source: URL, target: URL, size: CGSize) async throws {
        guard let images = CGImageSourceCreateWithURL(source as CFURL, nil) else { throw CustomSongCoverError.invalidMedia }
        let count = min(CGImageSourceGetCount(images), 120)
        guard count > 0 else { throw CustomSongCoverError.invalidMedia }
        let temporary = target.deletingLastPathComponent().appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let writer = try AVAssetWriter(outputURL: temporary, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height)])
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height),
                    kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw CustomSongCoverError.invalidMedia }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CustomSongCoverError.invalidMedia }
        writer.startSession(atSourceTime: .zero)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "beans.lock-screen-image-movie", qos: .utility)
            var frame = 0
            var elapsed = 0.0
            var finished = false
            func fail(_ error: Error) {
                guard !finished else { return }; finished = true
                input.markAsFinished(); writer.cancelWriting(); continuation.resume(throwing: error)
            }
            input.requestMediaDataWhenReady(on: queue) {
                guard !finished else { return }
                while input.isReadyForMoreMediaData && frame < count {
                    guard let image = CGImageSourceCreateImageAtIndex(images, frame, nil),
                          let buffer = pixelBuffer(image: image, size: size, attributes: attributes),
                          adaptor.append(buffer, withPresentationTime: CMTime(seconds: elapsed, preferredTimescale: 600)) else {
                        fail(writer.error ?? CustomSongCoverError.invalidMedia); return
                    }
                    let properties = CGImageSourceCopyPropertiesAtIndex(images, frame, nil) as? [CFString: Any]
                    let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                    let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                        ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.1
                    elapsed += count == 1 ? 2 : min(max(delay, 1.0 / 30), 1)
                    frame += 1
                    if elapsed >= 29 { frame = count; elapsed = 29 }
                }
                if frame == count {
                    finished = true
                    writer.endSession(atSourceTime: CMTime(seconds: elapsed, preferredTimescale: 600))
                    input.markAsFinished()
                    writer.finishWriting {
                        if writer.status == .completed { continuation.resume() }
                        else { continuation.resume(throwing: writer.error ?? CustomSongCoverError.invalidMedia) }
                    }
                }
            }
        }
        try FileManager.default.moveItem(at: temporary, to: target)
    }

    private static func pixelBuffer(image: CGImage, size: CGSize, attributes: [String: Any]) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB,
                                  attributes as CFDictionary, &buffer) == kCVReturnSuccess, let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        let scale = max(size.width / CGFloat(image.width), size.height / CGFloat(image.height))
        let width = CGFloat(image.width) * scale, height = CGFloat(image.height) * scale
        context.draw(image, in: CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height))
        return buffer
    }
}
