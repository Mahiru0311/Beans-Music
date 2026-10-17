import SwiftUI

// Wrap measured native text before applying word transforms. Geometry never depends on time.
struct FoliaClassicLayout: Layout {
    let geometries: [FoliaClassicWordGeometry]
    let fontSize: Double
    let intensity: FoliaClassicIntensity
    let spacing: Double
    let legacy: Bool
    let interlude: Bool
    let justification: FoliaClassicJustification
    let alignment: Int

    struct Item { let index: Int; let size: CGSize; let margin: CGFloat }
    struct Row { var items: [Item] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = sizes[index]
            let margin: CGFloat
            if geometries.indices.contains(index) {
                margin = CGFloat(FoliaClassicMotion.margin(
                    width: Double(size.width), nextWidth: index + 1 < sizes.count ? Double(sizes[index + 1].width) : 0,
                    geometry: geometries[index], next: index + 1 < geometries.count ? geometries[index + 1] : nil,
                    fontSize: fontSize, intensity: intensity, spacing: spacing, legacy: legacy, interlude: interlude))
            } else { margin = 0 }
            if !row.items.isEmpty, row.width + size.width > width {
                rows.append(row); row = Row()
            }
            row.items.append(Item(index: index, size: size, margin: margin))
            row.width += size.width + margin
            row.height = max(row.height, size.height)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(1, proposal.width ?? 1152)
        let rows = rows(width: width, subviews: subviews)
        return CGSize(width: width, height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * 28)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            // CSS margin-right also contributes after the final item.
            let free = max(0, bounds.width - row.width)
            var x = bounds.minX
            var extra: CGFloat = 0
            switch justification {
            case .start: break
            case .center: x += free / 2
            case .end: x += free
            case .around: extra = free / CGFloat(row.items.count); x += extra / 2
            case .between: extra = row.items.count > 1 ? free / CGFloat(row.items.count - 1) : 0
            }
            for item in row.items {
                let align = geometries.indices.contains(item.index) ? geometries[item.index].alignment ?? alignment : alignment
                let vertical = align == 0 ? 0 : align == 2 ? row.height - item.size.height : (row.height - item.size.height) / 2
                subviews[item.index].place(at: CGPoint(x: x, y: y + vertical), anchor: .topLeading,
                                          proposal: ProposedViewSize(item.size))
                x += item.size.width + item.margin + extra
            }
            y += row.height + 28
        }
    }
}
