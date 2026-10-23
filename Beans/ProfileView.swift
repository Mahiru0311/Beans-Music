import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

/// 自动下载新版 IPA 的结果
enum DownloadOutcome {
    case success(fileName: String)
    case failure(message: String)
}

struct ProfileView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @AppStorage("beans.homeHeaderHideSort") private var homeHeaderHideSort = false
    @AppStorage("beans.pauseHomeRendering") private var homeRenderingPaused = false


    /// 统一账号登录面板（网易云 + QQ 音乐整合）
    @State private var showAccountHub = false
    /// 设置页（外观 + 歌词翻译等）
    @State private var showSettings = false
    @State private var showSectionSort = false
    @State private var myPlaylists: [Playlist] = []
    @State private var myPlaylistsLoaded = false
    @State private var myPlaylistsLoading = false
    /// 我的界面板块顺序（账号 / 关于，可自定义）
    @State private var profileOrder = SectionOrderStore.load(SectionOrderStore.profileKey, defaults: SectionOrderStore.profileDefaults)
    /// 手动检查更新
    @State private var checkingUpdate = false
    /// 自动下载新版 IPA
    @State private var didRefreshProfileAccount = false
    /// VIP 图标选择：点昵称旁徽标弹出（wy.dwkc.cn 面板结构）；"auto" 为自动（Co 自绘）。
    @AppStorage("beans.vipIconItemId") private var vipIconItemId = "auto"
    @State private var showVIPIconPicker = false
    @State private var showStatusEditor = false
    @State private var showHideConfirm = false
    @State private var hideConfirmPlaylist: Playlist?
    @State private var myStatusText = ""
    @State private var statusDraft = ""
    @State private var vipIconImage: UIImage?
    @State private var vipIconLoadFailed = false
    /// 用户页背景（1.8.5）：默认 auto，不再是纯黑；见 profileHeaderBackground。
    @AppStorage("beans.profileBackground") private var profileBackgroundRaw = "auto"
    @AppStorage("beans.profileBackgroundCustomHex") private var profileBackgroundCustomHex = ""
    /// 我的页隐藏歌单（1.8.5）：按酷狗账号区分存，见 CoHiddenPlaylists。
    @State private var hiddenPlaylistEntries: [(id: Int, name: String)] = []
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @AppStorage("beans.language") private var languageRaw = AppLanguage.chinese.rawValue

    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var isEnglish: Bool { languageRaw == AppLanguage.english.rawValue }

    private var displayPlatformSummary: String {
        if !isEnglish { return platformPrefs.summaryText }
        return platformPrefs.enabledSearchProviders.map { provider in
            switch provider {
            case .netease: return "NetEase Cloud Music"
            case .qq: return "QQ Music"
            case .kugou: return "Kugou Music"
            }
        }.joined(separator: " / ")
    }

    /// 登录状态的合并提示（展示各平台真实昵称）
    private var accountStatusLine: String {
        var parts: [String] = []
        if platformPrefs.isEnabled(SearchProvider.netease), auth.isLoggedIn {
            if let nick = auth.user?.nickname, !nick.isEmpty {
                parts.append("网易云音乐 \(nick)")
            } else {
                parts.append("网易云音乐 UID \(auth.user?.uid ?? 0)")
            }
        }
        if platformPrefs.isEnabled(SearchProvider.qq), false {
                parts.append("".isEmpty ? (isEnglish ? "QQ Music Logged In" : "QQ 已登录") : "")
        }
        if platformPrefs.isEnabled(SearchProvider.kugou), kugouAuth.isLoggedIn {
                parts.append(kugouAuth.nickname.isEmpty ? (isEnglish ? "Kugou Music Logged In" : "酷狗已登录") : kugouAuth.nickname)
        }
        if parts.isEmpty {
            return isEnglish ? "Sign in to sync \(displayPlatformSummary) playlists" : "登录后可同步 \(platformPrefs.summaryText) 歌单"
        }
        return parts.joined(separator: " · ")
    }



    /// “我的”页顶部（wy.dwkc.cn 格式）：无大标题；左三横菜单、右设置齿轮；
    /// 黑色标题区 + 白色主卡大圆角压边。左菜单仍开板块排序（Co 在“我的”页唯一的菜单入口）。
    private var myTopBar: some View {
        HStack(alignment: .center) {
            if !homeHeaderHideSort {
                GlassIconButton(systemName: "line.3.horizontal", forceLiquid: true) {
                    BeansHaptics.tap()
                    showSectionSort = true
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            GlassIconButton(systemName: "gearshape.fill", forceLiquid: true) {
                BeansHaptics.tap()
                homeRenderingPaused = true
                showSettings = true
            }
        }
    }

    /// 居中头像区（wy 格式）：上方小字、居中圆形头像（点头像进账号/登录）、
    /// 下方昵称 + 黑金 VIP 动态徽标并排。昵称/头像优先酷狗登录态，酷狗未登录时回落旧账号态。
    private var myCenteredHeader: some View {
        VStack(spacing: 12) {
            Button {
                BeansHaptics.tap()
                statusDraft = myStatusText
                showStatusEditor = true
            } label: {
                Text(myStatusText.isEmpty ? "+ 添加状态" : "修改状态")
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(profileHeaderSecondary)
            }
            .buttonStyle(.plain)
            Button {
                BeansHaptics.tap()
                showAccountHub = true
            } label: {
                AsyncImage(url: kugouAuth.avatarURL ?? auth.user?.avatarURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(profileHeaderSecondary)
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .background(profileHeaderForeground.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(profileHeaderForeground.opacity(0.35), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            // 1.8.7：昵称+VIP 行居中、限宽（长条 VIP 图不再把昵称挤出屏幕）；
            // 昵称优先截断，VIP 图固定小尺寸。
            HStack(spacing: 6) {
                Text(myDisplayNickname)
                    .font(BeansFont.appFont(20, .bold))
                    .foregroundStyle(profileHeaderForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                // 点徽标弹出系统弹窗切换；未登录时点徽标先进账号/登录。
                Button {
                    BeansHaptics.tap()
                    if kugouAuth.isLoggedIn { showVIPIconPicker = true } else { showAccountHub = true }
                } label: { myVIPBadge }
                .buttonStyle(.plain)
                .accessibilityLabel("切换 VIP 图标")
            }
            .frame(maxWidth: 320)
            // 1.8.7：只有真的写了状态才显示状态行，空状态不再留一个孤立的铅笔斜杠；
            // 账号行与昵称完全相同时也不重复显示（截图里“明天见”出现两次的根因之一）。
            if !myStatusText.isEmpty {
                Button {
                    BeansHaptics.tap()
                    statusDraft = myStatusText
                    showStatusEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Text(myStatusText)
                            .font(BeansFont.appFont(13))
                            .foregroundStyle(profileHeaderForeground)
                            .lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(profileHeaderSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            if accountStatusLine != myDisplayNickname {
                Text(accountStatusLine)
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(profileHeaderSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var myDisplayNickname: String {
        if kugouAuth.isLoggedIn, !kugouAuth.nickname.isEmpty { return kugouAuth.nickname }
        if let nick = auth.user?.nickname, !nick.isEmpty { return nick }
        if kugouAuth.isLoggedIn { return "酷狗音乐已登录" }
        return "免登录 · 点击登录"
    }

    // MARK: - 1.8.5 VIP 图标：点徽标弹出切换，按需下载当前一款、只缓存一款
    private var selectedVIPIconItem: CoVIPIconItem? {
        vipIconItemId == "auto" ? nil : CoVIPIconCatalog.item(id: vipIconItemId)
    }
    /// 徽标本体：远程款有缓存图时显示该图（含动图播放），否则回落 Co 自绘；动效款无 VIP 时绝不显示动图。
    private var myVIPBadge: some View {
        Group {
            if let item = selectedVIPIconItem, !item.isSelfDrawn {
                if let img = vipIconImage, !(item.isAnimated && !kugouAuth.hasMembership) {
                    // 1.8.8：按原图比例显示（只定高 26pt、宽按比例算），不裁剪、不压扁；
                    // 1.8.7 的 84×20 硬框 + clipped() 是唱片圆被裁成扁长条的根因。
                    CoVIPRemoteImage(image: img)
                } else {
                    CoVIPAutoBadge(isVIP: kugouAuth.hasMembership, isLoggedIn: kugouAuth.isLoggedIn)
                }
            } else if let item = selectedVIPIconItem {
                CoVIPSelfDrawnBadge(itemId: item.id, isVIP: kugouAuth.hasMembership)
            } else {
                CoVIPAutoBadge(isVIP: kugouAuth.hasMembership, isLoggedIn: kugouAuth.isLoggedIn)
            }
        }
    }
    private func loadVIPIcon(allowDownload: Bool) {
        guard let item = selectedVIPIconItem, let url = item.url else {
            // 自动或自绘款：不下载、不留缓存，旧缓存立即清掉（选新删旧）。
            CoVIPIconCatalog.deleteCachedIcon()
            vipIconImage = nil
            vipIconLoadFailed = false
            return
        }
        if item.isAnimated && !kugouAuth.hasMembership {
            // 无 VIP 时动效款不生效：不下载、不显示动图，回落灰静态。
            vipIconImage = nil
            vipIconLoadFailed = false
            return
        }
        let cachedId = UserDefaults.standard.string(forKey: CoVIPIconCatalog.cachedItemIdKey) ?? ""
        if cachedId == item.id, let img = CoVIPIconCatalog.cachedImage() {
            vipIconImage = img
            vipIconLoadFailed = false
            return
        }
        guard allowDownload else { vipIconImage = nil; return }
        Task {
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty,
                      CoVIPIconCatalog.isDecodable(data), let img = CoAnimatedImageDecoder.animatedImage(from: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                let dir = CoVIPIconCatalog.cacheFileURL().deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try data.write(to: CoVIPIconCatalog.cacheFileURL(), options: .atomic)
                UserDefaults.standard.set(item.id, forKey: CoVIPIconCatalog.cachedItemIdKey)
                await MainActor.run { vipIconImage = img; vipIconLoadFailed = false }
            } catch {
                await MainActor.run { vipIconImage = nil; vipIconLoadFailed = true }
            }
        }
    }
    private func selectVIPIcon(_ item: CoVIPIconItem?) {
        // 选新删旧：先删旧缓存文件，再记新选择、再下载新款；失败时回落自绘（见 loadVIPIcon）。
        CoVIPIconCatalog.deleteCachedIcon()
        vipIconImage = nil
        vipIconLoadFailed = false
        vipIconItemId = item?.id ?? "auto"
        BeansHaptics.select()
        // 下载是异步的，失败时系统弹窗的 message 会显示回落提示，不在此处同步弹 toast。
        loadVIPIcon(allowDownload: true)
    }

    // MARK: - 1.8.5 用户页背景：默认 auto（浅灰适配，不黑、不与白卡同色）
    private var profileHeaderBackground: Color {
        switch profileBackgroundRaw {
        case "accentTint":
            // 主题色 14% + 浅灰 86% 的不透明混合色（不透底、不与白卡同色）。
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor.beansAmber.getRed(&r, green: &g, blue: &b, alpha: &a)
            var gr: CGFloat = 0, gg: CGFloat = 0, gb: CGFloat = 0, ga: CGFloat = 0
            UIColor.systemGray6.getRed(&gr, green: &gg, blue: &gb, alpha: &ga)
            return Color(red: r * 0.14 + gr * 0.86, green: g * 0.14 + gg * 0.86, blue: b * 0.14 + gb * 0.86)
        case "lightGray":
            return Color(UIColor.systemGray5)
        case "custom":
            if let c = Color(hex: profileBackgroundCustomHex) { return c }
            return Color(UIColor.systemGray6)
        default: // auto：浅色取浅灰、深色取深灰（均非纯黑、均与 systemBackground 白卡有区分）
            return Color(UIColor.systemGray6)
        }
    }
    private var profileHeaderForeground: Color {
        // 自定义深色背景时用白字，其余（auto/主题浅 tint/浅灰）用系统标签色（浅色黑字、深色白字）。
        if profileBackgroundRaw == "custom", let ui = UIColor(hex: profileBackgroundCustomHex) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            if 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.45 { return .white }
        }
        return Color.beansLabel
    }
    private var profileHeaderSecondary: Color { profileHeaderForeground.opacity(0.65) }

    // MARK: - 1.8.5 我的页隐藏歌单（只藏显示，不删歌单；按酷狗账号区分存）
    private var hiddenPlaylistIds: Set<Int> { Set(hiddenPlaylistEntries.map(\.id)) }
    private var visiblePlaylists: [Playlist] { myPlaylists.filter { !hiddenPlaylistIds.contains($0.id) } }
    private func loadHiddenPlaylists() {
        hiddenPlaylistEntries = CoHiddenPlaylists.load(userId: kugouAuth.userId)
    }
    private func hidePlaylist(_ playlist: Playlist) {
        var entries = hiddenPlaylistEntries
        if !entries.contains(where: { $0.id == playlist.id }) {
            entries.append((id: playlist.id, name: playlist.name))
        }
        hiddenPlaylistEntries = entries
        CoHiddenPlaylists.save(userId: kugouAuth.userId, entries: entries)
        BeansHaptics.select()
        // 1.8.8：隐藏了就隐藏了，只给一句确认，不再引导去设置恢复。
        ToastCenter.shared.show("已隐藏")
    }

    /// VIP 图标选择面板（wy.dwkc.cn 面板结构：VIP / SVIP / 长条形三档，VIP 内分普通/动效/已过期/特殊）。
    /// 网格里只放文字款式（不预下载全部款式图），当前选中的一款放大显示在顶部（已缓存的图或自绘）；
    /// 点选即生效、只保留当前一款，旧缓存已在 selectVIPIcon 里先删掉。
    /// 1.8.6 VIP 精简：只用他网站 VIP 档的核心款（普通/动效/已过期/特殊各 1 款，共 4 款），
    /// 不再铺 SVIP/长条形自绘款与 v0-v7 全量网格；展开用系统 DisclosureGroup（系统展开框），
    /// 选款仍按需下载、选新删旧只留一款、CDN 失效回落 Co 自绘（逻辑见 selectVIPIcon/loadVIPIcon）。
    /// 白色主卡（wy 格式）：顶部大圆角压住黑色标题区，内含统计行与歌单。
    /// 统计行只用 Co 真实数据，不编造关注/粉丝/等级/小时数。
    private var myWhiteCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            myStatsRowPlain
            myPlaylistsSection
            // 1.8.8：我的页不再展示版本信息（页脚已删），版本信息只在设置/关于页。
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
        .background {
            // 主目标部署版本为 iOS 15，UnevenRoundedRectangle（iOS 16+）不可用；
            // 用全圆角矩形：顶部大圆角压边效果不变，底部圆角在卡片收尾处同样自然。
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(UIColor.systemBackground))
        }
        .offset(y: -24)
    }

    /// 统计行（白卡内无底色版）：我喜欢 / 歌单 / 历史 / 常听，全部取本地真实数据。
    private var myStatsRowPlain: some View {
        HStack(spacing: 0) {
            myStatCell(value: "\(FavoritesStore.shared.kugouFavoriteSongs.count)", label: "我喜欢")
            Divider().frame(height: 28)
            myStatCell(value: "\(visiblePlaylists.count)", label: "歌单")
            Divider().frame(height: 28)
            myStatCell(value: "\(player.history.count)", label: "历史")
            Divider().frame(height: 28)
            myStatCell(value: "\(player.topPlayed.count)", label: "常听")
        }
        .padding(.vertical, 4)
    }

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
        ZStack(alignment: .top) {
            // 页面背景：同步开启时显示壁纸/背景色，否则默认氛围渐变
            GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            // 实例级 UITabBar 清透风格（固定全透明，无需调节）
            TabBarAppearanceConfigurator()
            ScrollView {
                VStack(spacing: 0) {
                    // 用户页标题区（1.8.5 默认不再是纯黑，见 profileHeaderBackground）：顶部栏 + 居中头像区。
                    VStack(spacing: 14) {
                        myTopBar
                            .padding(.horizontal, 16)
                        if profileOrder.contains("账号") {
                            myCenteredHeader
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity)
                    .background(profileHeaderBackground)
                    // 白色主卡：顶部大圆角压住黑色标题区，内含统计行、快捷入口、歌单、常听排行。
                    myWhiteCard
                }
                .padding(.bottom, 190)
                .frame(maxWidth: .infinity)
            }
            .beansScrollIndicatorsHidden()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task {
            guard !didRefreshProfileAccount else { return }
            didRefreshProfileAccount = true
            await auth.refreshAccount()
        }
        .task(id: kugouAuth.userId) {
            guard kugouAuth.isLoggedIn, !myPlaylistsLoaded else { return }
            myPlaylistsLoading = true
            if let list = try? await KugouMusicAPI.shared.userPlaylists() {
                myPlaylists = list
            }
            myPlaylistsLoaded = true
            myPlaylistsLoading = false
        }
        .task(id: kugouAuth.userId) { loadHiddenPlaylists() }
        .task(id: vipIconItemId) { loadVIPIcon(allowDownload: true) }
        .background {
            HighRefreshConfigurator()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        // 1.8.7：VIP 选择改成真正的系统弹窗（confirmationDialog，底部系统弹窗样式），
        // 不再是自定义居中圆角大面板 / 全页 List 选择页。
        .confirmationDialog("VIP 图标", isPresented: $showVIPIconPicker, titleVisibility: .visible) {
            Button("自动（按 VIP 状态自动对应）\(vipIconItemId == "auto" ? " ✓" : "")") { selectVIPIcon(nil) }
            ForEach(CoVIPIconCatalog.vipCore) { item in
                let disabled = item.isAnimated && !kugouAuth.hasMembership
                Button("\(item.label)\(item.isAnimated ? " · 动图" : " · 静态")\(vipIconItemId == item.id ? " ✓" : "")") {
                    if !disabled { selectVIPIcon(item) }
                }
                .disabled(disabled)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(vipIconLoadFailed ? "当前款图标加载失败，已回落 Co 自绘徽标；可重选一款重试。" : "选款后只下载当前一款并缓存，换一款时旧缓存立即删除。动效款仅 VIP 可用。")
        }
        // 1.8.7：状态编辑改成系统 alert 文本框弹窗（iOS 16+ 文本框；iOS 15 上 alert 只有按钮，入口仍可用）。
        .alert("我的状态", isPresented: $showStatusEditor) {
            if #available(iOS 16.0, *) {
                TextField("写一句话状态", text: $statusDraft)
            }
            Button("保存") {
                let text = String(statusDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                myStatusText = text
                CoUserStatus.save(userId: kugouAuth.userId, text: text)
                BeansHaptics.select()
            }
            Button("清空状态", role: .destructive) {
                myStatusText = ""
                statusDraft = ""
                CoUserStatus.save(userId: kugouAuth.userId, text: "")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("在头像下方显示一句话状态，只存在本地，不同步到酷狗账号。")
        }
        // 1.8.7：歌单隐藏确认也用系统弹窗。
        .confirmationDialog("隐藏此歌单？", isPresented: $showHideConfirm, titleVisibility: .visible) {
            Button("隐藏此歌单", role: .destructive) {
                if let target = hideConfirmPlaylist { hidePlaylist(target) }
                hideConfirmPlaylist = nil
            }
            Button("取消", role: .cancel) { hideConfirmPlaylist = nil }
        } message: {
            Text("只在“我的”页隐藏，不删除酷狗里的歌单，可在设置里恢复。")
        }
        .task(id: kugouAuth.userId) { myStatusText = CoUserStatus.load(userId: kugouAuth.userId) }
        .sheet(isPresented: $showAccountHub) {
            AccountHubSheet()
                .environmentObject(auth)
                .environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(theme)
                .environmentObject(player)
                .ignoresSafeArea(.all)
        }
        .sheet(isPresented: $showSectionSort) {
            SectionOrderSheet(
                title: "我的板块排序",
                sections: SectionOrderStore.profileDefaults,
                order: $profileOrder,
                platformOrder: Binding(
                    get: { platformPrefs.orderedRaw },
                    set: { platformPrefs.orderedRaw = $0 }
                )
            )
                .onDisappear { SectionOrderStore.save(SectionOrderStore.profileKey, profileOrder) }
        }
        }
    }

    /// 壁纸格子：点击应用为当前背景；使用中的壁纸显示主题色边框+勾选；右上角删除
    private func wallpaperCell(path: String) -> some View {
        let isActive = path == theme.backgroundImagePath
        return ZStack(alignment: .topTrailing) {
            Button {
                BeansHaptics.tap()
                theme.applyWallpaper(at: path)
            } label: {
                Group {
                    if let img = BeansImageFileCache.image(at: path) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.beansGlassFill
                    }
                }
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.beansAmber)
                            .background { BeansSurface(shape: Circle()) }
                            .padding(5)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                BeansHaptics.medium()
                theme.deleteWallpaper(at: path)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.beansComment)
                    .frame(width: 28, height: 28)
                    .background { BeansSurface(shape: Circle()) }
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .padding(6)
            }
            .buttonStyle(.plain)
            .zIndex(2)
        }
    }

    /// 功能宫格：常用功能统一整合排版（统计行已由白卡内 myStatsRowPlain 承载，见上）。
    private func myStatCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(BeansFont.appFont(16, .bold))
                .foregroundStyle(Color.beansLabel)
                .lineLimit(1)
            Text(label)
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var myPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的歌单")
            if !kugouAuth.isLoggedIn {
                Button {
                    BeansHaptics.tap()
                    showAccountHub = true
                } label: {
                    Text("登录酷狗后，这里会显示你的歌单")
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansComment)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                }
                .buttonStyle(.plain)
            } else if myPlaylistsLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if visiblePlaylists.isEmpty {
                // 1.8.8：隐藏了就隐藏了，我的页不留任何去设置恢复的提示；
                // 恢复入口只在设置 → 外观与界面 → 隐藏的歌单里。
                Text("暂无歌单")
                    .font(BeansFont.appFont(13))
                    .foregroundStyle(Color.beansComment)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(visiblePlaylists.prefix(8))) { playlist in
                        // 1.8.6：点歌单进详情页（2.0.3 歌单页结构：封面/歌名/歌曲数/歌曲列表/播放全部），不再直接播放首歌。
                        NavigationLink {
                            PlaylistView(playlist: playlist)
                                .environmentObject(player)
                                .environmentObject(auth)
                                .environmentObject(theme)
                        } label: {
                            HStack(spacing: 10) {
                                CoverImage(url: playlist.coverURL, size: 44, cornerRadius: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(14, .semibold))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Text(playlist.trackCount > 0 ? "\(playlist.trackCount) 首" : "歌单")
                                        .font(BeansFont.appFont(12))
                                        .foregroundStyle(Color.beansComment)
                                        .lineLimit(1)
                                }
                                Spacer()
                                // 1.8.7：看得见的隐藏入口（行内 ··· 钮，点开系统弹窗确认；
                                // 长按菜单仍保留）。内层按钮优先于 NavigationLink 响应点按。
                                Button {
                                    BeansHaptics.tap()
                                    hideConfirmPlaylist = playlist
                                    showHideConfirm = true
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.beansComment)
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment.opacity(0.7))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                        }
                        .buttonStyle(.plain)
                        // 长按隐藏仍保留：只藏“我的”页显示，不删歌单、不影响酷狗账号内歌单。
                        .contextMenu {
                            Button("隐藏此歌单", role: .destructive) { hidePlaylist(playlist) }
                        }
                    }
                }
            }
        }
    }

    /// 常听排行：按本地播放次数排序（MD3 用户中心的听歌排行同款，数据已在本地，不调新接口）。

}

// MARK: - 统一账号登录面板（网易云 + QQ 音乐整合）

struct AccountHubSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @AppStorage("beans.language") private var languageRaw = AppLanguage.chinese.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var showKugouLogin = false
    @State private var confirmKugouLogout = false

    private var isEnglish: Bool { languageRaw == AppLanguage.english.rawValue }
    private var displayPlatformSummary: String {
        if !isEnglish { return platformPrefs.summaryText }
        return platformPrefs.enabledSearchProviders.map { provider in
            switch provider {
            case .netease: return "NetEase Cloud Music"
            case .qq: return "QQ Music"
            case .kugou: return "Kugou Music"
            }
        }.joined(separator: " / ")
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "账号")
                        if platformPrefs.isEnabled(SearchProvider.kugou) { kugouCard }
                        Text(isEnglish ? "Sign in to \(displayPlatformSummary) to sync playlists and improve playback availability" : "\(platformPrefs.summaryText) 登录后可同步歌单并提升可播成功率")
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                            .padding(.horizontal, 4)
                    }
                    .padding(16)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("账号登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showKugouLogin) {
            KugouLoginSheet()
                .environmentObject(theme)
        }
        .confirmationDialog("退出酷狗音乐？", isPresented: $confirmKugouLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                kugouAuth.logout()
                WebLoginDataCleaner.clearKugou()
                ToastCenter.shared.show("已退出酷狗音乐")
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var kugouCard: some View {
        Button {
            BeansHaptics.tap()
            if kugouAuth.isLoggedIn { confirmKugouLogout = true } else { showKugouLogin = true }
        } label: {
            HStack(spacing: 14) {
                Image("BrandKugou")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color(red: 0.08, green: 0.43, blue: 1.0).opacity(0.22), radius: 10, y: 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text("酷狗音乐")
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    HStack(spacing: 6) {
                        Group {
                            if kugouAuth.isLoggedIn {
                                Text(kugouAuth.nickname.isEmpty ? NSLocalizedString("已登录", comment: "") : kugouAuth.nickname)
                            } else {
                                Text(LocalizedStringKey("未登录 · App 扫码同步歌单"))
                            }
                        }
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        if kugouAuth.isLoggedIn, let badge = kugouAuth.vipBadge {
                            VIPBadgeView(text: badge)
                        }
                    }
                }
                Spacer()
                Text(kugouAuth.isLoggedIn ? "退出" : "登录")
                    .font(BeansFont.appFont(13, .medium))
                    .foregroundStyle(kugouAuth.isLoggedIn ? Color.red : Color.beansAmber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background { BeansSurface(shape: Capsule()) }
            }
            .padding(14)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
    }

}

// MARK: - 设置页（外观 + 歌词翻译，从「我的」右上角齿轮进入）

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("beans.themeMode") private var themeModeRaw = BeansThemeMode.system.rawValue
    @AppStorage("beans.profileBackground") private var profileBackgroundRaw = "auto"
    @AppStorage("beans.profileBackgroundCustomHex") private var profileBackgroundCustomHex = ""
    @AppStorage("beans.language") private var languageRaw = AppLanguage.chinese.rawValue
    @AppStorage("beans.homeWallpaperBlur") private var homeWallpaperBlur = 0.0
    /// 底栏是否显示文字（关闭后只显示图标）
    @AppStorage("beans.tabLabelsVisible") private var tabLabelsVisible = true
    @AppStorage("beans.legacyTabCornerRadius") private var legacyTabCornerRadius = 32.0
    @AppStorage("beans.legacyTabWidth") private var legacyTabWidth = 356.0
    @AppStorage("beans.legacyTabOffsetX") private var legacyTabOffsetX = 0.0
    @AppStorage("beans.legacyTabOffsetY") private var legacyTabOffsetY = 0.0
    /// 第三方音源播放会员歌成功时提醒，默认开启
    @AppStorage("beans.showThirdPartyVIPNotice") private var showThirdPartyVIPNotice = true
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true
    /// 高刷新率请求，默认开启
    @AppStorage("beans.enableHighRefresh") private var enableHighRefresh = false  // Co：默认关闭高刷新（省电）
    @AppStorage("beans.audio.mixothers.v1") private var mixesWithOthers = false
    @AppStorage("beans.audioQuality") private var playbackAudioQualityRaw = BeansAudioQuality.hires.rawValue
    @AppStorage(BeansHaptics.enabledKey) private var hapticsEnabled = true
    @AppStorage("beans.playback.autoResumeLast") private var autoResumeLastPlayback = false
    @AppStorage("beans.labelColorHex") private var labelColorHex = ""
    @AppStorage("beans.homeGreetingText") private var homeGreetingText = ""
    @AppStorage("beans.homeGreetingSize") private var homeGreetingSize = 30.0
    @AppStorage("beans.homeGreetingHeight") private var homeGreetingHeight = 0.0
    @AppStorage("beans.homeGreetingColorHex") private var homeGreetingColorHex = ""
    @AppStorage("beans.homeGreetingLine1Size") private var homeGreetingLine1Size = 0.0
    @AppStorage("beans.homeGreetingLine2Size") private var homeGreetingLine2Size = 0.0
    @AppStorage("beans.homeGreetingLine3Size") private var homeGreetingLine3Size = 0.0
    @AppStorage("beans.homeGreetingLine1ColorHex") private var homeGreetingLine1ColorHex = ""
    @AppStorage("beans.homeGreetingLine2ColorHex") private var homeGreetingLine2ColorHex = ""
    @AppStorage("beans.homeGreetingLine3ColorHex") private var homeGreetingLine3ColorHex = ""
    @AppStorage("beans.homeGreetingLine1OffsetY") private var homeGreetingLine1OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine2OffsetY") private var homeGreetingLine2OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine3OffsetY") private var homeGreetingLine3OffsetY = 0.0
    @AppStorage("beans.homeGreetingLine1GradientStartHex") private var homeGreetingLine1GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine2GradientStartHex") private var homeGreetingLine2GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine3GradientStartHex") private var homeGreetingLine3GradientStartHex = ""
    @AppStorage("beans.homeGreetingLine1GradientEndHex") private var homeGreetingLine1GradientEndHex = ""
    @AppStorage("beans.homeGreetingLine2GradientEndHex") private var homeGreetingLine2GradientEndHex = ""
    @AppStorage("beans.homeGreetingLine3GradientEndHex") private var homeGreetingLine3GradientEndHex = ""
    @AppStorage("beans.homeGreetingGlowEnabled") private var homeGreetingGlowEnabled = false
    @AppStorage("beans.homeGreetingGlowIntensity") private var homeGreetingGlowIntensity = 0.45
    @AppStorage("beans.homeGreetingUnderline") private var homeGreetingUnderline = false
    @AppStorage("beans.homeGreetingGradient") private var homeGreetingGradient = false
    @AppStorage("beans.homeGreetingGradientStartHex") private var homeGreetingGradientStartHex = ""
    @AppStorage("beans.homeGreetingGradientEndHex") private var homeGreetingGradientEndHex = ""
    @AppStorage("beans.homeGreetingFont") private var homeGreetingFontName = ""
    @AppStorage("beans.pauseHomeRendering") private var homeRenderingPaused = false
    @AppStorage("beans.homeHideUsername") private var homeHideUsername = false
    @AppStorage("beans.homeHeaderHideSort") private var homeHeaderHideSort = false
    @AppStorage("beans.homeHeaderHideRefresh") private var homeHeaderHideRefresh = true
    @AppStorage(PlatformPreferenceStore.hidePickerKey) private var hidePlatformPicker = false
    /// 导航栏显示开关（与 RootView 同一组 UserDefaults 键，参照 2.0.3 BeansTabVisibility，Co 五页版）。
    @AppStorage("beans.tab.discover.visible") private var navDiscoverVisible = true
    @AppStorage("beans.tab.library.visible") private var navLibraryVisible = true
    @AppStorage("beans.tab.profile.visible") private var navProfileVisible = true
    @AppStorage("beans.tab.search.visible") private var navSearchVisible = true
    @AppStorage("beans.tab.featured.visible") private var navFeaturedVisible = true
    // 1.8.7：底栏图标样式（与 RootView 共用同一存储键，切换后底栏立即变）。
    @AppStorage("beans.tabIconStyle") private var tabIconStyleRaw = CoTabIconStyle.appleMusic.rawValue

    private var navVisibleCount: Int {
        [navDiscoverVisible, navFeaturedVisible, navLibraryVisible, navProfileVisible, navSearchVisible].filter { $0 }.count
    }

    /// 1.8.7：外观与界面子项收起/展开——打开设置页时全部默认收起，用户点开才展开。
    @State private var appearanceExpanded = false
    @State private var themeModeExpanded = false
    @State private var interfaceFontWallpaperExpanded = false
    @State private var navVisibilityExpanded = false
    @State private var audioQualityExpanded = false
    @State private var staticWallpaperExpanded = false
    @State private var dynamicWallpaperExpanded = false
    @State private var highRefreshExpanded = false
    /// 1.8.4 恢复项（默认收起的高级项）：问候语、隐藏开关、低系统底栏。
    @State private var greetingExpanded = false
    @State private var hideExpanded = false
    @State private var legacyTabExpanded = false
    @State private var profileBackgroundExpanded = false
    @State private var hiddenPlaylistsExpanded = false
    @State private var hiddenAccounts: [(userId: String, entries: [(id: Int, name: String)])] = []
    /// 沉浸详情界面：关闭后播放器详情页不再用封面毛玻璃背景，只用静态渐变（省电）。
    @AppStorage("beans.immersiveDetail") private var immersiveDetail = true
    /// 锁屏沉浸封面：关闭后锁屏/灵动岛不再取封面，只显示文字信息。
    @AppStorage("beans.lockScreenCover") private var lockScreenCover = true

    private func navBinding(for tab: String) -> Binding<Bool> {
        Binding(
            get: {
                switch tab {
                case "discover": return navDiscoverVisible
                case "featured": return navFeaturedVisible
                case "library": return navLibraryVisible
                case "profile": return navProfileVisible
                default: return navSearchVisible
                }
            },
            set: { newValue in
                if !newValue && navVisibleCount <= 1 {
                    ToastCenter.shared.show("至少保留一页导航栏")
                    return
                }
                switch tab {
                case "discover": navDiscoverVisible = newValue
                case "featured": navFeaturedVisible = newValue
                case "library": navLibraryVisible = newValue
                case "profile": navProfileVisible = newValue
                default: navSearchVisible = newValue
                }
            }
        )
    }
    @ObservedObject private var equalizer = BeansEqualizer.shared
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared

    @State private var playbackExpanded = false
    @State private var showWallpaperPicker = false
    @State private var wallpaperAppearanceTarget: BeansWallpaperAppearance = .light
    @State private var showFontImporter = false
    @State private var showGreetingFontImporter = false
    /// 更新日志
    @State private var showChangelog = false
    @State private var backupDoc: BackupDocument?
    @State private var showExportBackup = false
    @State private var showRestorePicker = false
    @State private var pendingRestore: [String: Any]?
    @State private var showRestoreConfirm = false
    @State private var showSourceManager = false
    @State private var showEqualizer = false
    @State private var backupExpanded = false
    @State private var backupIncludeAccounts = false
    @State private var backupIncludeWallpapers = false
    @State private var backupMessage: String?
    /// 日志
    @State private var showLogViewer = false
    @State private var settingsSearchText = ""

    /// 设置搜索（参照 2.0.3 与 MD3 的设置搜索，关键词为空时全部显示）。
    private func settingsMatches(_ terms: String...) -> Bool {
        let query = settingsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return terms.joined(separator: " ").localizedCaseInsensitiveContains(query)
    }

    /// 新组“外观与界面”的搜索可见性：界面 / 字体 / 静态壁纸 / 音质任一关键词命中即显示。
    private var showAccountSettings: Bool { settingsMatches("账号 登录 酷狗") }
    private var showAppearanceInterfaceSettings: Bool { settingsMatches("外观 界面 主题 强调色 壁纸 字体 音质 底栏 语言 沉浸 液态 高刷新 动态 背景色 问候语 隐藏 低系统 用户页背景 隐藏歌单 图标样式 精选") }
    private var showPlaybackSettings: Bool { settingsMatches("播放 音质 睡眠 定时 触感 混音") }
    private var showEqualizerSettings: Bool { settingsMatches("均衡器 音效") }
    private var showChangelogSettings: Bool { settingsMatches("更新 日志 版本") }
    private var showBackupSettings: Bool { settingsMatches("备份 恢复 导出 导入 缓存") }
    private var showLogSettings: Bool { settingsMatches("日志 诊断 崩溃") }
    private var hasSettingsSearchResults: Bool {
        showAccountSettings || showAppearanceInterfaceSettings || showPlaybackSettings || showEqualizerSettings
            || showChangelogSettings || showBackupSettings || showLogSettings
    }

    private func settingsGroupTitle(_ title: String) -> some View {
        Text(title)
            .font(BeansFont.appFont(13, .semibold))
            .foregroundStyle(Color.beansComment)
            .padding(.leading, 4)
    }

    private var themeMode: BeansThemeMode {
        BeansThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var customSourceCount: Int {
        0  // Co：第三方音源已删
    }

    private var playbackAudioQualitySelection: Binding<BeansAudioQuality> {
        Binding(
            get: { BeansAudioQuality(rawValue: playbackAudioQualityRaw) ?? .hires },
            set: { playbackAudioQualityRaw = $0.rawValue }
        )
    }

    private var homeGreetingLines: [String] {
        let custom = homeGreetingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if custom.isEmpty { return ["自动问候"] }
        return custom.components(separatedBy: .newlines)
    }

    private func greetingLineSizeBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: {
                switch index {
                case 0: return homeGreetingLine1Size > 0 ? homeGreetingLine1Size : homeGreetingSize
                case 1: return homeGreetingLine2Size > 0 ? homeGreetingLine2Size : homeGreetingSize
                default: return homeGreetingLine3Size > 0 ? homeGreetingLine3Size : homeGreetingSize
                }
            },
            set: { value in
                switch index {
                case 0: homeGreetingLine1Size = value
                case 1: homeGreetingLine2Size = value
                default: homeGreetingLine3Size = value
                }
            }
        )
    }

    private func greetingLineColorBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                let raw: String
                switch index {
                case 0: raw = homeGreetingLine1ColorHex
                case 1: raw = homeGreetingLine2ColorHex
                default: raw = homeGreetingLine3ColorHex
                }
                return Color(hex: raw) ?? (Color(hex: homeGreetingColorHex) ?? Color.beansLabel)
            },
            set: { color in
                let hex = color.hexString
                switch index {
                case 0: homeGreetingLine1ColorHex = hex
                case 1: homeGreetingLine2ColorHex = hex
                default: homeGreetingLine3ColorHex = hex
                }
            }
        )
    }

    private func greetingLineOffsetBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: {
                switch index {
                case 0: return homeGreetingLine1OffsetY
                case 1: return homeGreetingLine2OffsetY
                default: return homeGreetingLine3OffsetY
                }
            },
            set: { value in
                switch index {
                case 0: homeGreetingLine1OffsetY = value
                case 1: homeGreetingLine2OffsetY = value
                default: homeGreetingLine3OffsetY = value
                }
            }
        )
    }

    private func greetingLineGradientStartBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                let raw: String
                switch index {
                case 0: raw = homeGreetingLine1GradientStartHex
                case 1: raw = homeGreetingLine2GradientStartHex
                default: raw = homeGreetingLine3GradientStartHex
                }
                return Color(hex: raw) ?? (Color(hex: homeGreetingGradientStartHex) ?? Color.beansLabel)
            },
            set: { color in
                switch index {
                case 0: homeGreetingLine1GradientStartHex = color.hexString
                case 1: homeGreetingLine2GradientStartHex = color.hexString
                default: homeGreetingLine3GradientStartHex = color.hexString
                }
            }
        )
    }

    private func greetingLineGradientEndBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                let raw: String
                switch index {
                case 0: raw = homeGreetingLine1GradientEndHex
                case 1: raw = homeGreetingLine2GradientEndHex
                default: raw = homeGreetingLine3GradientEndHex
                }
                return Color(hex: raw) ?? (Color(hex: homeGreetingGradientEndHex) ?? Color.beansLabel)
            },
            set: { color in
                switch index {
                case 0: homeGreetingLine1GradientEndHex = color.hexString
                case 1: homeGreetingLine2GradientEndHex = color.hexString
                default: homeGreetingLine3GradientEndHex = color.hexString
                }
            }
        )
    }

    private func resetGreetingLineStyle(_ index: Int) {
        switch index {
        case 0:
            homeGreetingLine1Size = 0
            homeGreetingLine1ColorHex = ""
            homeGreetingLine1OffsetY = 0
            homeGreetingLine1GradientStartHex = ""
            homeGreetingLine1GradientEndHex = ""
        case 1:
            homeGreetingLine2Size = 0
            homeGreetingLine2ColorHex = ""
            homeGreetingLine2OffsetY = 0
            homeGreetingLine2GradientStartHex = ""
            homeGreetingLine2GradientEndHex = ""
        default:
            homeGreetingLine3Size = 0
            homeGreetingLine3ColorHex = ""
            homeGreetingLine3OffsetY = 0
            homeGreetingLine3GradientStartHex = ""
            homeGreetingLine3GradientEndHex = ""
        }
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.beansComment)
                            TextField("搜索设置", text: $settingsSearchText)
                                .font(BeansFont.appFont(14))
                                .foregroundStyle(Color.beansLabel)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                            if !settingsSearchText.isEmpty {
                                Button { settingsSearchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.beansComment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                        .onChange(of: settingsSearchText) { value in
                            // 1.8.7：默认收起只管“打开时”；用户主动搜设置项时把外观组展开，
                            // 否则搜到的项全藏在收起的组里，搜索等于没用。
                            if !value.isEmpty { appearanceExpanded = true }
                        }
                        if !settingsSearchText.isEmpty && !hasSettingsSearchResults {
                            Text("没有找到相关设置")
                                .font(BeansFont.appFont(14))
                                .foregroundStyle(Color.beansComment)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 12)
                        }
                        if showAccountSettings {
                            VStack(alignment: .leading, spacing: 12) {
                                settingsGroupTitle("账号")
                                HStack(spacing: 12) {
                                    Image(systemName: KugouMusicAuth.shared.isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.beansAmber)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(KugouMusicAuth.shared.isLoggedIn ? "酷狗已登录" : "酷狗未登录")
                                            .font(BeansFont.appFont(15))
                                            .foregroundStyle(Color.beansLabel)
                                        Text(KugouMusicAuth.shared.isLoggedIn ? "在“我的”页点头像可管理账号与 VIP。" : "在“我的”页点头像可扫码登录，登录后同步歌单与 VIP。")
                                            .font(BeansFont.appFont(11))
                                            .foregroundStyle(Color.beansComment)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
                            }
                        }
                        if showAppearanceInterfaceSettings {
                            // 1.8.6：外观与界面归一为一个系统 DisclosureGroup 直接可展开，内部分段列出全部项，不再是 12 张分开的玻璃子卡；开关一个不少。
                            DisclosureGroup(isExpanded: $appearanceExpanded) {
                                appearanceInterfaceSection
                            } label: {
                                HStack {
                                    Text("外观与界面")
                                        .font(BeansFont.appFont(15, .semibold))
                                        .foregroundStyle(Color.beansLabel)
                                    Spacer()
                                    Text(appearanceSummaryText)
                                        .font(BeansFont.appFont(12))
                                        .foregroundStyle(Color.beansComment)
                                    Image(systemName: appearanceExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.beansComment.opacity(0.6))
                                }
                            }
                        }
                        if showPlaybackSettings || showEqualizerSettings {
                            VStack(alignment: .leading, spacing: 12) {
                                settingsGroupTitle("播放与音效")
                                if showPlaybackSettings { playbackSection }
                                if showEqualizerSettings { equalizerSection }
                            }
                        }
                        if showBackupSettings || showLogSettings {
                            VStack(alignment: .leading, spacing: 12) {
                                settingsGroupTitle("数据与支持")
                                if showBackupSettings { backupSection }
                                if showLogSettings { logSection }
                            }
                        }
                        if showChangelogSettings {
                            VStack(alignment: .leading, spacing: 12) {
                                settingsGroupTitle("关于")
                                changelogSection
                                footerNote
                            }
                        } else {
                            footerNote
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(themeMode.colorScheme)
        .onAppear {
            wallpaperAppearanceTarget = colorScheme == .dark ? .dark : .light
        }
        .sheet(isPresented: $showWallpaperPicker) {
            WallpaperPhotoPicker { data in
                theme.addWallpaper(data, for: wallpaperAppearanceTarget.colorScheme)
                BeansHaptics.success()
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showFontImporter) {
            FontDocumentPicker { url in
                installFont(from: url)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showGreetingFontImporter) {
            FontDocumentPicker { url in
                installGreetingFont(from: url)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showChangelog) {
            ChangelogListView()
                .environmentObject(theme)
        }
        .fileExporter(
            isPresented: $showExportBackup,
            document: backupDoc,
            contentType: .json,
            defaultFilename: "Beans设置备份-\(Self.backupDateString())"
        ) { result in
            switch result {
            case .success:
                backupMessage = "配置备份已导出"
                ToastCenter.shared.show("配置备份已导出")
            case .failure(let error):
                backupMessage = "导出失败：\(error.localizedDescription)"
                ToastCenter.shared.show("导出失败")
            }
        }
        .sheet(isPresented: $showLogViewer) {
            LogViewerSheet(importedText: nil)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showSourceManager) {
            Text("第三方音源已删")
                .environmentObject(theme)
        }
        .sheet(isPresented: $showEqualizer) {
            EqualizerSettingsView()
                .environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showRestorePicker) {
            BackupDocumentPicker { url in
                handleBackupImport(url)
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("导入备份将覆盖当前部分设置，是否继续？", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("恢复", role: .destructive) {
                applyRestore(pendingRestore)
            }
            Button("取消", role: .cancel) {}
        }
        .onAppear {
            homeRenderingPaused = true
        }
        .onDisappear {
            homeRenderingPaused = false
        }
    }

    /// “外观与界面” curated 组（参照 2.0.3 设置页的界面/字体/壁纸/音质项，但只留日常项、按清晰度做）：
    /// 界面（主题模式、全局 UI 样式、底栏文字、强调色）、字体（全局、问候语专属，带预览）、
    /// 静态壁纸（上传、壁纸库、模糊度、同步、恢复默认；明确不做动态壁纸）、音质（酷狗官方 5 档简化版，按账号权益自动降级）。
    /// 1.8.4 恢复：1.8.3 合并时随旧区删掉的问候语逐行定制、隐藏开关、低系统底栏已恢复为本组内三个可收起子项（仍是唯一一个“外观与界面”组，不另立重复组）；
    /// 核心项（主题模式、语言、全局/问候语字体、壁纸、音质、底栏显示）全部保留在本组内，子项均可收起、收起时标题行显示当前值。
    /// 1.8.6 外观与界面归一后的标题行当前值：主题模式 + 导航栏已显示页数。
    private var appearanceSummaryText: String {
        let mode = BeansThemeMode(rawValue: themeModeRaw)?.title ?? "跟随系统"
        return "\(mode) · 导航 \(navVisibleCount)/5 页"
    }

    private var appearanceInterfaceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - 界面
            DisclosureGroup(isExpanded: $themeModeExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                Picker("主题模式", selection: $themeModeRaw) {
                    ForEach(BeansThemeMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.title)).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Picker("语言", selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.beansAmber)
                Toggle(isOn: $immersiveDetail) {
                    Text("沉浸详情界面")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                Toggle(isOn: $lockScreenCover) {
                    Text("锁屏沉浸封面")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                Toggle(isOn: Binding(
                    get: { theme.uiStyle == .nativeClean },
                    set: { theme.setUIStyle($0 ? .nativeClean : .liquid) }
                )) {
                    Text("关闭液态模式")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                Picker("全局 UI 样式", selection: Binding(
                    get: { theme.uiStyle },
                    set: { theme.setUIStyle($0) }
                )) {
                    ForEach(BeansUIStyle.allCases, id: \.self) { style in
                        Text(LocalizedStringKey(style.title)).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Toggle(isOn: $tabLabelsVisible) {
                    Text("底栏显示文字")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                HStack {
                    Text("强调色")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Picker("强调色", selection: Binding(
                        get: { theme.accent },
                        set: { theme.set($0) }
                    )) {
                        ForEach(BeansAccent.allCases) { accent in
                            Text(LocalizedStringKey(accent.rawValue)).tag(accent)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.beansAmber)
                }
                HStack {
                    Text("自定义强调色")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { theme.customAccent ?? Color.beansAmber },
                        set: { theme.setCustomAccent($0.hexString) }
                    ))
                    .labelsHidden()
                }
                HStack(spacing: 12) {
                    Button {
                        theme.clearCustomAccent()
                        BeansHaptics.select()
                    } label: {
                        Text("恢复预设")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(LocalizedStringKey(theme.customAccentHex == nil ? "当前：使用预设主题" : "当前：已自定义"))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
            }
            } label: {
                HStack {
                    Text("主题模式")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(BeansThemeMode(rawValue: themeModeRaw)?.title ?? "跟随系统")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: themeModeExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 字体
            DisclosureGroup(isExpanded: $interfaceFontWallpaperExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                Text("Co 音乐 · 字体预览 Aa")
                    .font(BeansFont.appFont(17, .semibold))
                    .foregroundStyle(Color.beansLabel)
                HStack {
                    Text("全局字体")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(FontManager.installedFontName ?? "系统默认")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                HStack(spacing: 12) {
                    Button { showFontImporter = true } label: {
                        Text("上传字体")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Button {
                        FontManager.clear()
                        BeansHaptics.select()
                        ToastCenter.shared.show("已恢复系统默认字体")
                    } label: {
                        Text("恢复默认字体")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                HStack {
                    Text("问候语专属字体")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(LocalizedStringKey(homeGreetingFontName.isEmpty ? "当前：跟随全局" : "当前：已设置"))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                HStack(spacing: 12) {
                    Button { showGreetingFontImporter = true } label: {
                        Text("选择字体")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Button {
                        homeGreetingFontName = ""
                        BeansHaptics.select()
                    } label: {
                        Text("清除专属字体")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            } label: {
                HStack {
                    Text("字体")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(FontManager.installedFontName ?? "系统默认")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: interfaceFontWallpaperExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 静态壁纸（只做静态，不做 2.0.3 的动态壁纸）
            DisclosureGroup(isExpanded: $staticWallpaperExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("当前")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(LocalizedStringKey(theme.customBackgroundImage(for: wallpaperAppearanceTarget.colorScheme) == nil ? "默认背景" : "已应用壁纸"))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Picker("背景模式", selection: $wallpaperAppearanceTarget) {
                    ForEach(BeansWallpaperAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("主页背景色")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { theme.customBackground(for: wallpaperAppearanceTarget.colorScheme) ?? Color.beansBackground },
                        set: { theme.setBackground($0.hexString, for: wallpaperAppearanceTarget.colorScheme) }
                    ))
                    .labelsHidden()
                }
                Button { showWallpaperPicker = true } label: {
                    HStack {
                        Text("上传壁纸")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.beansAmber)
                    }
                }
                .buttonStyle(.plain)
                if !theme.wallpaperPaths.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(theme.wallpaperPaths, id: \.self) { path in
                            wallpaperCell(path: path, appearance: wallpaperAppearanceTarget)
                        }
                    }
                } else {
                    Text("还没有壁纸，上传后会显示在这里")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                HStack {
                    Text("主页壁纸模糊度")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text("\(Int(homeWallpaperBlur))")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Slider(value: $homeWallpaperBlur, in: 0...30, step: 1)
                    .tint(Color.beansAmber)
                Toggle(isOn: Binding(
                    get: { theme.backgroundSyncAll },
                    set: { theme.setBackgroundSyncAll($0) }
                )) {
                    Text("同步到搜索 / 音乐库 / 我的")
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansLabel)
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                HStack(spacing: 12) {
                    Button {
                        theme.setBackground("")
                        BeansHaptics.select()
                    } label: {
                        Text("恢复默认背景")
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Text("仅静态壁纸，不做动态壁纸、持续动画壁纸。")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            }
            } label: {
                HStack {
                    Text("静态壁纸")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(theme.customBackgroundImage(for: wallpaperAppearanceTarget.colorScheme) == nil ? "默认背景" : "已应用壁纸")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: staticWallpaperExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 用户页背景（1.8.5：默认自动适配浅灰，不黑、不与白卡同色，不做动态背景）
            DisclosureGroup(isExpanded: $profileBackgroundExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                Picker("用户页背景", selection: $profileBackgroundRaw) {
                    Text("自动").tag("auto")
                    Text("主题浅色").tag("accentTint")
                    Text("浅灰").tag("lightGray")
                    Text("自定义").tag("custom")
                }
                .pickerStyle(.segmented)
                if profileBackgroundRaw == "custom" {
                    HStack {
                        Text("自定义颜色").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: profileBackgroundCustomHex) ?? Color(UIColor.systemGray6) },
                            set: { profileBackgroundCustomHex = $0.hexString }
                        ))
                        .labelsHidden()
                    }
                    Text("深色自定义色时标题区文字自动变白字；浅色时用深色字。")
                        .font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
                }
                Text("默认“自动”为浅灰适配：不再是纯黑，与下方白色主卡有区分、层次分明；切换后标题区与头像区同步变色。本项只改静态背景色，不做动态壁纸、持续动画。")
                    .font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
            }
            } label: {
                HStack {
                    Text("用户页背景").font(BeansFont.appFont(13, .semibold)).foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(profileBackgroundRaw == "auto" ? "自动适配" : profileBackgroundRaw == "accentTint" ? "主题浅色" : profileBackgroundRaw == "lightGray" ? "浅灰" : "自定义").font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                    Image(systemName: profileBackgroundExpanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 导航栏显示（参照 2.0.3 BeansTabVisibility，Co 五页版，含精选标签、不含聚合切换）
            DisclosureGroup(isExpanded: $navVisibilityExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                ForEach([
                    ("discover", "主页", "house.fill"),
                    ("featured", "精选", "square.grid.2x2.fill"),
                    ("library", "音乐库", "music.note.list"),
                    ("profile", "我的", "person.crop.circle"),
                    ("search", "搜索", "magnifyingglass"),
                ], id: \.0) { item in
                    Toggle(isOn: navBinding(for: item.0)) {
                        HStack(spacing: 12) {
                            Image(systemName: item.2)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.beansAmber)
                                .frame(width: 28)
                            Text(item.1)
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(Color.beansAmber)
                }
                Text("关掉即从底栏消失，打开即恢复；至少保留一页；当前页被关闭时自动切到第一个可见页。精选页内容走现有发现页的歌单广场与排行榜，不做聚合与平台切换。")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                Divider().overlay(Color.beansComment.opacity(0.15))
                // 1.8.7：底栏图标样式多选（2.0.3 同款三档），用系统 SF Symbols
                // 填充/描边/圆润变体实现，不另引 2.0.3 图片资源；切换后底栏立即变。
                VStack(alignment: .leading, spacing: 10) {
                    Text("底栏图标样式").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    Picker("底栏图标样式", selection: $tabIconStyleRaw) {
                        Text("Apple Music").tag(CoTabIconStyle.appleMusic.rawValue)
                        Text("SF Symbols").tag(CoTabIconStyle.sfSymbols.rawValue)
                        Text("圆润样式").tag(CoTabIconStyle.rounded.rawValue)
                    }
                    .pickerStyle(.segmented)
                    Text("Apple Music 为填充图标、SF Symbols 为描边图标、圆润样式为圆形变体；仅改图标样式，不改底栏顺序与颜色。")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Text("关掉即从底栏消失，打开即恢复；至少保留一页；当前页被关闭时自动切到第一个可见页。")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            }
            } label: {
                HStack {
                    Text("底部栏显示")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text("已显示 \(navVisibleCount)/5 页")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: navVisibilityExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 隐藏的歌单（1.8.5：我的页长按隐藏的歌单在此逐条恢复，只藏显示、不删歌单）
            DisclosureGroup(isExpanded: $hiddenPlaylistsExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                Button { hiddenAccounts = CoHiddenPlaylists.allAccounts() } label: {
                    Text("刷新列表").font(BeansFont.appFont(13, .medium)).foregroundStyle(Color.beansAmber)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background { BeansSurface(shape: Capsule()) }
                }
                .buttonStyle(.plain)
                if hiddenAccounts.isEmpty {
                    Text("暂无隐藏的歌单。在“我的”页长按一条歌单可隐藏它，隐藏后只不在“我的”页显示，歌单本身不删除。")
                        .font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                } else {
                    ForEach(hiddenAccounts, id: \.userId) { account in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(account.userId == "local" ? "本地（未登录）" : "账号 \(account.userId)")
                                .font(BeansFont.appFont(12, .semibold)).foregroundStyle(Color.beansComment)
                            ForEach(account.entries, id: \.id) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name).font(BeansFont.appFont(14)).foregroundStyle(Color.beansLabel).lineLimit(1)
                                        Text("歌单 ID \(entry.id)").font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
                                    }
                                    Spacer()
                                    Button {
                                        var entries = account.entries.filter { $0.id != entry.id }
                                        CoHiddenPlaylists.save(userId: account.userId, entries: entries)
                                        hiddenAccounts = CoHiddenPlaylists.allAccounts()
                                        BeansHaptics.select()
                                        ToastCenter.shared.show("已恢复显示")
                                    } label: {
                                        Text("恢复显示").font(BeansFont.appFont(13, .medium)).foregroundStyle(Color.beansAmber)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background { BeansSurface(shape: Capsule()) }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear { hiddenAccounts = CoHiddenPlaylists.allAccounts() }
            } label: {
                HStack {
                    Text("隐藏的歌单").font(BeansFont.appFont(13, .semibold)).foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(hiddenAccounts.isEmpty ? "无" : "\(hiddenAccounts.reduce(0) { $0 + $1.entries.count }) 条已隐藏").font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                    Image(systemName: hiddenPlaylistsExpanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 音质（简化版：酷狗官方 5 档，不做 Wi-Fi/蜂窝分档，不做第三方音源音质）
            DisclosureGroup(isExpanded: $audioQualityExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("播放音质")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(playbackAudioQualitySelection.wrappedValue.displayName)
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BeansAudioQuality.allCases) { quality in
                            let selected = playbackAudioQualitySelection.wrappedValue == quality
                            Button {
                                playbackAudioQualitySelection.wrappedValue = quality
                                BeansHaptics.select()
                            } label: {
                                HStack(spacing: 5) {
                                    Text(quality.displayName)
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                }
                                .font(BeansFont.appFont(12, selected ? .semibold : .medium))
                                .foregroundStyle(selected ? Color.beansAmber : Color.beansLabel)
                                .padding(.horizontal, 12)
                                .frame(height: 31)
                                .background {
                                    Capsule()
                                        .fill(selected ? Color.beansAmber.opacity(0.14) : Color.beansLabel.opacity(0.055))
                                }
                                .overlay {
                                    Capsule()
                                        .strokeBorder(selected ? Color.beansAmber.opacity(0.42) : Color.beansLabel.opacity(0.08), lineWidth: 0.8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                Text("按酷狗账号权益自动降级：无 VIP 时 Hi-Res / 无损可能不可用，接口会自动降级，不是 bug。")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            }
            } label: {
                HStack {
                    Text("音源与音质")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(playbackAudioQualitySelection.wrappedValue.displayName)
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: audioQualityExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)


            // MARK: - 动态壁纸（Co 不做动态壁纸：无动态壁纸引擎，默认关闭以省电，此处只作说明，不设假开关）
            DisclosureGroup(isExpanded: $dynamicWallpaperExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Co 只用静态壁纸（上传/选择/模糊度见上方“静态壁纸”）。2.0.3 的动态壁纸是连续动画，耗电明显，Co 默认不做、不开。")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
            } label: {
                HStack {
                    Text("动态壁纸")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text("关闭（省电）")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: dynamicWallpaperExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 高刷新率（Co 默认关闭以省电，选项保留）
            DisclosureGroup(isExpanded: $highRefreshExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $enableHighRefresh) {
                        Text("高刷新率（最高 120Hz）")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                    }
                    .toggleStyle(.switch)
                    .tint(Color.beansAmber)
                    Text("默认关闭以省电。开启后界面刷新率可达 120Hz，但耗电与发热增加。")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
            } label: {
                HStack {
                    Text("高刷新率")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(enableHighRefresh ? "开启" : "关闭（省电）")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: highRefreshExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 问候语（1.8.4 恢复：原旧区的高级项，存储键与逐行绑定函数一直都在，只补回界面）
            DisclosureGroup(isExpanded: $greetingExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("主页问候文字（留空自动显示早上好/下午好/晚上好）")
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansComment)
                    TextEditor(text: $homeGreetingText)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.beansLabel.opacity(0.12), lineWidth: 0.8))
                    HStack {
                        Text("文字大小").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                        Spacer()
                        Text("\(Int(homeGreetingSize))").font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                    }
                    Slider(value: $homeGreetingSize, in: 20...64, step: 1).tint(Color.beansAmber)
                    HStack {
                        Text("文字高度").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                        Spacer()
                        Text(homeGreetingHeight <= 0 ? "自动" : "\(Int(homeGreetingHeight))").font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                    }
                    Slider(value: $homeGreetingHeight, in: 0...260, step: 1).tint(Color.beansAmber)
                    HStack {
                        Text("问候文字颜色").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: homeGreetingColorHex) ?? Color.beansLabel },
                            set: { homeGreetingColorHex = $0.hexString }
                        )).labelsHidden()
                    }
                    Toggle(isOn: $homeGreetingGlowEnabled) {
                        Text("开启文字背景发光").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    }.toggleStyle(.switch).tint(Color.beansAmber)
                    if homeGreetingGlowEnabled {
                        HStack {
                            Text("发光强度").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                            Spacer()
                            Text("\(Int(homeGreetingGlowIntensity * 100))%").font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                        }
                        Slider(value: $homeGreetingGlowIntensity, in: 0...2, step: 0.01).tint(Color.beansAmber)
                    }
                    Toggle(isOn: $homeGreetingUnderline) {
                        Text("显示底部横线").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    }.toggleStyle(.switch).tint(Color.beansAmber)
                    Toggle(isOn: $homeGreetingGradient) {
                        Text("开启上下渐变字").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    }.toggleStyle(.switch).tint(Color.beansAmber)
                    if homeGreetingGradient {
                        HStack {
                            Text("渐变起始颜色").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                            Spacer()
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: homeGreetingGradientStartHex) ?? Color.beansLabel },
                                set: { homeGreetingGradientStartHex = $0.hexString }
                            )).labelsHidden()
                        }
                        HStack {
                            Text("渐变结束颜色").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                            Spacer()
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: homeGreetingGradientEndHex) ?? Color.beansLabel },
                                set: { homeGreetingGradientEndHex = $0.hexString }
                            )).labelsHidden()
                        }
                    }
                    ForEach(Array(homeGreetingLines.prefix(3).enumerated()), id: \.offset) { index, line in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("第 \(index + 1) 行：\(line)").font(BeansFont.appFont(14, .semibold)).foregroundStyle(Color.beansLabel).lineLimit(1)
                                Spacer()
                                Button("恢复默认行") { resetGreetingLineStyle(index) }
                                    .font(BeansFont.appFont(12, .semibold)).foregroundStyle(Color.beansAmber).buttonStyle(.plain)
                            }
                            HStack {
                                Text("字号").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                                Spacer()
                                Text("\(Int(greetingLineSizeBinding(index).wrappedValue))").font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                            }
                            Slider(value: greetingLineSizeBinding(index), in: 12...80, step: 1).tint(Color.beansAmber)
                            HStack {
                                Text("颜色").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                                Spacer()
                                ColorPicker("", selection: greetingLineColorBinding(index), supportsOpacity: false).labelsHidden()
                            }
                            HStack {
                                Text("上下偏移").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                                Spacer()
                                Text("\(Int(greetingLineOffsetBinding(index).wrappedValue))").font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                            }
                            Slider(value: greetingLineOffsetBinding(index), in: -80...80, step: 1).tint(Color.beansAmber)
                            if homeGreetingGradient {
                                HStack {
                                    Text("渐变起始").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                                    Spacer()
                                    ColorPicker("", selection: greetingLineGradientStartBinding(index), supportsOpacity: false).labelsHidden()
                                }
                                HStack {
                                    Text("渐变结束").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                                    Spacer()
                                    ColorPicker("", selection: greetingLineGradientEndBinding(index), supportsOpacity: false).labelsHidden()
                                }
                            }
                        }
                        .padding(12)
                        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
                    }
                    Text("逐行设置只对主页问候语生效，改动即时保存；恢复默认行会清掉该行的字号/颜色/偏移/渐变。")
                        .font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
                }
            } label: {
                HStack {
                    Text("问候语").font(BeansFont.appFont(13, .semibold)).foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(homeGreetingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自动问候" : (homeGreetingLines.first ?? "自动问候"))
                        .font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment).lineLimit(1)
                    Image(systemName: greetingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 隐藏开关（1.8.4 恢复：原旧区的隐藏项，只影响界面显示，不删数据）
            DisclosureGroup(isExpanded: $hideExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $homeHideUsername) {
                        Text("隐藏主页用户名").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    }.toggleStyle(.switch).tint(Color.beansAmber)
                    Toggle(isOn: $homeHeaderHideSort) {
                        Text("隐藏所有界面排序按钮").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    }.toggleStyle(.switch).tint(Color.beansAmber)
                    Toggle(isOn: $hidePlatformPicker) {
                        Text("隐藏顶部平台列表").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    }.toggleStyle(.switch).tint(Color.beansAmber)
                    Toggle(isOn: $homeHeaderHideRefresh) {
                        Text("隐藏主页刷新按钮").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    }.toggleStyle(.switch).tint(Color.beansAmber)
                    Toggle(isOn: $showSongVIPBadge) {
                        Text("显示歌曲 VIP 图标").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                    }.toggleStyle(.switch).tint(Color.beansAmber)
                    Text("排序按钮隐藏后，“我的”页左菜单会消失，但设置齿轮还在，可随时回来再打开；其余隐藏项只藏界面元素，不影响播放与数据。")
                        .font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
                }
            } label: {
                HStack {
                    Text("隐藏开关").font(BeansFont.appFont(13, .semibold)).foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text("\([homeHideUsername, homeHeaderHideSort, hidePlatformPicker, homeHeaderHideRefresh].filter { $0 }.count + (showSongVIPBadge ? 0 : 1)) 项已隐藏")
                        .font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                    Image(systemName: hideExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)

            // MARK: - 低系统底栏（1.8.4 恢复：原旧区的低系统悬浮底栏微调，仅 iOS 26 以下生效）
            DisclosureGroup(isExpanded: $legacyTabExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    if #unavailable(iOS 26) {
                        HStack {
                            Text("低系统悬浮底栏").font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                            Spacer()
                            Button("恢复默认") { resetLegacyTabBar() }
                                .font(BeansFont.appFont(12, .semibold)).foregroundStyle(Color.beansAmber).buttonStyle(.plain)
                        }
                        settingsSlider("圆润度", valueText: "\(Int(legacyTabCornerRadius))") {
                            Slider(value: $legacyTabCornerRadius, in: 18...42, step: 1).tint(Color.beansAmber)
                        }
                        settingsSlider("长度", valueText: "\(Int(legacyTabWidth))") {
                            Slider(value: $legacyTabWidth, in: 300...420, step: 1).tint(Color.beansAmber)
                        }
                        settingsSlider("X 位置", valueText: signedIntText(legacyTabOffsetX)) {
                            Slider(value: $legacyTabOffsetX, in: -40...40, step: 1).tint(Color.beansAmber)
                        }
                        settingsSlider("Y 位置", valueText: signedIntText(legacyTabOffsetY)) {
                            Slider(value: $legacyTabOffsetY, in: -36...36, step: 1).tint(Color.beansAmber)
                        }
                    } else {
                        Text("iOS 26 及以上走新式系统底栏，本项不生效；Co 在 iOS 27 上不走这条旧底栏路径，故不提供假调节。")
                            .font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                    }
                }
            } label: {
                HStack {
                    Text("低系统底栏").font(BeansFont.appFont(13, .semibold)).foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text("仅 iOS 26 以下生效")
                        .font(BeansFont.appFont(12)).foregroundStyle(Color.beansComment)
                    Image(systemName: legacyTabExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.beansComment.opacity(0.6))
                }
            }
            .padding(.vertical, 2)        }
    }

    /// 主题相关设置统一归组，避免平台和排行榜外观选项散落在设置页。
    /// 校验扩展名并安装字体（asCopy 返回的 URL 已在沙盒内，可直接读取）
    private func installFont(from url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ["ttf", "otf", "ttc"].contains(ext) else {
            ToastCenter.shared.show("请选择 ttf / otf 字体文件")
            return
        }
        if let name = FontManager.install(from: url) {
            BeansHaptics.success()
            ToastCenter.shared.show("字体已应用：\(name)")
        } else {
            ToastCenter.shared.show("字体安装失败，请使用 ttf / otf 文件")
        }
    }

    private func installGreetingFont(from url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ["ttf", "otf", "ttc"].contains(ext) else {
            ToastCenter.shared.show("请选择 ttf / otf 字体文件")
            return
        }
        if let name = FontManager.installGreeting(from: url) {
            homeGreetingFontName = name
            BeansHaptics.success()
            ToastCenter.shared.show("主页问候字体已应用：\(name)")
        } else {
            ToastCenter.shared.show("主页问候字体安装失败，请使用 ttf / otf 文件")
        }
    }

    private var equalizerSection: some View {
        Button {
            BeansHaptics.select()
            showEqualizer = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(beansLocalized("均衡器", "Equalizer"))
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Text(beansLocalized("调节低音、人声与高音", "Adjust bass, vocals, and treble"))
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                Text(equalizer.isEnabled ? beansLocalized("已开启", "On") : beansLocalized("已关闭", "Off"))
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(equalizer.isEnabled ? Color.beansAmber : Color.beansComment)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
    }

    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BeansHaptics.select()
                withAnimation(.easeInOut(duration: 0.22)) {
                    playbackExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("播放设置")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                    }
                    Spacer()
                    Image(systemName: playbackExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))

            if playbackExpanded {
            VStack(spacing: 14) {
                Toggle(isOn: $mixesWithOthers) {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("与其他音频同时播放")
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)
                .onChange(of: mixesWithOthers) { value in
                    PlayerManager.applyAudioMixPreference(value)
                }

                Divider().overlay(Color.beansComment.opacity(0.15))

                // 1.8.7：删旧的“高刷新已关闭”省电行——它一打开就强制关高刷，
                // 会把用户在外观组里开的高刷新率悄悄关掉；高刷开关只留外观组一处。

                Toggle(isOn: $autoResumeLastPlayback) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.square.stack.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(beansLocalized("启动时自动播放上次歌曲", "Auto-play the last song on launch"))
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                            Text(beansLocalized("打开软件后自动恢复上次未播放完的歌曲", "Automatically resume the last unfinished song when the app starts."))
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)

                Divider().overlay(Color.beansComment.opacity(0.15))

                // 1.8.7：音质只在“外观与界面 → 音源与音质”里留一处，这里不再重复。
                Text("播放音质在“外观与界面 → 音源与音质”里设置，这里不再重复。")
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)

                Divider().overlay(Color.beansComment.opacity(0.15))

                Toggle(isOn: $hapticsEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        Text(beansLocalized("触感反馈", "Haptic Feedback"))
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)

                Divider().overlay(Color.beansComment.opacity(0.15))

                Toggle(isOn: $showThirdPartyVIPNotice) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(beansLocalized("第三方播放会员歌提醒", "VIP song notice for third-party playback"))
                                .font(BeansFont.appFont(15))
                                .foregroundStyle(Color.beansLabel)
                        }
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.beansAmber)

                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                    Text(beansLocalized("第三方音源", "Third-party Sources"))
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(beansLocalized("\(customSourceCount) 个", "\(customSourceCount) sources"))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }

                Button {
                    ToastCenter.shared.show("第三方音源已删")
                    BeansHaptics.tap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                        Text(beansLocalized("管理 / 导入音源", "Manage / Import Sources"))
                    }
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black, in: Capsule())
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.97))


            }
            .padding(16)
            .background {
                                BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .beansCardShadow(radius: 9, y: 3)
            .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// 更新日志入口
    private var changelogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                BeansHaptics.tap()
                showChangelog = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 28)
                    Text("更新日志")
                        .font(BeansFont.appFont(15))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text("v\(ChangelogStore.currentVersion)")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.beansComment.opacity(0.6))
                }
                .padding(16)
                .background {
                                    BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            .beansCardShadow(radius: 8, y: 3)
        }
    }
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BeansHaptics.select()
                withAnimation(.easeInOut(duration: 0.22)) {
                    backupExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(Color.beansAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("备份与恢复")
                            .font(BeansFont.appFont(15))
                            .foregroundStyle(Color.beansLabel)
                    }
                    Spacer()
                    Image(systemName: backupExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.beansComment)
                }
                .padding(14)
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .buttonStyle(.plain)

            if backupExpanded {
            VStack(spacing: 10) {
                Toggle("备份登录信息", isOn: $backupIncludeAccounts)
                    .tint(Color.beansAmber)
                    .font(BeansFont.appFont(13))
                Divider().opacity(0.35)
                Toggle("备份壁纸图片", isOn: $backupIncludeWallpapers)
                    .tint(Color.beansAmber)
                    .font(BeansFont.appFont(13))
                Divider().opacity(0.35)
                Text("默认不带账号登录信息；关闭壁纸后只备份普通设置，不写入壁纸图片数据")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            HStack(spacing: 10) {
                backupActionButton(icon: "square.and.arrow.up", title: "导出备份") {
                    BeansHaptics.tap()
                    exportBackup(includeAccounts: backupIncludeAccounts, includeWallpapers: backupIncludeWallpapers)
                }
                backupActionButton(icon: "square.and.arrow.down", title: "导入恢复") {
                    BeansHaptics.tap()
                    showRestorePicker = true
                }
            }
            if let backupMessage {
                Text(backupMessage)
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            }
        }
    }

    private func backupActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(LocalizedStringKey(title))
            }
            .font(BeansFont.appFont(14, .semibold))
            .foregroundStyle(Color.beansLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
    }

    private static func isAccountBackupKey(_ key: String) -> Bool {
        key == "beans.user"
            || key.hasPrefix("beans.netease.")
            || key.hasPrefix("beans.qqmusic.")
            || key.hasPrefix("beans.kugou.")
    }

    private static func isPrivacyBackupKey(_ key: String) -> Bool {
        key.hasPrefix("beans.search.")
            || key.hasPrefix("beans.log")
            || key.hasPrefix("beans.crash")
            || key == "beans.thirdPartyAPIKeys"
            || key == "beans.launchInProgress"
            || key == "beans.wallpapers.deleted"
    }

    private static func isWallpaperBackupKey(_ key: String) -> Bool {
        key == "beans.background.image"
            || key == "beans.background.image.light"
            || key == "beans.background.image.dark"
            || key == "beans.background.custom"
            || key == "beans.background.custom.light"
            || key == "beans.background.custom.dark"
            || key == "beans.wallpapers.list"
            || key == "beans.wallpapers.data"
            || key == "beans.lyricBackground.image"
            || key == "beans.lyricBackground.data"
    }

    private static func isSystemBackupKey(_ key: String) -> Bool {
        key.hasPrefix("Apple")
            || key.hasPrefix("NS")
            || key.hasPrefix("com.apple.")
            || key == "AddingEmojiKeybordHandled"
    }

    private static func isBackupCandidateKey(_ key: String) -> Bool {
        key.hasPrefix("beans.") && !isSystemBackupKey(key)
    }

    private static func isExcludedBackupKey(_ key: String, includeAccounts: Bool = false, includeWallpapers: Bool = true) -> Bool {
        (!includeAccounts && isAccountBackupKey(key))
            || (!includeWallpapers && isWallpaperBackupKey(key))
            || isPrivacyBackupKey(key)
            || key == "beans.backup.meta"
            || key == "beans.font.restore"
    }

    /// 导出：收集本 App 设置，排除账号、搜索记录和日志，交给系统原生导出面板
    private func exportBackup(includeAccounts: Bool, includeWallpapers: Bool) {
        let defaults = UserDefaults.standard
        var payload: [String: Any] = [:]
        if includeWallpapers {
            theme.refreshWallpaperBackupForExport()
            LyricBackgroundStore.refreshForExport()
        }
        for (key, value) in defaults.dictionaryRepresentation() {
            guard Self.isBackupCandidateKey(key) else { continue }
            guard !Self.isExcludedBackupKey(key, includeAccounts: includeAccounts, includeWallpapers: includeWallpapers) else { continue }
            // 超大原始 Data 直接跳过（壁纸 base64 已以字符串形式存于 beans.wallpapers.data，不受影响）
            if let data = value as? Data, data.count > 2 * 1024 * 1024 { continue }
            let safe = backupJSONSafe(value)
            // 逐个校验可序列化，异常类型直接跳过，避免整份备份生成失败
            guard JSONSerialization.isValidJSONObject([key: safe]) else { continue }
            payload[key] = safe
        }
        // 字体文件（Documents/Fonts）随备份一起导出
        if let font = FontManager.exportFontData() {
            payload["beans.font.restore"] = [
                "name": font.name,
                "data": font.data.base64EncodedString(),
            ] as [String: Any]
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        payload["beans.backup.meta"] = [
            "app": "Co",
            "created": ISO8601DateFormatter().string(from: Date()),
            "version": version,
            "includedAccounts": includeAccounts,
            "includedWallpapers": includeWallpapers,
            "excluded": [
                includeAccounts ? nil : "account",
                includeWallpapers ? nil : "wallpapers",
                "search history",
                "logs",
            ].compactMap { $0 }.joined(separator: ", "),
        ] as [String: Any]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            backupMessage = "备份生成失败：存在无法序列化的设置项"
            ToastCenter.shared.show("备份生成失败")
            return
        }
        backupDoc = BackupDocument(data: data)
        backupMessage = nil
        BeansLogger.shared.log("导出配置备份（\(payload.count) 项，账号=\(includeAccounts ? "包含" : "排除") 壁纸=\(includeWallpapers ? "包含" : "排除")）", level: .info)
        showExportBackup = true
    }

    private static func backupDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// 读取用户选择的备份文件并解析，弹确认后恢复
    private func handleBackupImport(_ url: URL) {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            ToastCenter.shared.show("备份文件解析失败")
            return
        }
        pendingRestore = json
        showRestoreConfirm = true
    }

    /// 恢复：把 JSON 备份中除账号、搜索记录和日志外的本 App 设置写回 UserDefaults
    private func applyRestore(_ json: [String: Any]?) {
        guard let json else { return }
        let defaults = UserDefaults.standard
        var count = 0
        for (key, value) in json {
            guard Self.isBackupCandidateKey(key) else { continue }
            guard !Self.isExcludedBackupKey(key, includeAccounts: true, includeWallpapers: true) else { continue }
            guard let restored = backupPlistSafe(value) else { continue }
            defaults.set(restored, forKey: key)
            count += 1
        }
        // 兼容旧备份：旧版本只有一套背景，恢复后让浅色和深色都继承它。
        if json["beans.background.custom.light"] == nil,
           json["beans.background.custom.dark"] == nil,
           let legacy = json["beans.background.custom"] as? String {
            defaults.set(legacy, forKey: "beans.background.custom.light")
            defaults.set(legacy, forKey: "beans.background.custom.dark")
        }
        if json["beans.background.image.light"] == nil,
           json["beans.background.image.dark"] == nil,
           let legacy = json["beans.background.image"] as? String {
            defaults.set(legacy, forKey: "beans.background.image.light")
            defaults.set(legacy, forKey: "beans.background.image.dark")
        }
        theme.reloadBackgroundSettings()
        defaults.removeObject(forKey: "beans.wallpapers.deleted")
        // 恢复壁纸：写回 beans.wallpapers.* 后重建文件（沙盒路径变化也能恢复）
        theme.reloadWallpapersFromBackup()
        // 恢复歌词背景图片：路径变化时按备份的 base64 重建文件
        LyricBackgroundStore.restoreFromBackup()
        // 恢复字体文件
        if let fontPayload = json["beans.font.restore"] as? [String: Any],
           let name = fontPayload["name"] as? String,
           let b64 = fontPayload["data"] as? String,
           let fontData = Data(base64Encoded: b64) {
            if FontManager.restoreFont(name: name, data: fontData) {
                count += 1
            }
        }
        BeansLogger.shared.log("恢复配置备份：\(count) 项设置", level: .info)
        if count > 0 {
            BeansHaptics.success()
            backupMessage = "已恢复 \(count) 项设置，部分设置需重启应用后完全生效"
            ToastCenter.shared.show("已恢复 \(count) 项设置")
        } else {
            backupMessage = "备份中未找到可恢复的设置"
        }
    }

    private func resetLegacyTabBar() {
        legacyTabCornerRadius = 32
        legacyTabWidth = 356
        legacyTabOffsetX = 0
        legacyTabOffsetY = 0
    }

    private func signedIntText(_ value: Double) -> String {
        let intValue = Int(value.rounded())
        if intValue == 0 { return "0" }
        return intValue > 0 ? "+\(intValue)" : "\(intValue)"
    }

    private func settingsSlider<Content: View>(_ title: String, valueText: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(BeansFont.appFont(13))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Text(valueText)
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(Color.beansAmber)
            }
            content()
                .transaction { transaction in transaction.animation = nil }
        }
    }

    /// 任意 UserDefaults 值 → JSON 可序列化（Data 转 base64、Date 转时间戳）
    private func backupJSONSafe(_ value: Any) -> Any {
        if let data = value as? Data {
            return ["__beansData__": data.base64EncodedString()]
        }
        if let date = value as? Date { return date.timeIntervalSince1970 }
        if let dict = value as? [String: Any] { return dict.mapValues { backupJSONSafe($0) } }
        if let array = value as? [Any] { return array.map { backupJSONSafe($0) } }
        if let dict = value as? [String: String] { return dict }
        if let array = value as? [String] { return array }
        return value
    }

    /// JSON 值 → UserDefaults 可存类型（只保留 plist 兼容类型）
    private func backupPlistSafe(_ value: Any) -> Any? {
        if let dict = value as? [String: Any], dict.count == 1,
           let b64 = dict["__beansData__"] as? String,
           let data = Data(base64Encoded: b64) {
            return data
        }
        if value is String || value is NSNumber { return value }
        if let array = value as? [Any] {
            let mapped = array.compactMap { backupPlistSafe($0) }
            return mapped.count == array.count ? mapped : nil
        }
        if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (k, v) in dict {
                guard let mv = backupPlistSafe(v) else { return nil }
                result[k] = mv
            }
            return result
        }
        return nil
    }

    /// 日志：查看 / 清空（导出入口放在日志查看器右上角）
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "日志")
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    logActionButton(icon: "doc.text.magnifyingglass", title: "查看日志") {
                        showLogViewer = true
                    }
                    logActionButton(icon: "trash", title: "清空日志") {
                        BeansLogger.shared.clear()
                        ToastCenter.shared.show("日志已清空")
                    }
                }
            }
            .padding(14)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private func logActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(LocalizedStringKey(title))
            }
            .font(BeansFont.appFont(13, .semibold))
            .foregroundStyle(Color.beansLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.95))
    }

    private var footerNote: some View {
        VStack(spacing: 6) {
            Text("Co · 仅供学习交流，纯 AI 实现此应用")
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment.opacity(0.7))
            Text("专为酷狗音乐打造")
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    /// 壁纸格子：点击应用到所选外观；使用中的壁纸显示主题色边框+勾选；右上角删除
    private func wallpaperCell(path: String, appearance: BeansWallpaperAppearance) -> some View {
        let isActive = path == theme.backgroundImagePath(for: appearance.colorScheme)
        return ZStack(alignment: .topTrailing) {
            Button {
                BeansHaptics.tap()
                theme.applyWallpaper(at: path, for: appearance.colorScheme)
            } label: {
                Group {
                    if let img = BeansImageFileCache.image(at: path) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.beansGlassFill
                    }
                }
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.beansAmber)
                            .background { BeansSurface(shape: Circle()) }
                            .padding(5)
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                BeansHaptics.medium()
                theme.deleteWallpaper(at: path)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.beansComment)
                    .frame(width: 28, height: 28)
                    .background { BeansSurface(shape: Circle()) }
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .padding(6)
            }
            .buttonStyle(.plain)
            .zIndex(2)
        }
    }
}

