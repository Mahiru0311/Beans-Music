import SwiftUI
import Combine

/// 用户选择需要显示的平台。只控制入口可见性，不删除平台能力。
final class PlatformPreferenceStore: ObservableObject {
    static let shared = PlatformPreferenceStore()

    private static let orderKey = "beans.platformOrder.v1"

    @Published private(set) var selectedRaw: Set<String>
    @Published var orderedRaw: [String]


    private init() {
        // 酷狗专版：只剩酷狗一个平台，旧的多平台偏好一律归一。
        selectedRaw = [SearchProvider.kugou.rawValue]
        orderedRaw = [SearchProvider.kugou.rawValue]
    }

    func isEnabled(_ provider: SearchProvider) -> Bool {
        selectedRaw.contains(provider.rawValue)
    }

    func isEnabled(_ provider: LibraryProvider) -> Bool {
        isEnabled(provider.searchProvider)
    }

    func set(_ provider: SearchProvider, enabled: Bool) {
        // 酷狗专版不做平台开关，调用保持空操作以免旧调用点断链。
        _ = provider; _ = enabled
    }

    func resetOrder() {
        orderedRaw = [SearchProvider.kugou.rawValue]
        saveOrder()
        objectWillChange.send()
    }

    func moveProviders(from offsets: IndexSet, to destination: Int) {
        orderedRaw.move(fromOffsets: offsets, toOffset: destination)
        normalizeOrder()
        saveOrder()
        objectWillChange.send()
    }

    private func normalizeOrder() {
        orderedRaw = [SearchProvider.kugou.rawValue]
    }

    private func saveOrder() {
        UserDefaults.standard.set(orderedRaw, forKey: Self.orderKey)
    }

}

extension LibraryProvider {
    var searchProvider: SearchProvider { .kugou }
}

