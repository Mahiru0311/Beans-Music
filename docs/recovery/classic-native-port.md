# Classic 流光原生移植记录

依据：本地 Folia v0.7.16 的 `src/components/visualizer/classic/Visualizer.tsx`、`src/types.ts`、`subtitleFontSizes.ts`。本次没有修改上游 Folia 源码。

## 已接入的行为

| 原版行为 | Swift 实现 |
| --- | --- |
| Classic 独立模式，顺序 30 | `FoliaModeCatalog` + `FoliaStageView` + `PlayerView` 路由；状态为 draft |
| 等待、激活、已唱三态 | `FoliaClassicMotion.state`；正常模式提前 0.15 秒激活，结束点包含在激活区间 |
| 行开始时间 + 词序号的固定布局 | 同一个 sin(seed + index + offset) × 10000 小数部分；时间变化不随机重排 |
| calm / normal / chaotic 强度 | 同样的位移范围、旋转范围、比例和呼吸周期 |
| 旧布局 / 测量后的间距 | `FoliaClassicLayout` 通过 SwiftUI Layout 测量文本，计算缩放溢出及相邻位移补偿 |
| 呼吸的五个关键帧 | 0 → -distance → 0 → distance × 0.45 → 0；周期 8.5 / 7 / 5.8 秒 |
| 旋转、呼吸倍率、旧布局、间距设置 | 独立 AppStorage 键，默认 true / 1 / false / 0.7；进入 Beans WebDAV 备份 |
| 换句进入 / 退出 | 原生 scale、opacity、blur transition；数值采用正常模式的 0.9/10 和 1.1/20 |
| 有翻译优先，否则显示后续两句 | 字符筛选、完成句翻译保持、后续句模糊预告；没有活跃句时不虚构预告 |
| 少动态效果 | 关闭位移、缩放、旋转、呼吸和模糊；保留歌词时间状态 |
| 字素辉光 | 真逐词时间内按 extended grapheme 分段；单字持续，多字扫过并在已唱后 0.9 秒淡出；组合 Emoji 不拆碎 |
| 独立已唱旋转 | passed 旋转用 5 秒线性轨道；缩放、位移、模糊、透明度和颜色各有独立动画修饰符 |

当前逐词驱动读取正在播放的 AVPlayer 时间，30 Hz 更新仅限舞台。缓冲、暂停时停止逐词定时刷新；拖动仍由 Beans 的时钟更新使舞台重算。不使用墙上时钟推算媒体时间。呼吸是独立的装饰动画，可以在暂停时继续，与上游行为一致。

普通 LRC 没有逐词时间轴，显示整句而不构造假逐词时间。原始 Beans 的 YRC / QRC / KRC 数据可以驱动逐词状态。

## 尚未对齐，不能宣称动效完全一致

- 中文 semantic/sticky 布局分组目前仍使用原始词组。
- `renderHints` 的 instant / fast、延长显示结束和特殊换句模式尚未进入原生数据模型。
- 已加入字素辉光和已唱余辉；Beans 模型没有 syllables，音节时间还未接入。UIKit 测量的字形位置和 SwiftUI Text 的连字/字偶距还需对齐。
- 合唱 ripple、关键词着色、主题自定义字体、3D perspective 尚未移植。
- 已拆分旋转和颜色等轨道，仍需录屏确认 SwiftUI 修饰符的插值与 framer 曲线一致。
- Folia VisualizerShell 的音频响应背景不在本批范围内，仍在 F04 / F08。
- 视口布局、字体度量、弹簧插值需在 iPhone / iPad 上与原版录屏对照。

## 已执行的验证

2026-10-14：tree-sitter 检查 1337 个 Swift 文件。Folia 新增文件无语法报告；整个工程保留 13 条报告，分布在 6 个文件，这 6 个文件在用户提供的原始 Beans 源码中也有 parser 报告。**这不是 Swift 编译通过。**

确定性布局的 XCTest 固定样本从上游 JS 公式计算：seed=12.5、index=2、normal，x=6.99277511863329，y=-14.136947649203648，scale=1.1387630607749089。测试还覆盖后退拖动、时间边界、测量溢出间距、呼吸关键帧和字幕标记筛选。

Windows 没有 Xcode，新增 XCTest 未执行。`build-unsigned-ipa.yml` 已纳入上述测试以及现有 Folia timeline / bridge / catalog 测试，尚未提交、推送或触发远程构建。

## Mac 验收

1. XcodeGen 生成工程后，运行 BeansTests 中 `FoliaClassicMotionTests`、`FoliaClassicGlowTests`、`FoliaTimelineTests`、`FoliaBeansLyricBridgeTests`、`FoliaModeCatalogTests` 和 `WebDAVRecoveryTests`。
2. 设置 → Folia → 使用 Folia 舞台 → 流光；检查进入、退出、再次进入和切歌。
3. 用真实逐词歌词向前、向后拖动到 start-0.15 / start / end / end+0.01；停顿后检查翻译与下一句行为。
4. 播放速度 0.5 / 1 / 2 倍、网络缓冲和暂停；歌词必须跟媒体时间一致。
5. 三种动效强度、关闭旋转、呼吸 0/1/2、旧布局、间距 0/0.7/2、减少动态效果；检查重入后参数保留。
6. 手机竖横屏、iPad、长中文 / 英文单词、Emoji、无歌词、纯 LRC；记录字体溢出和帧率。

上述验收通过后仍需要补齐未对齐项，才能将 F02 改为完成。
