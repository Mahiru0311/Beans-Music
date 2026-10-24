import CoreImage
import SwiftUI
import UIKit

/// Rebuilt from the 2.0.3 reflected header fields. Exact timing and layout require device comparison.
struct CoImmersiveDetailHeader: View {
    static let enabledKey = "co.immersiveDetail.enabled"
    let coverURL: URL?
    let title: String
    var subtitle = ""
    var metadata = ""
    var descriptionText: String?
    var portrait = false
    var onSubtitle: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var palette = Color.coAmber

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { proxy in
                let pull = max(0, proxy.frame(in: .global).minY - 100)
                CoverImage(url: coverURL, size: min(proxy.size.width, 240), cornerRadius: portrait ? 120 : 22)
                    .scaleEffect(reduceMotion ? 1 : 1 + min(pull / 700, 0.16))
                    .frame(maxWidth: .infinity)
                    .shadow(color: palette.opacity(0.32), radius: 24, y: 12)
            }.frame(height: 240)
            Text(title).font(CoFont.appFont(28, .bold)).multilineTextAlignment(.center)
                .accessibilityIdentifier("co.immersive.title")
            if !subtitle.isEmpty {
                Button { onSubtitle?() } label: {
                    Text(subtitle).font(CoFont.appFont(15, .medium)).foregroundStyle(palette)
                }.buttonStyle(.plain).disabled(onSubtitle == nil)
                    .accessibilityIdentifier("co.immersive.subtitle")
            }
            if !metadata.isEmpty {
                Text(metadata).font(CoFont.appFont(12)).foregroundStyle(Color.coComment)
                    .accessibilityIdentifier("co.immersive.metadata")
            }
            if let descriptionText, !descriptionText.isEmpty {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
                } label: {
                    VStack(spacing: 6) {
                        Text(descriptionText).lineLimit(expanded ? nil : 3).multilineTextAlignment(.leading)
                        Text(expanded ? "收起简介" : "展开简介").font(.caption.weight(.semibold))
                    }.foregroundStyle(Color.coComment)
                }.buttonStyle(.plain).accessibilityIdentifier("co.immersive.description-more")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [palette.opacity(0.25), palette.opacity(0.02)], startPoint: .top, endPoint: .bottom)
        }
        .accessibilityIdentifier("co.immersive.header")
        .task(id: coverURL) { await loadPalette() }
    }

    private func loadPalette() async {
        guard let coverURL else { return }
        let image: UIImage?
        if coverURL.isFileURL { image = CustomCoverMedia.previewImage(at: coverURL) }
        else if let result = try? await URLSession.shared.data(from: coverURL), !Task.isCancelled { image = UIImage(data: result.0) }
        else { image = nil }
        guard let image, let input = CIImage(image: image),
              let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: input.extent)]),
              let output = filter.outputImage else { return }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(output, toBitmap: &pixel, rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        guard !Task.isCancelled else { return }
        let color = Color(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { palette = color }
    }
}
