# 给 Mac 上编程 AI 的完整实施指令

请全程使用中文，直接读取项目、编写代码、本地编译、运行测试，并交付完整源码和未签名 IPA。不要只分析或提出建议。工作在这份本地源码副本中，不需要 GitHub 操作，不推送，不发布 Release，不修改或上传后端。

## 输入与已经核实的事实

我提供的素材是：

1. 本目录的 Beans 完整源码基线，也可从 Beans-CiliCili-source.zip 解压。原始压缩包外面还套了一层同名 ZIP，可能需要解压两次。
2. Beans-2.0.3-b2-WebDAV-unsigned.ipa，是需要对照恢复的成品。Bundle ID 为 com.beans.app，版本 2.0.3，build 2，MinimumOSVersion 为 15.0。
3. 本目录 RecoveryEvidence 下的反编译资料；如果尚未提供，请继续完成独立的源码检查和修复，再明确指出缺失的恢复证据。
4. ikun-music-source.js 已在 Beans/Resources 中；若另提供同名脚本，应核对版本并使用实际提供的脚本。

重要：不能因为 ZIP 名称或我的原先判断，就把它认定为 2.0.3 原源码。实际 project.yml 是 1.8.1 / build 19，iOS 26.1。按 CRLF/LF 归一化后，其中 1297 个 Swift/YAML 文件与旧 Windows 仓库一致，没有发现更新的 Swift/YAML 实现。它是可继续开发的源码基线，不是已找回的 2.0.3 工程。

IPA 未加密，但主程序实现符号大多被剥离，无 DWARF。资料包括 Swift 类型/字段、字符串、资源清单、24 个重点函数的 Ghidra 伪代码，不是完整原始 Swift。自动分析曾达到时间上限，CiliCiliKit 元数据有 5 个解析异常。要保留这些证据限制，不要把未验证的推测写成已经恢复的行为。

请先读取 SOURCE_ANALYSIS.md，检查已有实现，再制定本地实施清单。保留正确的 CiliCili 详情页和评论实现、Beans 播放器、壁纸与动效。我的目标是重建 2.0.3 中缺失的功能，同时落实以下产品调整。

## 一、恢复 IPA 中缺失的功能

优先分析 RecoveryEvidence/Beans/swift-types.json、strings.json、webdav-string-loads.json、decompiled，以及资源清单、IPA 的 Info.plist 和本地化。

已经确认 IPA 主程序中有以下源码基线缺失的结构：

- SongSource 包含 webdav，Song 包含 webDAV 字段。
- WebDAVConnection：id、address、username、allowHTTP。
- WebDAVTrack：connectionID、relativePath、accountKey。
- WebDAVStore、WebDAVClient、WebDAVListingParser、WebDAVTransfer。
- WebDAVView、WebDAVConnectionView、WebDAVBrowserView、WebDAVBackupView、WebDAVPageBackdrop。
- WebDAVBackup：format、version、createdAt、playlists、favoriteSongs、albums、artists、favoritePlaylists、settings。
- WebDAVSetting 的 string、number、bool 三种形式。
- WebDAVError：http、keychain、invalidAddress、outsideRoot、invalidListing、tooLarge、missingConnection、invalidBackup。
- PlayerManager 中有 bilibiliQueueLoader、bilibiliQueueID、audioResolutionTask、preparationTimeoutWorkItem 等在新包中出现的状态线索。

根据证据实现连接管理、目录浏览和搜索、播放、队列、音乐缓存清理、上传备份、下载备份、预览和合并恢复。补齐 SongSource/Song 的 Codable、身份键、列表/收藏/历史、播放器、缓存和下载处理；检查全部 switch 和旧数据兼容，不能只添加一个页面。

字符串中存在 HTTPS 地址验证、HTTP 单独确认、目录越界拒绝、Keychain 凭据、401/403/404 分别提示、文件大小限制、取消下载、备份回读校验、设置可选恢复和红心歌曲合并入口。按实际伪代码和元数据确定实现，不要凭这些名称猜出全部协议细节。密码不能存入普通设置、备份、歌词或日志。

