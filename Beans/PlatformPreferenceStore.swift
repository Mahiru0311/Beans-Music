import SwiftUI
import Combine

/// 用户选择需要显示的平台。只控制入口可见性，不删除平台能力。
final class PlatformPreferenceStore: ObservableObject {
    static let shared = PlatformPreferenceStore()

    private static let key = "beans.enabledPlatforms.v1"
    private static let orderKey = "beans.platformOrder.v1"

    @Published private(set) var selectedRaw: Set<String>
    @Published var orderedRaw: [String]

    /// 仅隐藏页面顶部的平台切换控件，不影响平台启用状态或后台加载能力。
    static let hidePickerKey = "beans.hidePlatformPicker"

    var changes: AnyPublisher<Set<String>, Never> { $selectedRaw.eraseToAnyPublisher() }

    private init() {
        // 酷狗专版：只剩酷狗一个平台，旧的多平台偏好一律归一。
        selectedRaw = [SearchProvider.kugou.rawValue]
        orderedRaw = [SearchProvider.kugou.rawValue]
    }

    var enabledSearchProviders: [SearchProvider] { [.kugou] }

    var enabledLibraryProviders: [LibraryProvider] { [.kugou] }

    var summaryText: String {
        enabledSearchProviders.map(\.rawValue).joined(separator: " / ")
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

    func ensureVisible(_ provider: SearchProvider) -> SearchProvider { .kugou }

    func ensureVisible(_ provider: LibraryProvider) -> LibraryProvider { .kugou }

    func resetToDefault() {
        selectedRaw = [SearchProvider.kugou.rawValue]
        resetOrder()
        save()
    }

    func applyRemoteEnabledProviders(_ providers: [SearchProvider]) {
        // 酷狗专版忽略远程平台列表。
        _ = providers
    }

    func resetOrder() {
        orderedRaw = [SearchProvider.kugou.rawValue]
        saveOrder()
        objectWillChange.send()
    }

    var orderedSearchProviders: [SearchProvider] {
        orderedRaw.compactMap(SearchProvider.init(rawValue:))
    }

    func moveProviders(from offsets: IndexSet, to destination: Int) {
        orderedRaw.move(fromOffsets: offsets, toOffset: destination)
        normalizeOrder()
        saveOrder()
        objectWillChange.send()
    }

    private func normalize() {
        selectedRaw = [SearchProvider.kugou.rawValue]
    }

    private func save() {
        UserDefaults.standard.set(Array(selectedRaw), forKey: Self.key)
    }

    private func normalizeOrder() {
        orderedRaw = [SearchProvider.kugou.rawValue]
    }

    private func saveOrder() {
        UserDefaults.standard.set(orderedRaw, forKey: Self.orderKey)
    }

    private static func migrateRawValue(_ raw: String) -> String {
        SearchProvider.kugou.rawValue
    }
}

extension LibraryProvider {
    var searchProvider: SearchProvider { .kugou }
}

struct PlatformPreferencePicker: View {
    @ObservedObject private var store = PlatformPreferenceStore.shared

    var body: some View {
        VStack(spacing: 10) {
            ForEach(store.orderedSearchProviders) { provider in
                Button {
                    BeansHaptics.select()
                    store.set(provider, enabled: !store.isEnabled(provider))
                } label: {
                    HStack(spacing: 12) {
                        if let imageName = provider.brandImageName {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: provider.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(provider.rawValue))
                                .font(BeansFont.appFont(14, .semibold))
                                .foregroundStyle(Color.beansLabel)
                                Text(LocalizedStringKey(store.isEnabled(provider) ? "已显示" : "已隐藏"))
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        }
                        Spacer()
                        Image(systemName: store.isEnabled(provider) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(store.isEnabled(provider) ? Color.beansAmber : Color.beansComment)
                    }
                    .padding(12)
                    .background {
                        ZStack {
                            BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous), forceLiquid: true)
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(store.isEnabled(provider) ? Color.beansAmber.opacity(0.14) : Color.clear)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(store.isEnabled(provider) ? Color.beansAmber.opacity(0.35) : Color.beansComment.opacity(0.12), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
