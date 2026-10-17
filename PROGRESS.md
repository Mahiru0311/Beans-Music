# 本次恢复进度

当前工程：FoliaBeansNative。2026-10-14。

已写入的能力包括 WebDAV 原生目录、队列和收藏、同名歌词、设置备份；锁屏图片/GIF/视频素材、系统动画封面和 Live Activity 扩展；沉浸详情头部；B 站外观桥和搜索液态表面。详见 TASKS.md，尚未通过 Xcode 编译或 iPhone 真机验收的能力都保留待验收状态。

本次继续加入 Folia Classic（流光）独立 SwiftUI 路径：`FoliaClassicMotion` 负责逐词状态、确定性布局、调节参数和呼吸关键帧，`FoliaClassicRenderer` 负责舞台，`FoliaClassicLayout` 负责原生文本测量后的换行。Still 没有被冒充成 Classic；Classic 目前是已接入的移植初版，尚未声称能成功编译或动效与网页版本完全一致。

流光舞台直接读取 AVPlayer 时间，避免缓冲期间用墙上时钟推进歌词，并保留倍速与拖动的真实时间。舞台歌词文档按歌曲、歌词和时长变化刷新，不在每帧重新解析整个歌词列表。

修复 WebDAV 下载取消和缓存引用保留、旧封面回调覆盖新封面的竞争、锁屏素材预览失败后的引用泄漏、Live Activity 请求失败后不能重试，以及 B 站作者列表异步返回后误追加到新队列的问题。

本轮继续接入 B 站首页、搜索、作者、合集、收藏夹和相关推荐的列表快照。听视频请求带原始顺序和分 P CID；Beans 在列表中间开始播放时保留前后条目。默认听视频的启动分支原先直接返回，现在与手动听/看切换共用播放器交接；异步加载完的列表可以更新队列而不重建 AVPlayer。新增播放快照接口用于切回视频时读取同一个内容的进度及播放意图。分页续载、预解析音频流、详情与 Beans 下一首的双向同步仍待完成，详见 [队列接线记录](docs/recovery/bilibili-listen-context.md)。

流光增加 extended grapheme 辉光扫过、单字持续与已唱余辉，按播放时间重算，拖动时不残留旧时间的状态；减少动态效果关闭辉光。已唱词的旋转单独采用 5 秒线性轨道。语义分组、特殊 renderHints、合唱波纹、自定义字体和真机视觉对齐仍未完成。

2.0.3 主程序和 CiliCiliKit 的哈希已经核对。逆向报告位于 docs/recovery，原始分析证据位于 RecoveryEvidence。新增 Swift 是依据证据重建的实现，不是丢失源码的逐行还原。

Windows 已执行 Swift tree-sitter 语法检查。它只能检查语法结构，不能验证 SDK 类型、链接、签名、运行效果。现有基线中 parser 对上下文关键字、Preview 宏和一处 async 表达式有报告；需与原始基线对照并交给 Xcode 检查，不能用该检查宣称编译成功。

本轮最终扫描 1337 个 Swift 文件，本轮新增文件无语法报告；剩余 13 条报告所在的 6 个文件均已确认在原始 Beans 基线中也有 parser 问题。Classic 的完整已实现/未对齐清单和 Mac 验收步骤见 [移植记录](docs/recovery/classic-native-port.md)。新增 XCTest 还未执行，远程 CI 也未触发。

## 在 Mac 上验证

1. 使用包含 iOS 26.1 SDK 的 Xcode，安装 XcodeGen。
2. 在工程目录运行 `xcodegen generate`。
3. 打开 Beans.xcodeproj，选择 Beans scheme、iPhone 模拟器，先 Build，再运行 BeansTests。
4. 真机安装时给 Beans 和 BeansLiveActivity 配置个人 Team，使用相同 bundle ID 前缀。CiliCiliKit 随 App 签名。
5. 锁屏动态封面必须在支持的系统和设备上确认；系统可能因低电量、减少动态效果等设置使用静态封面。

工程仍保留原基线的版本号 1.8.1（19）和 iOS 26.1 部署目标。这是开发重建版本，不应标成已经复原且验收的 2.0.3。

## 主要验收场景

- WebDAV：中文、空格、百分号文件名；HTTP opt-in；401/403/404；根目录越界与重定向；快速切歌；后台播放；当前播放文件清理保护；备份回读失败和无效 JSON。
- 锁屏：图片、GIF、横竖视频；换封面和快速切歌；素材清理保留正在使用的文件；省电和减少动态效果；Live Activity 不重复创建。
- 详情：歌单、专辑、歌手、本地收藏；大封面和简介展开；壁纸浅深色；关闭沉浸模式。
- B 站：搜索所有分类、作者主页、视频详情及评论区；动态壁纸与玻璃关闭；从各入口进入与返回；与 Beans 音乐播放的锁屏所有权切换。
- Folia Classic：有逐词时间轴和无逐词 LRC 两种输入；拖动到等待/激活/已唱边界；切换平静、标准、强烈；关闭减少动态效果；改动间距、旋转和呼吸参数后重新进入舞台。

Apple 动态封面的 API 依据：[Providing animated artwork for media items](https://developer.apple.com/documentation/mediaplayer/providing-animated-artwork-for-media-items)。