备份的 format/version、日期格式、序列化类型与合并身份规则，要继续从代码证据或实际备份样本核实；没有证据时采用明确版本化的新格式并记录兼容边界，不能谎称与原版备份完全兼容。恢复前验证全部内容，避免半途失败留下部分写入。

还应核对 IPA 的 BeansCacheManagement.swift、BeansDiagnosticInstrumentation.swift、FavoriteDetailSwipeBack.swift、LyricDebugOverlay.swift 线索与当前功能差异。源码路径字符串不代表完整源码文件内容；优先恢复实际功能，不机械创建同名空文件。Live Activity 目录虽然在基线中存在，但 project.yml 未声明相应扩展目标；按 IPA 实际 extension 信息和已有共享模型检查需要恢复的 target、依赖与嵌入配置。

目前只要求 iOS 26 系统，先沿用基线 26.1 的真实 API 要求；不要仅因 IPA 写着 minimum iOS 15 就宣称代码支持 iOS 15。低版本适配以后再统一做。版本号最终按恢复开发包明确命名，不要只改到 2.0.3 就声称已恢复成品。

## 二、哔哩哔哩主页与搜索

必须先阅读本地 Modules/CiliCili 的真实代码。主入口是 Beans/DiscoverView.swift -> CiliCiliHomeView -> Modules/CiliCili/Sources/App/RootTabView.swift，不是 Beans/BilibiliHomePage.swift。后者目前是 Beans 搜索页的哔哩哔哩分支。不能改错入口。

- 主页默认双列；基线 LibraryStore.defaultHomeFeedLayout 已是 doubleColumn，核对持久化设置和实际卡片布局，不重复重写。
- 首页推荐数据继续使用 CiliCili 的 HomeViewModel、推荐服务与分页链路，保留其真实推流、凭据和过滤行为。不要改成旧 BilibiliHomeFeed 的推荐或关键词搜索来冒充分类推流。
- 顶部加原生搜索框，左上角用 Beans 旧蓝色 BrandBilibili 图标；主页右上角以账号头像进入“我的”。移除主区域“推荐、动态、直播、我的、搜索”整排根标签，恢复旧版游戏、生活、音乐等分区导航的视觉和真实分区行为。
- 分区参考 Beans/BilibiliBrowseModels.swift 的 BilibiliChannel；这些是分区而不是五个根页面。根据 CiliCili 已有 API 能力接入分区；推荐仍走 CiliCili 原推荐数据链路。直播等功能即使调整入口也不要无故删掉。
- 移除主页三个点中的推荐/热门切换与原右上角消息入口。HomeFeedModeMenu、HomeFeedNavigationChrome 在当前宿主中可能已经不显示，先查实际调用，不要删掉仍被其他页面使用的公共实现。
- Beans 搜索页恢复 Beans 原布局和搜索框，哔哩哔哩作为其中一个搜索来源，支持视频、UP、合集/收藏等原有类别；不要把整个搜索页替换成 CiliCili 首页，也不要无故删除其他音乐来源。
- SearchView.swift 当前有 provider == bilibili 的整页替换，以及 startSearch/searchPlaylistTab 的提前返回。恢复搜索必须同时处理这些实际阻断，复用现有搜索状态、取消与分页逻辑，不能只改 body。
- 清理实际存在的“我的歌/我的歌曲”等不需要的搜索入口，不要误删 Beans 本地音乐功能。

## 三、“我的”、登录和主题

