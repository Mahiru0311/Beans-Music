import SwiftUI
import UIKit

// Folia preferences use the same CoGlass component and original liquid preference keys.
struct FoliaSettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @AppStorage(FoliaPreferences.modeKey) private var modeRaw = FoliaVisualizerMode.still.rawValue
    @AppStorage(FoliaPreferences.fontScaleKey) private var fontScale = 1.0
    // 翻译已删：歌词数据里翻译本就是空的（translation: nil），
    // 显示翻译/翻译字号/翻译颜色三行是永远不起作用的死开关。
    @AppStorage(FoliaPreferences.daylightKey) private var daylight = false
    @AppStorage(FoliaPreferences.showTextKey) private var showText = true
    @AppStorage(FoliaPreferences.primaryColorKey) private var primaryHex = "#FFFFFF"
    @AppStorage(FoliaPreferences.accentColorKey) private var accentHex = "#A5B4FC"
    @AppStorage(FoliaPreferences.classicIntensityKey) private var intensityRaw = "normal"
    @AppStorage(FoliaPreferences.classicRotationKey) private var rotationEnabled = true
    @AppStorage(FoliaPreferences.classicBreathingKey) private var breathing = 1.0
    @AppStorage(FoliaPreferences.classicLegacyLayoutKey) private var legacy = false
    @AppStorage(FoliaPreferences.classicSpacingKey) private var wordSpacing = 0.7
    @AppStorage("co.disableLiquidGlass") private var disableLiquidGlass = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                card("Folia 歌词舞台") {
                    Picker("歌词模式", selection: $modeRaw) {
                        ForEach(FoliaVisualizerMode.ordered) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    Toggle("显示歌词", isOn: $showText)
                    Toggle("日间舞台", isOn: $daylight)
                    Text("静止模式显示上一句、当前句和下一句，句间停顿保持当前位置。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                card("字体与配色") {
                    Text("歌词字号 \(fontScale, specifier: "%.2f")×")
                    Slider(value: $fontScale, in: 0.5...2, step: 0.05)
                    ColorPicker("歌词颜色", selection: colorBinding($primaryHex), supportsOpacity: false)
                    ColorPicker("逐词高亮颜色", selection: colorBinding($accentHex), supportsOpacity: false)
                }
                if modeRaw == FoliaVisualizerMode.classic.rawValue {
                    card("流光调节") {
                        Picker("动效强度", selection: $intensityRaw) {
                            ForEach(FoliaClassicIntensity.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                        Toggle("词语旋转", isOn: $rotationEnabled)
                        Text("呼吸浮动 \(breathing, specifier: "%.2f")×")
                        Slider(value: $breathing, in: 0...2, step: 0.05)
                        Toggle("旧版词语布局", isOn: $legacy)
                        Text("词语间距 \(wordSpacing, specifier: "%.2f")×")
                        Slider(value: $wordSpacing, in: 0...2, step: 0.05).disabled(legacy)
                        Button("恢复流光默认参数") {
                            intensityRaw = "normal"; rotationEnabled = true
                            breathing = 1; legacy = false; wordSpacing = 0.7
                        }
                    }
                }
                card("Co 液态外观") {
                    Toggle("关闭液态模式", isOn: $disableLiquidGlass)
                    Picker("全局 UI 风格", selection: Binding(get: { theme.uiStyle }, set: { theme.setUIStyle($0) })) {
                        ForEach(CoUIStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    ColorPicker("液态容器颜色", selection: Binding(
                        get: { theme.liquidGlassColor ?? Color(red: 0.86, green: 0.91, blue: 1) },
                        set: { theme.setLiquidGlassColor("#" + UIColor($0).hexString) }
                    ), supportsOpacity: false)
                    Button("恢复清透颜色") { theme.clearLiquidGlassColor() }
                    Text("与 Co 设置共用。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(16).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background { GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil) }
        .navigationTitle("Folia")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content()
        }
        .padding(16).background { CoGlass(shape: RoundedRectangle(cornerRadius: 18)) }
    }

    private func colorBinding(_ hex: Binding<String>) -> Binding<Color> {
        Binding(get: { Color(hex: hex.wrappedValue) ?? .white },
                set: { hex.wrappedValue = "#" + UIColor($0).hexString })
    }
}
