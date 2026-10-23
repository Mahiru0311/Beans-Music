import SwiftUI

// MARK: - 版本更新日志（设置页与首次更新弹窗使用）

struct VersionLog: Identifiable {
    let id: String
    let version: String
    let title: String
    let notices: [String]
    let features: [String]
    let fixes: [String]
    let imageURL: URL?
    let textColorHex: String?

    init(id: String, version: String, title: String, notices: [String] = [], features: [String], fixes: [String], imageURL: URL? = nil, textColorHex: String? = nil) {
        self.id = id
        self.version = version
        self.title = title
        self.notices = notices
        self.features = features
        self.fixes = fixes
        self.imageURL = imageURL
        self.textColorHex = textColorHex
    }
}

enum ChangelogStore {
    static let lastSeenKey = "beans.lastSeenVersion"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var lastSeenVersion: String {
        UserDefaults.standard.string(forKey: lastSeenKey) ?? ""
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenKey)
        UserDefaults.standard.synchronize()
    }

    static var shouldShowWhatsNew: Bool {
        lastSeenVersion != currentVersion
    }

    static var latest: VersionLog? { logs.first }

    static let logs: [VersionLog] = [
        VersionLog(
            id: "1.9.3",
            version: "1.9.3",
            title: "返回键位置与点按修复、顶部渐变模糊、设置齿轮极简、歌单搜索椭圆",
            features: [
                "歌单与每日推荐详情页顶部加渐变模糊带：顶部安全区+约 120pt 内从模糊/压暗渐变到清晰封面（超薄材质采样背后封面 + 渐变遮罩向底部淡出），状态栏字与返回键落在模糊区里可读，不整张封面糊掉，封面高度与底部五段渐变不动",
                "返回键位置改紧贴状态栏下方：顶距改窗口真实顶安全区+6、左 16、44×44，不再用导航栈里会双重计数的 GeometryReader 安全区",
                "我的页设置齿轮改极简样式：去掉圆钮背景与描边，只留约 20pt 细齿轮（非填充、常规字重、次要灰色、无背景无边框），点击区域仍保留 44×44，点按仍进设置页",
                "歌单详情页搜索框改全圆角椭圆形胶囊：Capsule 形、高约 40pt，放大镜+占位字+清空钮都在胶囊内，背景仍走液态玻璃胶囊；每日推荐页搜索已删，本轮不加回来",
                "全仓审计清理：删掉声明后 0 调用的残留状态（歌单广场分类、下载选择器、手动检查更新、更新下载报错），返回键两页共用同一悬空按钮视图"
            ],
            fixes: [
                "修复返回键位置偏大：在导航栈目的地里 GeometryReader 的 safeAreaInsets.top 会把导航栏区域也算进去，悬空覆盖层顶距被双重抬高到约 140pt；现改窗口真实顶安全区，返回键紧贴状态栏下方",
                "修复返回键点按无效果：Discover/音乐库走 NavigationStack(path:)，该栈里 @Environment dismiss 对路径推送的目的地无效（点按注册了但不弹栈）；现路径栈由调用方弹最后一层（路径为空时回落 dismiss），普通 NavigationLink 栈仍走 dismiss，歌单、每日推荐、音乐库歌单三条路都接通"
            ]
        ),
        VersionLog(
            id: "1.9.2",
            version: "1.9.2",
            title: "返回键悬空固定、播放全部改液态玻璃",
            features: [
                "歌单与每日推荐详情页的返回键改悬空固定：从沉浸头滚动内容里拿出来，盖在整页上方，位置仍是左上、状态栏下方，下滑到歌曲列表底部也一直在、可点返回，样式为液态玻璃圆钮",
                "歌单与每日推荐详情页的播放全部改液态玻璃胶囊：走全站液态玻璃胶囊，字与播放图标改白字，压在玻璃与深色底上可读，行位置与点按播放全部功能不动，歌单页文案统一为“播放全部”"
            ],
            fixes: [
                "修复歌单下滑后返回键随内容滚走、滚到底部找不回来的问题（每日推荐页同结构一并改）",
                "修复播放全部还是白色 pill、与玻璃圆钮风格不一致的问题（每日推荐页的白色 pill 一并改）"
            ]
        ),
        VersionLog(
            id: "1.9.1",
            version: "1.9.1",
            title: "状态栏沉浸、每日推荐白字、图标间距、歌单圆润、统计可点",
            features: [
                "每日推荐与歌单详情页状态栏沉浸：封面从屏幕顶边开始画、状态栏压在封面之上且为浅色字，返回钮在状态栏下方，不再留黑底黑字切条；歌单页歌内搜索保留，只删每日推荐页的搜索",
                "每日推荐歌曲名改为白字可读：歌名纯白、歌手与时长浅灰、VIP 红标不变，搜索框已删（30 首没必要搜），列表直接全显，底部留白加到 170pt",
                "我的歌单行更圆润：行圆角 14→22、封面 44pt/圆角10→52pt/圆角16、内边距 12×8→16×12、加柔和描边与轻阴影，行上“···”与“>”两个控件都删，长按整行弹出系统确认弹窗再隐藏",
                "我的页统计行全部可点：我喜欢进本地喜欢歌曲列表，歌单进我的歌单列表（全部可见歌单，点进详情页），历史进现成最近播放页，常听进按播放次数排序的排行列表（带序号与真实播放次数），空时明写暂无不编数据",
                "右上角设置齿轮改精致：36pt 小液态玻璃圆钮 + 描边细齿轮（非填充、常规字重、浅灰色）+ 柔和描边，不再是白圆黑粗填充齿轮"
            ],
            fixes: [
                "修复状态栏黑条与歌曲名黑字的同源 bug：详情页的深色配色只改 SwiftUI 环境，改不了 UIKit trait（根主题仍浅色），状态栏仍是黑字、动态文字色仍取浅色值；现详情页可见期间把 key window 临时置深色（带计数，多层深色页不提前恢复），状态栏与动态色同步变亮，退出时恢复",
                "修复昵称与 VIP 图标间距约 42pt 的 bug：HStack 间距常量本来就是 8pt，差额来自远程图画布左边的透明区（scaledToFit 把透明区也算进宽度）；现解码器扫描 alpha 裁掉全部帧共有的透明边，昵称行按钮不再用 maxWidth:120 的框撑宽，只 hug 内容、限高 26",
                "纠正歌单详情页头部“···”的归属：本轮只删我的页歌单行上的“···”与“>”，详情页头部“···”菜单（含隐藏）保留，详情页仍可藏"
            ]
        ),
        VersionLog(
            id: "1.9.0",
            version: "1.9.0",
            title: "VIP 图标不再盖昵称、每日推荐沉浸页",
            features: [
                "每日推荐整页重做：旧的纯歌曲列表弹层已删除，大卡、横滑卡的查看全部都进同一页新页——全幅封面沉浸头、居中大标题每日推荐、歌曲数与每天 6:00 更新、白色播放全部 pill 与玻璃随机圆钮、玻璃搜索框、深色歌曲行、底部留白不再被迷你播放器遮住，点歌播放与搜索每日推荐与原有功能一致"
            ],
            fixes: [
                "修复长条款 VIP 图标盖住昵称“见”字的 bug：根因是 SwiftUI 的 frame 本身不裁剪、动图视图 clipsToBounds=false，图片按内在尺寸（截图量出约 97×53pt）居中画在 26pt 帧外，左沿向左溢出盖住昵称；现帧外加裁剪、视图内改裁剪到帧内、布局尺寸明确返回帧尺寸、解码按屏幕 scale 换算回点尺寸、长条款宽上限收紧到 120，昵称行再限高 26 并裁剪兜底",
                "纠正上一轮“每日推荐已统一”的错误结论：每日推荐根本不是歌单详情页，是 DiscoverRoute.dailySongs 进的旧弹层，现已按歌单同套重做；排行榜详情是榜单详情而非歌单详情，本身已用玻璃背景与玻璃按钮与玻璃歌曲行，不按歌单页重做，歌单广场、精选、音乐库、我的歌单仍全部走同一歌单详情页"
            ]
        ),
        VersionLog(
            id: "1.8.9",
            version: "1.8.9",
            title: "动效核查修复、歌单液态玻璃、整体代码优化",
            features: [
                "VIP 选择改成带预览图的系统底部弹层：每项左侧就是该图标的真实预览图，动效款预览本身能动，选中打勾、点即生效；无 VIP 时动效款置灰不可点但预览仍可见；预览图只放内存、不写选款缓存",
                "歌单详情页全部按钮走液态玻璃：返回、分享、随机、收藏星、···菜单、搜索框容器走全站 BeansGlass，iOS26+ 为真液态玻璃，低系统回落超薄材质，紧凑与简洁样式下自带平面回落、不强制液态；白色播放 pill 保持截图里的白色不变，歌曲行不整行玻璃、仍为深色行与细分隔线",
                "歌单更加沉浸：封面加高到 440pt、顶部压暗更足、底部五段渐变衔接更顺，结构仍是 1.8.8 截图布局，不改回小封面头；我的歌单、发现歌单广场、精选、音乐库、每日推荐歌单全部走同一套沉浸加玻璃歌单详情页",
                "VIP 动效款改为真动效解码：下载与缓存均走 CGImageSource 逐帧抽帧、按每帧时长重建动图，动效款在我的页与预览里可见时真能动，静态款、减弱动态效果、无 VIP 时仍静态，页面消失即停；动态壁纸保持不做、无假开关",
                "整体代码优化：删掉多处 0 引用的死代码与重复分支，歌单歌曲列表改懒加载，长歌单只渲染可见行"
            ],
            fixes: [
                "修复动效款 VIP 图标实际是静态的真 bug：旧路用 UIImage(data:) 解码，动图多帧会丢成首帧静态；现逐帧抽帧重建，动效款不再名不副实；静态款、长条款、自绘款本来就是静态设计，不是 bug，自动档自 1.8.6 起为静态也是省电决定",
                "修复 VIP 选择只有文字、看不到图的 bug：旧系统弹窗只有文字选项，现每项带真实预览图",
                "修复歌单详情页绕过全站玻璃的问题：1.8.8 沉浸头用自定义半透明深色按钮，从未调 glassEffect，现已接回 BeansGlass",
                "删掉网易云与 QQ 残留死代码：网易云/QQ 清理函数、QQ 收藏移除与网易云重置、QQ 榜渐变备用函数、网易云喜欢歌单判断、重复的播放音质旧区块、0 引用的歌单分类与账号登录判断、详情页旧迷你播放器修饰器"
            ]
        ),
        VersionLog(
            id: "1.8.8",
            version: "1.8.8",
            title: "图标不再裁、歌单沉浸头、我的页更简洁",
            features: [
                "歌单详情页改回截图布局：全幅封面沉浸头、居中多行大标题、创建者与歌曲数居中、分享圆钮与播放白 pill 与随机圆钮一行、搜索与收藏星一行、歌曲行封面与歌名与歌手与时长、深色底、底部留白不再被迷你播放器遮住",
                "歌单收藏星为本地星标：点星填充、再点取消，只存本地、不假装同步到酷狗账号；下载圆钮不做成假下载，改为真实的随机播放，分享圆钮为真实的系统分享",
                "隐藏了就隐藏了：我的页不再显示已隐藏歌单的提示与去设置恢复的引导，恢复入口只在设置外观与界面里的隐藏的歌单中",
                "我的页不再展示版本信息：页脚版本与基于 Beans 主分支已删，版本与更新日志只在设置关于页",
                "我的页进一步瘦身：只留头像、昵称与 VIP、状态、真实统计、我的歌单，提示行与页脚等杂项已清"
            ],
            fixes: [
                "修复 VIP 图标被 84×20 硬框压成扁长条、唱片圆被裁掉：远程 VIP 图改为只定高 26pt、宽度按原图比例自动算，scaledToFit、不裁剪、不压扁",
                "修复启动页 Logo 用 fill 加固定方框可能裁图标：改为按比例 fit 显示；设置页行首图标全仓排查，矢量图标本身不压扁、品牌位图已是 fit 显示，封面与壁纸等照片类 fill 裁剪为有意设计、未动"
            ]
        ),
        VersionLog(
            id: "1.8.7",
            version: "1.8.7",
            title: "系统弹窗、设置整理、精选标签、歌单详情页",
            features: [
                "VIP 选择改成系统底部弹窗：点徽标弹出系统弹窗，含自动档与 4 款核心款，选即生效，不再是全页选择页",
                "状态编辑改成系统弹窗文本框，歌单隐藏确认也用系统弹窗；我的页每条歌单行右侧加看得见的隐藏按钮",
                "设置打开时全部默认收起，点开才展开；设置整理为账号、外观与界面、播放与音效、数据与支持、关于五个清晰分组",
                "底栏加精选标签：主页、精选、音乐库、我的、搜索，精选页走现有歌单广场与排行榜，不做聚合切换",
                "底栏图标样式多选：Apple Music、SF Symbols、圆润样式三档，切换后底栏图标立即变",
                "歌单详情页按 2.0.3 改：小封面头、播放全部与随机、歌单内搜索与排序、歌曲行 46pt 封面与 64pt 行高、底部留白不再被迷你播放器遮住"
            ],
            fixes: [
                "修复我的页昵称被长条 VIP 图挤出屏幕：昵称与 VIP 行居中限宽，VIP 图限宽限高",
                "修复歌单行标题“歌手 - 歌名”合并显示、副标题写未知歌手：解析层与显示层双拆分，解析不到只显示歌名",
                "修复设置里音质与高刷新率重复出现、播放组一打开就强制关高刷的问题"
            ]
        ),
        VersionLog(
            id: "1.8.6",
            version: "1.8.6",
            title: "我的页重写、状态可改、歌单详情页",
            features: [
                "我的页重写：只留头像、昵称与 VIP、状态、真实统计、我的歌单与版本页脚，删掉快捷宫格与常听排行等杂项，默认 VIP 徽标改为静态，发烫降低",
                "主页状态可以修改：点添加状态可写一句话状态，保存在本地、按账号区分，不同步到酷狗账号，可再改、可清空",
                "歌单点进去：我的页歌单点按进入歌单详情页，封面、歌单名、歌曲数、歌曲列表、播放全部与单首点播，长按隐藏仍保留",
                "设置外观与界面归一：只有一个外观与界面，用系统展开框直接展开，全部项按顺序列在里面，问候语、隐藏开关、低系统底栏、隐藏的歌单都在",
                "VIP 图标精简：只留网站 VIP 档普通、动效、已过期、特殊各一款代表款，用系统展开框选择，按需下载、选新删旧只留一款，下载失败回落自绘徽标"
            ],
            fixes: [
                "修复我的页歌单点按只播放首歌、进不去详情页的问题",
                "修复设置外观与界面分开成多张子卡、开关容易被误删的问题"
            ]
        ),
        VersionLog(
            id: "1.8.5",
            version: "1.8.5",
            title: "VIP 弹出切换、用户页背景、歌单隐藏",
            features: [
                "点 VIP 徽标弹出图标切换，按需下载、选新删旧只留一款",
                "用户页背景可切换，默认不再是黑色",
                "我的页歌单可长按隐藏，设置里可恢复显示",
                "设置排版整理，代码审计删掉无用第三方音源代码"
            ],
            fixes: []
        ),
        VersionLog(
            id: "1.8.4",
            version: "1.8.4",
            title: "我的页重排与 VIP 自动切换",
            features: [
                "我的页按仿网易云格式重排：居中圆形头像、昵称与 VIP 并排、白色主卡压边",
                "VIP 徽标按登录态自动对应，有 VIP 扫光动效、无 VIP 灰色静态",
                "设置恢复问候语逐行定制、隐藏开关、低系统底栏"
            ],
            fixes: []
        ),
        VersionLog(
            id: "1.8.3",
            version: "1.8.3",
            title: "底部迷你播放器与设置合并",
            features: [
                "底部最小化状态迷你播放器改为封面、歌名与仅播放键",
                "设置合并为唯一一个外观与界面组，子项可收起展开并显示当前值"
            ],
            fixes: [
                "修复合并时误删均衡器入口的问题"
            ]
        ),
        VersionLog(
            id: "1.8.2",
            version: "1.8.2",
            title: "我的页与 VIP 动效",
            features: [
                "我的页参考仿网易云布局，VIP 徽标改为轻动效"
            ],
            fixes: []
        ),
        VersionLog(
            id: "1.8.1",
            version: "1.8.1",
            title: "导航栏与外观与界面",
            features: [
                "导航栏改为新式标签，搜索为系统搜索位，顺序为主页、音乐库、我的、搜索",
                "设置新增外观与界面组，含界面、字体、静态壁纸、简化音质",
                "导航栏显示可自定义，至少保留一页"
            ],
            fixes: []
        ),
        VersionLog(
            id: "1.5.8",
            version: "1.5.8",
            title: "歌单同步、主页与播放器全面优化",
            features: [
                "新增网易云音乐、QQ音乐、酷狗音乐歌单一键同步到本地",
                "本地歌单支持编辑和搜索，批量选择歌曲后可添加到其他本地歌单",
                "新增 QQ 音乐热门歌单展示",
                "主页问候语支持自定义文字、颜色、大小、发光、专属字体、底部横线和上下渐变，并可逐行选择渐变颜色",
                "播放器支持左右滑动切换歌曲，新增顶部三平台排序、隐藏主页刷新/用户名/排序按钮",
                "播放器按钮图标样式新增，播放器设置界面重新整理分组和控件排版",
                "主页、音乐库、我的、设置页增加 iPad 最大宽度适配",
                "播放列表、最近播放和日志界面背景同步主页壁纸"
            ],
            fixes: [
                "修复 QQ 音乐喜欢列表不显示的问题",
                "修复最近播放、日志、本地歌单和播放列表不同步主页壁纸的问题",
                "修复设置页掉帧问题；如果本次仍然掉帧，建议更换设备",
                "修复 iOS 15 编译兼容问题"
            ]
        ),
        VersionLog(
            id: "1.5.6",
            version: "1.5.6",
            title: "播放器体验优化",
            features: [
                "封面页歌名、歌手和预览歌词支持渐变、高光及高光强度调节",
                "播放页背景浮尘新增开关，默认关闭；动态浮尘支持密度和大小调节",
                "全局上传壁纸自动同步到播放器封面页背景",
                "播放页支持从顶部下划关闭，并加入缩放、淡出动画"
            ],
            fixes: [
                "修复酷狗排行榜歌曲封面缺失或未归一化的问题",
                "提高内置音源搜索上限",
                "播放器设置打开后不再默认展开播放和歌词显示分组"
            ]
        ),
        VersionLog(
            id: "1.5.5",
            version: "1.5.5",
            title: "播放流畅度与发热优化",
            notices: [
                "从 1.5.4 版本开始，播放器设置已从右上角删除，改为点击中间歌曲正在播放的标题打开。"
            ],
            features: [
                "优化播放中全局刷新策略，移除高刷保持器的常驻空转刷新，降低设置页、我的页面和播放器页面的发热与掉帧",
                "本地壁纸、歌词背景、设置页缩略图改为复用解码缓存，减少滚动和切换设置时的重复图片解码",
                "锁屏/系统正在播放封面增加缓存，避免播放状态变化时反复下载和刷新同一张封面",
                "聆澜内置音源支持多密钥池，当前密钥未命中时自动切换下一个，并记住最近可用密钥",
                "播放器设置新增封面页歌名、歌手、预览歌词与未播放歌词颜色调节"
            ],
            fixes: [
                "修复播放中进度更新过于频繁导致非播放器页面也跟随重绘的问题",
                "修复重新上传歌词背景或恢复壁纸后，部分位置可能继续显示旧图片缓存的问题",
                "修复酷狗排行榜详情歌曲封面链接未归一化，并在官网榜单缺封面时自动用移动端榜单数据补齐封面",
                "优化巨魔安装场景下播放中切换页面的刷新与解码负担"
            ]
        ),
    ]
}