// MARK: - 均衡器

struct EqualizerSettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var equalizer = BeansEqualizer.shared
    @State private var newPresetName = ""
    @State private var showPresetNamePrompt = false

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { equalizer.isEnabled },
            set: { equalizer.setEnabled($0) }
        )
    }

    private func gainBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { equalizer.bandGains.indices.contains(index) ? equalizer.bandGains[index] : 0 },
            set: { equalizer.setBandGain(at: index, to: $0) }
        )
    }

    private var preampBinding: Binding<Double> {
        Binding(
            get: { equalizer.preampGain },
            set: { equalizer.setPreampGain($0) }
        )
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        EqualizerResponseView(
                            gains: equalizer.bandGains,
                            preampGain: equalizer.preampGain
                        )
                        controlCard
                        presetCard
                        bandsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle(beansLocalized("均衡器", "Equalizer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(beansLocalized("完成", "Done")) { dismiss() }
                }
            }
            .alert(
                beansLocalized("保存自定义预设", "Save custom preset"),
                isPresented: $showPresetNamePrompt
            ) {
                TextField(
                    beansLocalized("预设名称", "Preset name"),
                    text: $newPresetName
                )
                Button(beansLocalized("保存", "Save")) {
                    if equalizer.saveCustomPreset(name: newPresetName) {
                        BeansHaptics.select()
                    }
                    newPresetName = ""
                }
                Button(beansLocalized("取消", "Cancel"), role: .cancel) {
                    newPresetName = ""
                }
            } message: {
                Text(beansLocalized("保存当前频段和前级增益，之后可以一键恢复。", "Save the current bands and preamp for one-tap recall later."))
            }
        }
    }

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: enabledBinding) {
                HStack(spacing: 11) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(beansLocalized("启用均衡器", "Enable Equalizer"))
                            .font(BeansFont.appFont(15, .semibold))
                            .foregroundStyle(Color.beansLabel)
                        Text(beansLocalized("播放时实时应用当前调节", "Apply the current tuning while playing"))
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(Color.beansAmber)

            Text(beansLocalized("均衡器仅处理 Beans 当前播放的音乐，不影响其他 App。", "The equalizer only processes music playing in Beans."))
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(Color.beansComment.opacity(0.14))

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(beansLocalized("前级增益", "Preamp"))
                        .font(BeansFont.appFont(13, .medium))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(String(format: "%+.1f dB", equalizer.preampGain))
                        .font(BeansFont.appFont(12, .semibold))
                        .foregroundStyle(abs(equalizer.preampGain) > 0.01 ? Color.beansAmber : Color.beansComment)
                        .monospacedDigit()
                }
                Slider(value: preampBinding, in: -BeansEqualizer.maximumGain...BeansEqualizer.maximumGain, step: 0.5)
                    .tint(Color.beansAmber)
                    .transaction { transaction in transaction.animation = nil }
                HStack {
                    Text("-12")
                    Spacer()
                    Text(beansLocalized("不增益", "Unity"))
                    Spacer()
                    Text("+12")
                }
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment.opacity(0.75))
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(beansLocalized("预设", "Preset"))
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Menu {
                    ForEach(BeansEqualizerPreset.allCases.filter { $0 != .custom }) { preset in
                        Button(preset.displayName) {
                            equalizer.applyPreset(preset)
                            BeansHaptics.select()
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(equalizer.selectedCustomPresetName ?? equalizer.selectedPreset.displayName)
                            .font(BeansFont.appFont(13, .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.beansAmber)
                    .padding(.horizontal, 11)
                    .frame(height: 31)
                    .background { BeansSurface(shape: Capsule()) }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(BeansEqualizerPreset.allCases.filter { $0 != .custom }) { preset in
                    let selected = equalizer.selectedPreset == preset
                    Button {
                        equalizer.applyPreset(preset)
                        BeansHaptics.select()
                    } label: {
                        Text(preset.displayName)
                            .font(BeansFont.appFont(11.5, selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.beansAmber : Color.beansLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background {
                                Capsule().fill(selected ? Color.beansAmber.opacity(0.14) : Color.primary.opacity(0.035))
                            }
                            .overlay {
                                Capsule().strokeBorder(selected ? Color.beansAmber.opacity(0.42) : Color.primary.opacity(0.06), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !equalizer.customPresets.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text(beansLocalized("我的预设", "My presets"))
                        .font(BeansFont.appFont(12, .semibold))
                        .foregroundStyle(Color.beansComment)
                    ForEach(equalizer.customPresets) { preset in
                        HStack(spacing: 8) {
                            Button {
                                equalizer.applyCustomPreset(preset)
                                BeansHaptics.select()
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: equalizer.selectedCustomPresetName == preset.name ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(equalizer.selectedCustomPresetName == preset.name ? Color.beansAmber : Color.beansComment)
                                    Text(preset.name)
                                        .font(BeansFont.appFont(12.5, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            Button {
                                equalizer.deleteCustomPreset(preset)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    newPresetName = equalizer.selectedCustomPresetName ?? ""
                    showPresetNamePrompt = true
                } label: {
                    Label(beansLocalized("保存当前预设", "Save current preset"), systemImage: "square.and.arrow.down")
                        .font(BeansFont.appFont(12.5, .medium))
                        .foregroundStyle(Color.beansAmber)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 10, style: .continuous)) }
                }
                .buttonStyle(.plain)

                Button {
                    equalizer.reset()
                    BeansHaptics.select()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansComment)
                        .frame(width: 42, height: 34)
                        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 10, style: .continuous)) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(beansLocalized("重置调节", "Reset adjustments"))
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var bandsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(beansLocalized("自定义调节", "Custom tuning"))
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text(beansLocalized("范围 -12 dB 至 +12 dB", "Range: -12 dB to +12 dB"))
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
            }

            ForEach(Array(BeansEqualizer.bandFrequencies.enumerated()), id: \.offset) { index, frequency in
                equalizerBandRow(index: index, frequency: frequency)
                if index < BeansEqualizer.bandFrequencies.count - 1 {
                    Divider().overlay(Color.beansComment.opacity(0.14))
                }
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private func equalizerBandRow(index: Int, frequency: Double) -> some View {
        let gain = equalizer.bandGains.indices.contains(index) ? equalizer.bandGains[index] : 0
        return VStack(spacing: 6) {
            HStack {
                Text(frequencyLabel(frequency))
                    .font(BeansFont.appFont(13, .medium))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Text(String(format: "%+.1f dB", gain))
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(abs(gain) > 0.01 ? Color.beansAmber : Color.beansComment)
                    .monospacedDigit()
            }
            Slider(value: gainBinding(index), in: -BeansEqualizer.maximumGain...BeansEqualizer.maximumGain, step: 0.5)
                .tint(Color.beansAmber)
                .transaction { transaction in transaction.animation = nil }
            HStack {
                Text("-12")
                Spacer()
                Text("0")
                Spacer()
                Text("+12")
            }
            .font(BeansFont.appFont(10))
            .foregroundStyle(Color.beansComment.opacity(0.75))
        }
    }

    private func frequencyLabel(_ frequency: Double) -> String {
        if frequency >= 1_000 {
            let value = frequency / 1_000
            return value.rounded() == value ? "\(Int(value)) kHz" : String(format: "%.1f kHz", value)
        }
        return "\(Int(frequency)) Hz"
    }
}

private struct EqualizerResponseView: View {
    let gains: [Double]
    let preampGain: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(beansLocalized("频响预览", "Response preview"))
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text(beansLocalized("拖动下方频段，实时塑造声音", "Shape the sound in real time by tuning each band below"))
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                Image(systemName: "waveform.path")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.beansAmber)
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let values = responseValues
                ZStack {
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            Divider().overlay(Color.beansComment.opacity(0.12))
                            Spacer()
                        }
                    }
                    Path { path in
                        guard let first = values.first else { return }
                        path.move(to: CGPoint(x: 0, y: yPosition(first, height: height)))
                        for index in values.indices.dropFirst() {
                            let x = width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                            path.addLine(to: CGPoint(x: x, y: yPosition(values[index], height: height)))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.beansAmber.opacity(0.65), Color.beansAmber, Color.beansHighlight],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    Path { path in
                        guard let first = values.first else { return }
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: 0, y: yPosition(first, height: height)))
                        for index in values.indices.dropFirst() {
                            let x = width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                            path.addLine(to: CGPoint(x: x, y: yPosition(values[index], height: height)))
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.beansAmber.opacity(0.22), Color.beansAmber.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.7)
            }

            HStack {
                Text("31 Hz")
                Spacer()
                Text("1 kHz")
                Spacer()
                Text("16 kHz")
            }
            .font(BeansFont.appFont(10))
            .foregroundStyle(Color.beansComment)
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var responseValues: [Double] {
        guard !gains.isEmpty else { return [preampGain] }
        return gains.map { min(max($0 + preampGain * 0.35, -12), 12) }
    }

    private func yPosition(_ value: Double, height: CGFloat) -> CGFloat {
        let normalized = (value + 12) / 24
        return height * CGFloat(1 - normalized)
    }
}

// MARK: - 壁纸照片选择器（PHPicker 封装：iOS 14+ 兼容，支持多选图片）

struct WallpaperPhotoPicker: UIViewControllerRepresentable {
    let onPicked: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0 // 0 = 多选
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: WallpaperPhotoPicker
        init(_ parent: WallpaperPhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                let provider = result.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                        guard let data, !data.isEmpty else { return }
                        DispatchQueue.main.async {
                            self.parent.onPicked(data)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 字体文件选择器（UIDocumentPicker 包装，比 SwiftUI fileImporter 稳定：所有文件可选，系统 asCopy 复制到沙盒）

struct FontDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FontDocumentPicker
        init(_ parent: FontDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
// MARK: - 配置备份文档（SwiftUI 原生 fileExporter 导出，稳定可靠）

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
// MARK: - 配置备份文件选择器（UIDocumentPicker 封装：比 SwiftUI fileImporter 稳定，所有文件可选）

struct BackupDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText, .item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: BackupDocumentPicker
        init(_ parent: BackupDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