- 听视频/看视频选择放在哔哩哔哩主页右上角头像进入的“我的”中，持久化，并在打开视频时真正生效。MineContentView 已有此选择，要核对完整链路后保留。
- 复用 CiliCili 的账户、收藏/历史等逻辑，将哔哩哔哩“我的”整体 UI 改为 Beans 卡片、字号、间距和玻璃风格。
- Beans 设置中的哔哩哔哩登录入口只保留手机号、扫码、网页登录及必要登录状态/退出操作。当前 BilibiliLoginSheet 直接打开 CiliCiliRouteHost(.account)，实际展示完整 MineContentView；应拆出真正的登录专用页面，共享凭据，业务设置集中到主页右上角“我的”。
- 删除哔哩哔哩“我的”中原项目开源地址、版本展示、稍后再看入口、强制 120Hz、底栏液态暗色底、独立主色调设置。先查可达视图：MineContentView 目前只挂账户、资料库、播放模式，部分设置或关于组件已经没有显示；保留被其他有效功能引用的代码，处理必要的数据迁移。
- 这里按统一外观理解我的主题需求：哔哩哔哩主页、搜索、我的和登录周边 UI 应跟随 Beans 的壁纸、字号、强调色设置，主色调统一使用 Beans 设置。当前 CiliCiliEnvironment 使用独立 LibraryStore.appTintColor/字号，而 MineView 使用不透明 systemBackground，必须通过明确宿主桥接修复。framework 内不要直接引用 Beans 私有类型，也不要按播放器高频进度同步主题或重建依赖。
- GPL 来源与许可证必须保留在代码、资源和 THIRD_PARTY_NOTICES.md；删除 UI 的项目地址不代表删除归属或许可证。

## 四、听视频、队列和速度

这是已有代码的真实缺口：

- Beans/PlayerManager.swift 的 playBilibiliAudio 当前 queue = [song]。
- Beans/BilibiliCiliCiliBridge.swift 当前依据 request.ownerID 是否存在来决定请求作者视频；正常视频都有 ownerID，因此从主页进入也会拉成作者列表。它还只有第 1 页、未保留打开视频的真实列表位置。
- 异步补队列 Task 没有队列会话校验，用户切歌、退出或改模式后可能追加旧结果。
- CiliCili 已解析的音频流没有传到 Beans，Beans 再调用 BilibiliAPI.playbackURLs，先请求 video 再请求播放地址，可能造成重复解析。

请实现明确的播放来源上下文，从“点击哪条列表的哪个视频”传到路由、CiliCili 详情和 Beans 播放器。上下文至少覆盖主页推荐/分区、作者主页、搜索、合集、历史/收藏与相关视频；保留顺序、当前位置、分页游标和列表身份。

从作者页点击就按作者页顺序连播，从主页点击就按主页列表连播；未记录来源时不能仅凭作者 ID 猜来源。初始化上下文队列，不要等作者网络请求回来才允许下一首。分页需追加、去重、保留当前位置，异步结果必须核验 generation/队列 ID，取消过期工作，避免打乱 shuffle/history 或重复请求。

切换到“听视频”使用 Beans 原播放器和 MiniPlayer/PlayerView，音频播放、上/下一首、锁屏遥控统一归 Beans；不要隐藏视频画面后仍然用 CiliCili 的播放器冒充。看视频继续用 CiliCili 播放器。

复用已经解析的音频 URL、备用节点、请求头和播放信息，减少重复请求和等待；处理 URL 过期与登录凭据变化。切换时保留 BVID/CID、分 P、进度、播放/暂停意图、合理的音质和倍速，明确单一播放器所有权，防止双重播放。

从 Beans 切回看视频时要读取 Beans 当前正在播放的视频和进度，不能用已经停止的 CiliCili stablePlayer 的旧进度，也不能跳回最初视频。切换成功后只保留当前拥有者的遥控和生命周期回调。

## 五、直播和重复弹窗

当前 RootView 已使用 shouldHideBeansChrome，但 setLiveRoomActive 只在 CiliCiliRouteHost 的 initialRoute 为 live 时登记。LiveRoomDetailView 本身未登记，所以 CiliCili 首页/动态/UP 等内部导航进入直播可能漏掉隐藏。

将直播详情页所有权登记放在统一的实际详情生命周期中，覆盖全部入口、嵌套导航、退出、交互返回和旋转。直播详情中隐藏 Beans 底栏与迷你播放器，离开后正确恢复；直播列表可保留正常导航栏。iPad 侧栏布局也要检查，不能只修 iPhone TabView。

阅读 VideoDetailView、VideoDetailViewContentResolver、VideoDetailNativeContentTabView、UIKitShell/VideoDetailShellContentView、评论的 CommentsSection/CommentRow/ReplyTarget 等真实实现。基线详情与评论已用 ZStack、opacity、allowsHitTesting、accessibilityHidden 保持挂载，底部刷新/切换/发表工具栏也已存在，保留正确结构。

