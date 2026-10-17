# 已完成的源码对照分析

分析日期：2026-10-06。此文件记录检查结果，没有声称源码已重建或已完成 Xcode 编译。

## 源码基线

- 用户提供的 Beans-CiliCili-source.zip 外层只含一个同名 ZIP，内层才是源码。
- project.yml：MARKETING_VERSION 1.8.1、CURRENT_PROJECT_VERSION 19、deploymentTarget iOS 26.1。
- 与本地仓库 commit 2a4a72e 对照，排除 ci-logs/ci-builds 后，CRLF/LF 归一化的 1297 个 Swift/YAML 文件相同，0 个内容变化，0 个新增文件。此结论只涵盖检查过的 Swift/YAML，不代表每一个资源或日志都相同。
- 桌面副本保留上述源码基线，排除 backend、.git、ci-logs、ci-builds；没有覆盖原源码包和旧仓库，没有推送或发布。

## IPA 与缺失功能

- 输入成品是 2.0.3 build 2，Bundle ID com.beans.app，MinimumOSVersion 15.0。
- 无 FairPlay 加密，无 DWARF；主程序 678 个类型记录，CiliCiliKit 2190 个类型记录，后者 5 个元数据解析异常。
- 41 个包内源文件路径中，基线没有 BeansCacheManagement.swift、BeansDiagnosticInstrumentation.swift、FavoriteDetailSwipeBack.swift、LyricDebugOverlay.swift、WebDAVView.swift。路径存在不等于可以恢复该文件完整内容。
- WebDAV 的类型、字段和页面状态可在 RecoveryEvidence/Beans/swift-types.json 查到。SongSource 新增 webdav、Song 新增 webDAV 字段也是直接元数据证据。
- Ghidra 首次自动分析达到时间上限；之后通过 ARM64 ADRP/ADD 字符串加载指令定位，导出 24 个重点函数伪代码。不是全程序高层反编译，也未完成可编译 Swift 重建。

## 真实入口及已实现部分

| 功能 | 实际代码位置 | 现状 |
| --- | --- | --- |
| 哔哩哔哩主页 | Beans/DiscoverView.swift；Integration/CiliCiliRuntime.swift；App/RootTabView.swift | 走 CiliCiliHomeView 和 CiliCili HomeViewModel，不走 Beans/BilibiliHomePage |
| 主页双列 | Sources/Storage/LibraryStore.swift | defaultHomeFeedLayout 已为 doubleColumn，需检查旧偏好与实际展示 |
| Beans 的 B 站搜索 | Beans/SearchView.swift；Beans/BilibiliHomePage.swift | 搜索被替换为另一整页，旧搜索的 startSearch/searchPlaylistTab 存在提前返回 |
| B 站我的与登录 | Features/Mine/MineContentView.swift；Beans/BilibiliLoginSheet.swift | 我的已含听/看选择；登录入口却直接打开完整 .account 路由 |
| 详情与评论 | Features/VideoDetail/VideoDetailNativeContentTabView.swift 等 | ZStack 两页保持挂载、刷新/切换/发表工具栏已经存在 |
| Beans 听视频 | Beans/BilibiliCiliCiliBridge.swift；PlayerManager.swift | 已有外部播放桥，来源和队列链路不完整 |
| 直播底栏 | CiliCiliRouteHost.swift；LiveRoomDetailView.swift；Beans/RootView.swift | 仅 initialRoute 为 live 的 host 登记，内部进入详情有覆盖缺口 |
| 主题 | CiliCiliEnvironment；MineView.swift | 独立 LibraryStore.tint/字号与不透明背景，尚未统一 Beans 主题桥 |
| 音源 | Beans/Resources/ikun-music-source.js；LXScriptSourceRunner.swift | 脚本与适配环境已经存在，仍需验证真实音乐 URL 解析和播放 |

表中 Integration/App/Features/Storage 的相对位置均在 Modules/CiliCili 下，详见实施指令。

## 已定位的听视频问题

playBilibiliAudio 初始化单首队列；桥接按视频 ownerID 拉第 1 页作者视频，没有保留来源列表。正常视频都有作者，故不能区分主页与作者页。后台 Task 无队列身份校验，会有过期结果追加风险。详情已解析的音频流没有传给 Beans，Beans 再走 BilibiliAPI.playbackURLs 的 video/play URL 请求链。以上为代码链路发现，不是已完成的设备性能测量。

## 在本机未做的工作

未修改 Swift/YAML 产品代码，未执行 Xcode 编译或设备验收，未生成新的 IPA。桌面交付的是原始基线源码、分析证据和实施指令，供 Mac 上直接继续。