// MARK: - 更新说明弹窗

struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    if let log = ChangelogStore.latest {
                        VersionLogCard(log: log)
                            .padding(16)
                    }
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始使用") {
                        ChangelogStore.markSeen()
                        dismiss()
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansAmber)
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
        .onDisappear {
            ChangelogStore.markSeen()
        }
    }
}

struct ChangelogListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ChangelogStore.logs) { log in
                            VersionLogCard(log: log)
                        }
                    }
                    .padding(16)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
    }
}

private struct VersionLogCard: View {
    let log: VersionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("v\(log.version)")
                    .font(BeansFont.appFont(16, .bold))
                    .foregroundStyle(Color.beansAmber)
                Text(log.title)
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(textColor)
            }
            if let imageURL = log.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        EmptyView()
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !log.notices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log.notices, id: \.self) { notice in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.top, 1)
                            Text(notice)
                                .font(BeansFont.appFont(13, .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            if !log.features.isEmpty {
                logSection(title: "新增功能", icon: "plus.circle.fill", items: log.features)
            }
            if !log.fixes.isEmpty {
                Divider().overlay(Color.beansComment.opacity(0.15))
                logSection(title: "问题修复", icon: "checkmark.circle.fill", items: log.fixes)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .beansCardShadow(radius: 9, y: 3)
    }

    private func logSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(BeansFont.appFont(14, .bold))
                .foregroundStyle(Color.beansAmber)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansAmber)
                        .padding(.top, 2)
                    Text(LocalizedStringKey(item))
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var textColor: Color {
        if let raw = log.textColorHex, let color = Color(hex: raw) { return color }
        return Color.beansLabel
    }
}