排查加载期间弹窗重复出现，跟踪 sheet/alert/fullScreenCover/confirmationDialog、onAppear/task/onChange、播放器回调和错误事件，记录复现日志。根据具体根因修复任务幂等、回调所有权、呈现事件消费、错误 ID 与加载会话生命周期；同一失败不能在关闭弹窗后自动重复呈现，新请求和新错误仍需有反馈。不要用延迟、防抖或关闭全部报错来掩盖。

## 六、音源与体积

核对 Beans/Resources/ikun-music-source.js、LXScriptSourceRunner、ThirdPartySourceImportParser、UnblockSourceStore 与 UnblockService。脚本已有 LX User API 的初始化/请求/更新入口，包含 POST JSON、headers、Promise 和平台 musicInfo 标识。验证平台映射、初始化能力、hash/songmid、音质、响应解析、超时取消和最终 AVPlayer 播放，不能只证明脚本可导入。失败要区分宿主适配错误与服务鉴权/额度/服务器问题，真实不可用时不要伪造成功。脚本内的密钥或凭据不要抄进交接说明、测试输出或提交信息。

优化 Release 的实际二进制与资源体积，不减少已有内容、画质和动效。先测量主程序、CiliCiliKit、Assets.car、音源和扩展大小，核对 target membership、重复嵌入、不可达的根壳与调试/性能测试代码、资源重复和 release 符号。project.yml 已有 wholemodule、-O、dead stripping、strip 配置，不要重复加同样开关冒充优化。仅删除源码文件通常不会直接缩小 IPA，要给出可复现的优化前后大小。

## 七、Mac 本地验证与交付

1. 开始先看工作区是否有修改，保留已有正确部分，建立可恢复的本地快照；本源码包没有 .git，不要拿不存在的 Git 状态当阻碍。
2. 检查 Xcode/SDK、XcodeGen、targets/schemes；从 project.yml 生成项目。修改编译配置以 project.yml 为准，避免生成工程和 YAML 不一致。处理已有源码的模块访问级别、MainActor/nonisolated、Sendable、异步取消、SwiftUI 类型检查和 duplicate build files。
3. 先做一次基线编译保存日志，再分块修改和编译。可用基本命令：

   xcodegen generate
   xcodebuild -list -project Beans.xcodeproj
   xcodebuild -project Beans.xcodeproj -scheme Beans -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

   按实际 SDK 选择运行目标。流水线脚本仅供本地参考，不调用 GitHub Actions。
4. 运行 scripts/check-bilibili-protocol.swift 对应的本地协议检查、现有 Beans/CiliCili 测试以及相关 UI 测试。当前 CiliCiliPortUITests 的首页测试要求旧的五个根标签，产品调整后应更新为新的分区、搜索、我的入口验收，不要保留过时断言或删除有效覆盖。
5. 为来源队列、分页过期结果、播放交接和备份合并提供实质测试；在模拟器验证布局，真机验证音频/锁屏/直播与网络行为。验证详情/评论反复切换滚动不丢失、无重复 sheet，点赞/头像子按钮不被整行回复手势吞掉。
6. 完成实际成功的 Release 构建后，把 build/Build/Products/Release-iphoneos 下真实 Beans.app 及已嵌入 framework/extension 打成 Payload ZIP，命名清楚并说明未签名。确认 IPA 内有正确版本、framework 和 extension；不能改文件扩展名就声称构建成功。
7. 将完整修改源码、未签名 IPA、修改清单、本地构建日志和验收结果放到 Mac 桌面。源码包含 project.yml、Beans、Modules、资源/许可证、测试和必要脚本；排除 backend、密钥备份、build、DerivedData 和临时分析工具。不要把反编译 .c 纳入应用 target。
8. 标明确实完成、仅凭证据重建以及仍需真机核验的内容。最后给出桌面源码和 IPA 的准确路径、Xcode/SDK 与构建结果、体积对比和剩余限制。先完成所有可独立执行的工作，不要停在“可以继续”或要求我反复回复继续。

这是一份从旧源码基线恢复和继续开发的任务。不能仅凭反编译资料保证与丢失的 2.0.3 原工程逐行或二进制相同，但需要尽最大可能恢复其功能，并通过实际编译和运行完成交付。
