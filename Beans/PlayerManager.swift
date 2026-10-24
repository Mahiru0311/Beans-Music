import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

enum PlayMode: String, CaseIterable, Identifiable {
    case sequential
    case repeatAll
    case repeatOne
    case shuffle

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sequential: return "arrow.right"
        case .repeatAll: return "repeat"
        case .repeatOne: return "repeat.1"
        case .shuffle: return "shuffle"
        }
    }

    var title: String {
        switch self {
        case .sequential: return "顺序播放"
        case .repeatAll: return "列表循环"
        case .repeatOne: return "单曲循环"
        case .shuffle: return "随机播放"
        }
    }
}

/// 播放器编辑页显示时暂停底层播放器的高频渲染，音频引擎和实时预览继续运行。
final class PlaybackRenderGate {
    static let shared = PlaybackRenderGate()

    private var suppressionDepth = 0

    private init() {}

    var isSuppressed: Bool {
        suppressionDepth > 0
    }

    func beginSuppression() {
        suppressionDepth += 1
    }

    func endSuppression() {
        suppressionDepth = max(0, suppressionDepth - 1)
    }
}

final class PlaybackClock: ObservableObject {
    @Published private(set) var progress: Double = 0
    @Published private(set) var duration: Double = 0

    func update(progress: Double? = nil, duration: Double? = nil) {
        let apply = {
            if let progress, abs(progress - self.progress) > 0.01 {
                self.progress = progress
            }
            if let duration, abs(duration - self.duration) > 0.01 {
                self.duration = duration
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}

final class PlayerManager: NSObject, ObservableObject {
    @Published var queue: [Song] = []
    @Published var currentIndex = 0
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var loadFailed = false
    /// 切歌代次：防止旧歌的 URL 解析任务覆盖新歌（快速切歌时）
    private var loadGeneration = 0
    private var playbackLoadTask: Task<Void, Never>?
    let clock = PlaybackClock()
    var progress: Double = 0 {
        didSet { clock.update(progress: progress) }
    }
    var duration: Double = 0 {
        didSet { clock.update(duration: duration) }
    }
    @Published var playMode: PlayMode = .sequential {
        didSet {
            guard oldValue != playMode else { return }
            defaults.set(playMode.rawValue, forKey: playModeKey)
        }
    }
    @Published var rate: Double = 1.0
    /// Beans 自身的播放音量，不改变系统音量，方便和其他音频应用混合播放。
    @Published var softwareVolume: Double = 1.0 {
        didSet {
            let clamped = min(max(softwareVolume, 0), 1)
            if softwareVolume != clamped {
                softwareVolume = clamped
                return
            }
            defaults.set(clamped, forKey: softwareVolumeKey)
            player?.volume = Float(clamped)
        }
    }
    @Published var sleepTimerEndsAt: Date?
    @Published var sleepTimerRemaining: Int = 0
    /// 播放当前歌曲自然结束后停止，不受当前播放模式影响。
    @Published var stopAfterCurrentSong = false
    @Published var history: [Song] = []
    @Published var playCounts: [String: Int] = [:]
    /// 仅在 AVPlayer 实际输出音频时累积，不包含暂停、缓冲和拖动进度的跳变。
    @Published private(set) var listeningDuration: TimeInterval = 0
    /// 每次用户主动拖动进度或点击歌词都会递增，歌词视图据此立即重新定位。
    @Published private(set) var seekRevision = 0
    /// 歌词统一使用的播放游标，和播放器时间观察器使用同一个时间源。
    /// 高频游标不再触发整个播放器模型发布，由 PlaybackClock 驱动进度条与歌词局部刷新。
    private(set) var lyricProgress: Double = 0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var equalizerSettingsObserver: NSObjectProtocol?
    private var customCoverObserver: NSObjectProtocol?
    private var playbackConfirmed = false
    private var pendingThirdPartyVIPNotice: ThirdPartyVIPNotice?
    private var sessionConfigured = false
    private var systemPlaybackPrepared = false
    private var routeObserverInstalled = false
    private var interruptionObserverInstalled = false
    private var secondaryAudioHintObserverInstalled = false
    private var mediaServicesObserverInstalled = false
    private var applicationAudioObserverInstalled = false
    private var applicationIsInBackground = false
    private var remoteCommandsInstalled = false
    private var playOrder: [Int] = []
    private var orderPosition = 0
    private var sleepTimer: Timer?
    // 常听计数口径（2026-10-23 用户定“要实时、不要假动态数”后改）：
    // 原先是 lastCountedSongID：同一首歌一旦计过、在换歌前再怎么重播都不再计，
    // 单曲循环重播、点同一首歌重播都卡在 1 次，看起来就是数不动的假数。
    // 现在按每次真实播放的 load 计一次：setupPlayer 成功开播时，若当前 load 还没
    // 计过就 +1；失败重载会换 loadGeneration，失败那次本来就没计过，不会重复计；
    // 单曲循环自然结束重播走 restartCurrent，那里单独计一次（不走 setupPlayer）。
    private var countedLoadGeneration: Int?
    /// 计过数的歌本身（按 identityKey 存）：常听榜单以前只从 history 里找歌，
    /// history 上限 50 首，计过很多次的老歌滚出 50 首后榜单就掉了、但总数还在，
    /// 数和列表对不上；现在榜单从这里找歌，不再被 history 上限挤掉。
    private var countedSongs: [String: Song] = [:]
    private var wasPlayingBeforeInterruption = false
    private var interruptionInProgress = false
    private var interruptionResumeWorkItem: DispatchWorkItem?
    private var audioRecoveryWorkItem: DispatchWorkItem?
    private var audioSessionWatchdogTimer: Timer?
    private var shouldResumeAfterAudioLoss = false
    private var audioLossInProgress = false
    private var lastNowPlayingRefreshUptime = 0.0
    private var lastPublishedProgress: Double = -1
    private var lastPersistedProgress: Double = -1
    private var lastListeningProgress: Double?
    private var lastListeningSongKey: String?
    private var pendingListeningDuration: TimeInterval = 0
    /// 单调时钟记录当前实际播放片段，不依赖歌曲进度，避免拖动/切歌放大统计。
    private var listeningSegmentStartedUptime: TimeInterval?
    private var lastListeningPublishUptime = 0.0
    /// Encode and persist playback snapshots away from the main thread.
    private let playbackPersistenceQueue = DispatchQueue(
        label: "Co.PlayerManager.playback-persistence",
        qos: .utility
    )
    private var lastNowPlayingArtworkKey: String?
    private var nowPlayingSongKey: String?
    private var nowPlayingInfo: [String: Any] = [:]
    /// 酷狗高音质地址在部分账号/系统上会返回但无法由 AVPlayer 打开；每首歌只自动降级一次。
    private var kugouStandardFallbackSongKey: String?
    /// 第三方地址偶发过期或节点不可用时，按失败域名重试，避免同一节点反复进入播放器。
    private var thirdPartyRetryExcludedHostsBySong: [String: Set<String>] = [:]
    /// 记录已经交给 AVPlayer 的第三方音质，失败后选择下一个更低档位。
    private var attemptedThirdPartyQualitiesBySong: [String: Set<String>] = [:]
    private var activeThirdPartyQuality: ThirdPartyAudioQuality?
    /// 记录 QQ 官方 vkey 已经尝试过的 BR，官方地址实际打不开时继续换档位。
    private var attemptedQQOfficialBRsBySong: [String: Set<String>] = [:]
    private var activeQQOfficialBR: String?
    /// KVO 与 AVPlayerItemFailedToPlayToEndTime 可能同时报告同一次失败。
    private var playbackRecoveryInFlightSongKey: String?
    /// 同一首歌的多个 AVFoundation 失败回调只允许弹一次提示并自动切歌一次。
    private var finalizedFailureSongKey: String?
    /// 播放失败后安排到下一个主线程周期切歌，避免 AVFoundation 回调中同步重入。
    private var failureAutoSkipWorkItem: DispatchWorkItem?
    /// QQ 官方地址返回成功但实际不可播放时，只切换到第三方一次，避免官方/第三方之间循环。
    private var qqThirdPartyFallbackSongKey: String?
    private var playbackConfirmationWorkItem: DispatchWorkItem?
    private var playbackStallWorkItem: DispatchWorkItem?
    private var thirdPartyPrefetchTask: Task<Void, Never>?
    private static let nowPlayingArtworkCache = NSCache<NSURL, UIImage>()

    private let historyKey = "co.history"
    private let countsKey = "co.playcounts"
    private let countedSongsKey = "co.playcounts.songs.v1"
    private let playbackStateKey = "co.player.playbackState.v1"
    private let audioMixKey = "co.audio.mixothers.v1"
    private let nowPlayingEnabledKey = "co.nowPlaying.enabled.v1"
    private let playModeKey = "co.player.playMode"
    private let softwareVolumeKey = "co.player.softwareVolume.v1"
    private let autoSkipOnFailureKey = "co.playback.autoSkipOnFailure"
    static let autoCrossPlatformFallbackKey = "co.playback.autoCrossPlatformFallback"
    static let playbackSourcePreferenceKey = PlaybackSourcePreference.storageKey
    static let listeningDurationKey = "co.playback.listeningDuration.v1"
    private static let listeningPlayCountOffsetKey = "co.playback.listeningPlayCountOffset.v1"
    private let autoResumeLastPlaybackKey = "co.playback.autoResumeLast"
    private let thirdPartyVIPNoticeKey = "co.showThirdPartyVIPNotice"
    private let defaults = UserDefaults.standard
    private var didAttemptAutoResume = false
    /// 当前故障恢复链已尝试的平台，避免不同平台间反复切换同一首歌曲。
    private var crossPlatformFallbackOriginKey: String?
    private var crossPlatformFallbackTriedSources = Set<String>()
    private var crossPlatformFallbackInFlightSongKey: String?

    static var storedListeningDuration: TimeInterval {
        max(0, UserDefaults.standard.double(forKey: listeningDurationKey))
    }

    static var storedPlayCount: Int {
        storedLocalPlayCount + max(0, UserDefaults.standard.integer(forKey: listeningPlayCountOffsetKey))
    }

    private static var storedLocalPlayCount: Int {
        guard let data = UserDefaults.standard.data(forKey: "co.playcounts"),
              let counts = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return 0
        }
        return counts.values.reduce(0, +)
    }


    var totalPlayCount: Int {
        playCounts.values.reduce(0, +)
            + max(0, defaults.integer(forKey: Self.listeningPlayCountOffsetKey))
    }

    var formattedListeningDuration: String {
        Self.formatListeningDuration(listeningDuration)
    }

    static func formatListeningDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        if days > 0 { return "\(days) 天 \(hours) 小时 \(minutes) 分钟" }
        if hours > 0 { return "\(hours) 小时 \(minutes) 分钟" }
        return "\(minutes) 分钟"
    }

    private var externalSourcesEnabled: Bool { false }

    private struct ThirdPartyVIPNotice {
        let songKey: String
        let message: String
    }

    private enum PlaybackFailureCategory {
        case membership
        case network
        case sourceUnavailable
        case unsupportedFormat
        case thirdPartyUnavailable
        case unknown
    }

    private struct PersistedPlaybackState: Codable {
        let queue: [Song]
        let currentIndex: Int
        let progress: Double
        let duration: Double
        let savedAt: Date
    }

    var currentSong: Song? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    /// 当前实际播放顺序中、当前歌曲之后尚未播放的项目。
    /// 随机模式使用内部随机顺序，而不是原始队列顺序。
    var upcomingQueue: [(index: Int, song: Song)] {
        guard !queue.isEmpty else { return [] }
        let indices: [Int]
        if playMode == .shuffle, !playOrder.isEmpty {
            let nextPosition = min(orderPosition + 1, playOrder.count)
            indices = Array(playOrder.dropFirst(nextPosition))
        } else {
            indices = Array(queue.indices.dropFirst(min(currentIndex + 1, queue.count)))
        }
        return indices.compactMap { index in
            guard queue.indices.contains(index) else { return nil }
            return (index, queue[index])
        }
    }

    /// 当前歌曲实际拿到的音质档位键（hires/lossless/exhigh/standard），
    /// 由 KugouMusicAPI 回传的 hash 键推断；主 hash 或网页兜底拿到时为 nil，
    /// 此时播放页诚实显示偏好名，不编一个档位。
    @Published var actualAudioQualityKey: String? = nil

    override init() {
        NetworkAudioQuality.migrateConnectionAwareIfNeeded()
        super.init()
        softwareVolume = min(max(defaults.object(forKey: softwareVolumeKey) as? Double ?? 1.0, 0), 1)
        // Ensure a stale auxiliary-audio category cannot carry a previous mix
        // preference into the first playback after relaunch.
        sessionConfigured = Self.applyAudioMixPreference(mixesWithOthers, activate: false)
        if let raw = defaults.string(forKey: playModeKey),
           let saved = PlayMode(rawValue: raw) {
            playMode = saved
        }
        loadHistory()
        loadPlayCounts()
        // 恢复播放队列后，再用队列里的歌补一次 countedSongs：上次播过的歌
        // 很可能就在队列里，历史被清空时这一步能救回一部分歌名，救不回的
        // 仍走 orphanPlayCount 聚合显示，不编假歌。
        restorePersistedPlaybackState()
        var queueRecovered = false
        for song in queue where countedSongs[song.identityKey] == nil && playCounts[song.identityKey] != nil {
            countedSongs[song.identityKey] = song
            queueRecovered = true
        }
        if queueRecovered, let data = try? JSONEncoder().encode(countedSongs) {
            defaults.set(data, forKey: countedSongsKey)
        }
        listeningDuration = Self.storedListeningDuration
        lastListeningPublishUptime = ProcessInfo.processInfo.systemUptime
        // 播放队列恢复已移到上面（loadPlayCounts 之后），这里不再重复恢复，
        // 避免同一份持久化状态读两遍。
        equalizerSettingsObserver = NotificationCenter.default.addObserver(
            forName: CoEqualizer.settingsDidChange,
            object: CoEqualizer.shared,
            queue: .main
        ) { [weak self] _ in
            self?.applyEqualizerToCurrentItem()
        }
        customCoverObserver = NotificationCenter.default.addObserver(
            forName: .coCustomSongCoverDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }

    deinit {
        playbackLoadTask?.cancel()
        flushListeningDuration()
        interruptionResumeWorkItem?.cancel()
        audioRecoveryWorkItem?.cancel()
        audioSessionWatchdogTimer?.invalidate()
        if let equalizerSettingsObserver {
            NotificationCenter.default.removeObserver(equalizerSettingsObserver)
        }
        if let customCoverObserver {
            NotificationCenter.default.removeObserver(customCoverObserver)
        }
    }

    /// 在首帧之后恢复轻量播放偏好，避免安装后启动阶段触碰系统媒体服务。
    func restorePersistedPlayMode() {
        guard let raw = defaults.string(forKey: playModeKey),
              let saved = PlayMode(rawValue: raw) else { return }
        guard playMode != saved else { return }
        playMode = saved
        if !queue.isEmpty {
            buildPlayOrder()
        }
    }

    // MARK: - 播放控制

    func play(songs: [Song], startAt index: Int = 0) {
        guard !songs.isEmpty else { return }
        guard ensurePlaybackAllowed() else { return }
        queue = songs
        buildPlayOrder()
        jumpToOrderPosition(min(max(index, 0), songs.count - 1))
    }

    /// 由哔哩哔哩“听视频”模式复用 Beans 音频播放器，保留当前详情页的续播时间和播放意图。
    // Apply a resolved list without replacing the AVPlayer or losing its playhead.
    /// 追加后台继续加载的私人漫游歌曲，不打断当前歌曲或重置播放位置。
    func append(songs newSongs: [Song]) {
        guard !newSongs.isEmpty else { return }
        let existing = Set(queue.map(\.identityKey))
        let additions = newSongs.filter { !existing.contains($0.identityKey) }
        guard !additions.isEmpty else { return }
        queue.append(contentsOf: additions)
        buildPlayOrder()
        savePersistedPlaybackState()
    }


    /// 插队播放：把歌曲放到当前歌曲之后，不打断当前播放
    func playNext(_ song: Song) {
        guard !queue.isEmpty else {
            play(songs: [song], startAt: 0)
            return
        }
        let insertAt = currentIndex + 1
        queue.insert(song, at: min(insertAt, queue.count))
        switch playMode {
        case .shuffle:
            playOrder = playOrder.map { $0 >= insertAt ? $0 + 1 : $0 }
            let nextOrderPosition = min(orderPosition + 1, playOrder.count)
            playOrder.insert(min(insertAt, queue.count - 1), at: nextOrderPosition)
        default:
            buildPlayOrder()
        }
        savePersistedPlaybackState()
        Task { @MainActor in
            ToastCenter.shared.show("已加入下一首播放")
        }
    }

    /// 可选地恢复上次退出时的歌曲并立即播放，只在每次应用启动时执行一次。
    func resumePersistedPlaybackIfEnabled() {
        guard !didAttemptAutoResume else { return }
        didAttemptAutoResume = true
        guard defaults.object(forKey: autoResumeLastPlaybackKey) as? Bool ?? false,
              currentSong != nil else { return }
        loadCurrent(resumeAt: progress)
    }

    func togglePlayPause() {
        guard ensurePlaybackAllowed() else { return }
        guard let player else {
            guard currentSong != nil else { return }
            loadCurrent(resumeAt: progress)
            return
        }
        if player.timeControlStatus == .playing {
            clearAudioRecoveryIntent()
            isPlaying = false
            player.pause()
            stopListeningSegment()
            resetListeningProgress()
            stopAudioSessionWatchdog()
        } else {
            clearAudioRecoveryIntent()
            player.playImmediately(atRate: Float(rate))
            isPlaying = true
            startListeningSegment()
            startAudioSessionWatchdogIfNeeded()
        }
        savePersistedPlaybackState()
        updateNowPlaying()
    }

    func next(manual: Bool = true) {
        guard ensurePlaybackAllowed() else { return }
        guard !queue.isEmpty else { return }
        // 单曲循环只影响自然播放结束；用户手动点击下一首时始终切换歌曲。
        advance()
        loadCurrent()
    }

    func previous() {
        guard ensurePlaybackAllowed() else { return }
        guard !queue.isEmpty else { return }
        // 直接切换到上一首（不再做“播放超过 3 秒先重头播放”的判断）
        if playMode == .shuffle {
            orderPosition = (orderPosition - 1 + playOrder.count) % playOrder.count
            currentIndex = playOrder[orderPosition]
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
        }
        resetCrossPlatformFallbackState()
        loadCurrent()
    }

    func seek(to seconds: Double) {
        // 与播放器的歌词游标保持同一套逻辑：以用户指定的时间立即更新，
        // 不等待 AVPlayer 回调，也不使用回调中的旧 currentTime 覆盖目标位置。
        let clamped = max(0, min(seconds, max(duration, currentSong?.duration ?? seconds)))
        progress = clamped
        lyricProgress = clamped
        resetListeningProgress()
        seekRevision &+= 1
        player?.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        updateNowPlaying()
        savePersistedPlaybackState()
    }

    /// 歌词点击专用的精确跳转。
    /// 保持 AVPlayer 的当前播放意图，避免连续点歌词时上一笔跳转留下暂停状态。
    func seekPrecisely(to seconds: Double) {
        let knownDuration = max(duration, currentSong?.duration ?? seconds)
        let target = knownDuration > 0
            ? max(0, min(seconds, knownDuration))
            : max(0, seconds)
        let shouldKeepPlaying = isPlaying || player?.timeControlStatus == .playing
        let seekSongKey = currentSong?.identityKey
        seekRevision &+= 1
        let revision = seekRevision
        progress = target
        lyricProgress = target
        resetListeningProgress()
        player?.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            guard finished else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.currentSong?.identityKey == seekSongKey,
                      self.seekRevision == revision else { return }
                self.progress = target
                self.lyricProgress = target
                self.lastPublishedProgress = target
                if shouldKeepPlaying {
                    self.player?.playImmediately(atRate: Float(self.rate))
                    self.isPlaying = true
                    self.startListeningSegment()
                }
                self.updateNowPlaying()
                self.savePersistedPlaybackState()
                self.seekRevision &+= 1
            }
        }
        updateNowPlaying()
    }

    func seekBy(_ delta: Double) {
        seek(to: progress + delta)
    }

    func togglePlayMode() {
        switch playMode {
        case .sequential: playMode = .repeatAll
        case .repeatAll: playMode = .repeatOne
        case .repeatOne: playMode = .shuffle
        case .shuffle: playMode = .sequential
        }
        buildPlayOrder()
    }

    func setPlayMode(_ mode: PlayMode) {
        playMode = mode
        buildPlayOrder()
    }

    func setRate(_ newRate: Double) {
        rate = newRate
        if isPlaying {
            player?.playImmediately(atRate: Float(newRate))
        }
        updateNowPlaying()
    }

    func playQueueIndex(_ index: Int) {
        guard ensurePlaybackAllowed() else { return }
        guard queue.indices.contains(index) else { return }
        jumpToOrderPosition(index)
    }

    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index), queue.count > 1 else { return }
        let removedID = queue[index].id
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            currentIndex = min(currentIndex, queue.count - 1)
            loadCurrent()
        }
        buildPlayOrder(avoiding: removedID)
        savePersistedPlaybackState()
    }

    /// Move one queue item while keeping the current song and shuffle order
    /// pointing at the same songs.
    func moveQueueItem(from source: Int, to destination: Int, persist: Bool = true) {
        guard queue.indices.contains(source), queue.indices.contains(destination), source != destination else { return }
        let oldQueue = queue
        let currentSongID = currentSong?.identityKey
        let shuffleSongIDs = playOrder.compactMap { oldQueue.indices.contains($0) ? oldQueue[$0].identityKey : nil }

        var reordered = oldQueue
        let moved = reordered.remove(at: source)
        let insertionIndex = min(max(destination, 0), reordered.count)
        reordered.insert(moved, at: insertionIndex)
        queue = reordered

        if let currentSongID, let newCurrentIndex = queue.firstIndex(where: { $0.identityKey == currentSongID }) {
            currentIndex = newCurrentIndex
        } else {
            currentIndex = min(currentIndex, max(0, queue.count - 1))
        }

        if playMode == .shuffle {
            playOrder = shuffleSongIDs.compactMap { id in
                queue.firstIndex(where: { $0.identityKey == id })
            }
            orderPosition = playOrder.firstIndex(of: currentIndex) ?? 0
        } else {
            playOrder = Array(queue.indices)
            orderPosition = currentIndex
        }
        if persist { savePersistedPlaybackState() }
    }

    /// 按播放列表当前显示顺序移动“接下来播放”的歌曲。
    /// 顺序播放直接调整队列；随机播放只调整当前歌曲之后的随机顺序，
    /// 不重新洗牌，也不会改变当前歌曲和已经播放过的歌曲。
    func moveUpcomingQueueItem(from sourcePosition: Int, to destinationPosition: Int, persist: Bool = true) {
        let upcoming = upcomingQueue
        guard upcoming.indices.contains(sourcePosition), !upcoming.isEmpty else { return }
        let destination = min(max(destinationPosition, 0), upcoming.count - 1)
        guard sourcePosition != destination else { return }

        if playMode == .shuffle {
            let nextStart = min(orderPosition + 1, playOrder.count)
            var future = Array(playOrder.dropFirst(nextStart))
            guard future.indices.contains(sourcePosition), future.indices.contains(destination) else { return }
            let moved = future.remove(at: sourcePosition)
            future.insert(moved, at: destination)
            objectWillChange.send()
            playOrder = Array(playOrder.prefix(nextStart)) + future
            orderPosition = playOrder.firstIndex(of: currentIndex) ?? max(0, nextStart - 1)
            if persist { savePersistedPlaybackState() }
        } else {
            moveQueueItem(from: upcoming[sourcePosition].index, to: upcoming[destination].index, persist: persist)
        }
    }

    func finishUpcomingQueueReorder() {
        savePersistedPlaybackState()
    }

    func retryCurrent() {
        guard ensurePlaybackAllowed() else { return }
        loadFailed = false
        resetCrossPlatformFallbackState()
        // 换音质 / 开关不断歌：从当前进度续播；暂停时保持暂停，缓冲中按播放处理。
        let time = player?.currentTime().seconds ?? 0
        let resume = time.isFinite ? max(0, time) : 0
        loadCurrent(resumeAt: resume, autoplay: isPlaying || isBuffering)
    }

    /// 删除单条播放历史（含持久化）
    func removeHistory(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard history.indices.contains(index) else { continue }
            history.remove(at: index)
        }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    /// 清空播放历史（含持久化）
    func clearHistory() {
        history.removeAll()
        defaults.removeObject(forKey: historyKey)
    }

    /// 清空队列，仅保留当前歌曲
    func clearQueue() {
        guard !queue.isEmpty else { return }
        if let current = currentSong {
            queue = [current]
            currentIndex = 0
        } else {
            queue = []
            currentIndex = 0
        }
        buildPlayOrder()
        savePersistedPlaybackState()
    }

    // MARK: - 睡眠定时

    func startSleepTimer(minutes: Int) {
        stopSleepTimer()
        sleepTimerEndsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerRemaining = minutes * 60
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let end = self.sleepTimerEndsAt else { return }
            let remain = Int(end.timeIntervalSinceNow)
            self.sleepTimerRemaining = max(0, remain)
            if remain <= 0 {
                self.stopSleepTimer()
                self.pausePlayback()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        sleepTimer = timer
    }

    func stopSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndsAt = nil
        sleepTimerRemaining = 0
    }

    var sleepTimerFormatted: String? {
        guard sleepTimerRemaining > 0 else { return nil }
        return String(format: "%d:%02d", sleepTimerRemaining / 60, sleepTimerRemaining % 60)
    }

    private func pausePlayback() {
        clearAudioRecoveryIntent()
        isPlaying = false
        player?.pause()
        stopListeningSegment()
        stopAudioSessionWatchdog()
        updateNowPlaying()
    }

    // Read the AVPlayer clock on visible lyric frames; wall-clock extrapolation
    // would advance during buffering and ignore playback speed changes.
    @MainActor
    func currentPlaybackTime() -> Double {
        guard !isBuffering, let time = player?.currentTime().seconds, time.isFinite else { return progress }
        return max(0, time)
    }

    // Bridges can reject asynchronous queue additions after a new load/ownership change.
    var queueContextRevision: Int { loadGeneration }

    // MARK: - 播放顺序

    private func buildPlayOrder(avoiding removedID: Int? = nil) {
        switch playMode {
        case .shuffle:
            var indices = Array(queue.indices).filter { $0 != removedID }
            indices.shuffle()
            playOrder = indices
            orderPosition = 0
        default:
            playOrder = Array(queue.indices)
            orderPosition = currentIndex
        }
    }

    private func advance() {
        resetCrossPlatformFallbackState()
        switch playMode {
        case .shuffle:
            guard !playOrder.isEmpty else { return }
            orderPosition = (orderPosition + 1) % playOrder.count
            currentIndex = playOrder[orderPosition]
        default:
            currentIndex = (currentIndex + 1) % queue.count
            orderPosition = currentIndex
        }
    }

    private func jumpToOrderPosition(_ index: Int) {
        resetCrossPlatformFallbackState()
        currentIndex = index
        if playMode == .shuffle {
            orderPosition = 0
            if let pos = playOrder.firstIndex(of: index) {
                orderPosition = pos
            }
        } else {
            orderPosition = index
        }
        loadCurrent()
    }

    // MARK: - 播放

    private func restartCurrent() {
        guard ensurePlaybackAllowed() else { return }
        seek(to: 0)
        player?.playImmediately(atRate: Float(rate))
        isPlaying = true
        startListeningSegment()
        updateNowPlaying()
        // 单曲循环自然结束重播：不走 setupPlayer，这里单独计一次，否则循环听
        // 一整天常听也只涨 1 次，看起来就是数不动的假数。
        if let song = currentSong {
            bumpPlayCount(song)
            countedLoadGeneration = loadGeneration
        }
    }

    private func loadCurrent(
        resumeAt: Double? = nil,
        forceKugouStandard: Bool = false,
        autoplay: Bool = true
    ) {
        guard ensurePlaybackAllowed() else { return }
        guard let song = currentSong else { return }
        playbackLoadTask?.cancel()
        playbackLoadTask = nil
        audioRecoveryWorkItem?.cancel()
        audioRecoveryWorkItem = nil
        stopAudioSessionWatchdog()
        clearAudioRecoveryIntent()
        loadGeneration += 1
        let generation = loadGeneration
        actualAudioQualityKey = nil
        thirdPartyRetryExcludedHostsBySong.removeValue(forKey: song.identityKey)
        attemptedThirdPartyQualitiesBySong.removeValue(forKey: song.identityKey)
        attemptedQQOfficialBRsBySong.removeValue(forKey: song.identityKey)
        activeThirdPartyQuality = nil
        activeQQOfficialBR = nil
        playbackRecoveryInFlightSongKey = nil
        finalizedFailureSongKey = nil
        failureAutoSkipWorkItem?.cancel()
        failureAutoSkipWorkItem = nil
        playbackStallWorkItem?.cancel()
        playbackStallWorkItem = nil
        thirdPartyPrefetchTask?.cancel()
        thirdPartyPrefetchTask = nil
        qqThirdPartyFallbackSongKey = nil
        stopListeningSegment()
        flushListeningDuration()
        resetListeningProgress()
        let initialProgress = max(0, min(resumeAt ?? 0, max(song.duration, 0)))
        // 切歌时同时解除旧 item，避免旧音频在新播放器建立期间残留输出。
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        duration = song.duration
        progress = initialProgress
        lyricProgress = initialProgress
        isPlaying = false
        isBuffering = true
        loadFailed = false
        pushHistory(song)
        savePersistedPlaybackState()
        guard song.source == .kugou else {
            isBuffering = false
            loadFailed = true
            finishUnrecoverablePlaybackFailure(song: song, reason: "酷狗专版仅支持酷狗歌曲")
            return
        }
        Task {
            var urlString: String?
            let quality = forceKugouStandard ? CoAudioQuality.standard : NetworkAudioQuality.officialPreferred
            for attempt in 0..<3 {
                if attempt > 0 {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    if Task.isCancelled { return }
                }
                guard generation == self.loadGeneration else { return }
                let resolved = try? await KugouMusicAPI.shared.songURLWithActual(song: song, quality: quality)
                urlString = resolved?.url
                await MainActor.run {
                    guard generation == self.loadGeneration else { return }
                    self.actualAudioQualityKey = resolved?.actualKey
                }
                if urlString != nil { break }
            }
            guard let urlString, let url = URL(string: urlString) else {
                await MainActor.run {
                    guard generation == self.loadGeneration else { return }
                    self.isBuffering = false
                    self.loadFailed = true
                    let reason = "解析播放地址失败"
                    let failureMessage = coLocalized(
                        "播放失败：\(self.playbackFailureMessage(for: song, reason: reason))",
                        "Playback failed: \(self.playbackFailureMessage(for: song, reason: reason, english: true))"
                    )
                    self.finishUnrecoverablePlaybackFailure(
                        song: song,
                        reason: reason,
                        message: failureMessage
                    )
                }
                return
            }
            await MainActor.run {
                guard generation == self.loadGeneration else { return }
                self.setupPlayer(
                    url: url,
                    resumeAt: initialProgress,
                    autoplay: autoplay
                )
            }
        }
    }


    /// 在网易云按 歌名+歌手 匹配同名歌曲（QQ vkey 失败时的免费播放兜底）
    /// 仅在高音质地址已经交给 AVPlayer 但实际无法打开时回退标准音质。
    /// 这样正常账号仍优先使用高音质，兼容部分旧系统或账号返回的不可解码资源。
    @discardableResult
    private func retryKugouAtStandardIfNeeded(error _: Error?) -> Bool {
        guard let song = currentSong,
              song.source == .kugou,
              PlaybackSourcePreference.current != .thirdParty,
              NetworkAudioQuality.officialPreferred != .standard,
              kugouStandardFallbackSongKey != song.identityKey else { return false }
        kugouStandardFallbackSongKey = song.identityKey
        let resume = progress
        loadCurrent(resumeAt: resume, forceKugouStandard: true)
        return true
    }

    private func setupPlayer(
        url: URL,
        thirdPartyVIPNotice: ThirdPartyVIPNotice? = nil,
        resumeAt: Double = 0,
        autoplay: Bool = true,
        isThirdParty: Bool = false,
        thirdPartyQuality: ThirdPartyAudioQuality? = nil,
        qqOfficialBR: String? = nil,
        attemptedQQOfficialBRs: [String] = []
    ) {
        guard ensurePlaybackAllowed(), let loadedSong = currentSong else { return }
        if isThirdParty {
            let quality = thirdPartyQuality ?? NetworkAudioQuality.thirdPartyPreferred
            activeThirdPartyQuality = quality
            activeQQOfficialBR = nil
            if let songKey = currentSong?.identityKey {
                attemptedThirdPartyQualitiesBySong[songKey, default: []].insert(quality.rawValue)
            }
        } else {
            activeThirdPartyQuality = nil
            activeQQOfficialBR = qqOfficialBR
            if let songKey = currentSong?.identityKey, !attemptedQQOfficialBRs.isEmpty {
                attemptedQQOfficialBRsBySong[songKey, default: []].formUnion(attemptedQQOfficialBRs)
            }
        }
        prepareForSystemPlayback()
        configureAudioSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        removeCurrentObservers()
        pendingThirdPartyVIPNotice = thirdPartyVIPNotice
        // QQ CDN 地址需要基础请求头；第三方地址也可能落在
        // ptqqmusic.gitv.tv / aqqmusic.tc.qq.com 等 QQ CDN 域名。
        // 这些地址在低系统上如果缺少 Referer/Cookie，常见表现是先进入
        // playing，随后以 AVFoundation -11849 失败。
        let item: AVPlayerItem
        var playbackHeaders: [String: String] = [:]
        if url.host?.contains("kugou.com") == true || url.host?.contains("kgimg.com") == true {
            playbackHeaders = [
                "User-Agent": "Android15-1070-11440-46-0-DiscoveryDRADProtocol-wifi",
                "Referer": "https://www.kugou.com/",
            ]
            let cookie = KugouMusicAuth.shared.cookieHeader
            if !cookie.isEmpty { playbackHeaders["Cookie"] = cookie }
            let asset = AVURLAsset(url: url, options: [
                "AVURLAssetHTTPHeaderFieldsKey": playbackHeaders
            ])
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }
        let player = AVPlayer(playerItem: item)
        // QQ CDN 返回的首包较小，避免 AVPlayer 为了预缓冲过久而表现为
        // “点击后没反应”；真正不可播放时仍由 item 失败回调触发音质降级。
        player.automaticallyWaitsToMinimizeStalling = false
        player.volume = Float(softwareVolume)
        player.rate = Float(rate)
        self.player = player
        configureEqualizer(for: item)
        playbackConfirmed = false
        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            self.performOnMain { [weak self] in
                guard let self,
                      self.player === player,
                      self.currentSong?.identityKey == loadedSong.identityKey else { return }
                if item.status == .readyToPlay { return }
                guard item.status == .failed else { return }
                if self.retryKugouAtStandardIfNeeded(error: item.error) { return }
                let reason = "AVPlayerItem 加载失败"
                self.finishUnrecoverablePlaybackFailure(song: loadedSong, reason: reason)
            }
        }
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            self.performOnMain { [weak self] in
                guard let self, self.player === player else { return }
                if player.timeControlStatus == .paused, self.isPlaying {
                    if self.applicationIsInBackground,
                       item.status == .readyToPlay {
                        // iOS 26.x can pause an AVPlayer while the app is being
                        // suspended without delivering a complete interruption
                        // sequence. Keep the user's playback intent and retry
                        // after the background audio session has settled.
                        self.rememberAudioPlaybackIntent()
                        self.isPlaying = false
                        self.stopListeningSegment()
                        self.refreshNowPlayingOwnership()
                        self.scheduleAudioRecovery(reason: "后台播放器暂停", delay: 0.25)
                    } else if self.mixesWithOthers,
                       item.status == .readyToPlay {
                        // 某些外部音频只会让 AVPlayer 暂停，不会发出完整的 interruption
                        // 通知；保留播放意图，等系统音频会话释放后自动恢复。
                        self.rememberAudioPlaybackIntent()
                        self.isPlaying = false
                        self.stopListeningSegment()
                        self.refreshNowPlayingOwnership()
                        self.scheduleAudioRecovery(reason: "外部音频暂停播放器", delay: 0.25)
                    } else if self.audioLossInProgress {
                        self.isPlaying = false
                        self.stopListeningSegment()
                        self.refreshNowPlayingOwnership()
                    }
                }
                if player.timeControlStatus == .playing, self.audioLossInProgress {
                    self.isPlaying = true
                    self.startListeningSegment()
                }
                if player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                    self.isBuffering = true
                    self.playbackStallWorkItem?.cancel()
                    let stall = DispatchWorkItem { [weak self, weak player, weak item] in
                        guard let self,
                              let player,
                              let item,
                              self.player === player,
                              player.currentItem === item,
                              self.currentSong?.identityKey == loadedSong.identityKey,
                              player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
                              !self.playbackConfirmed else { return }
                                                        if self.retryKugouAtStandardIfNeeded(error: item.error) { return }
                        self.finishUnrecoverablePlaybackFailure(
                            song: loadedSong,
                            reason: "播放地址长时间未响应"
                        )
                    }
                    self.playbackStallWorkItem = stall
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: stall)
                    return
                }
                self.playbackStallWorkItem?.cancel()
                self.playbackStallWorkItem = nil
                guard player.timeControlStatus == .playing, !self.playbackConfirmed else { return }
                self.playbackConfirmationWorkItem?.cancel()
                let confirmation = DispatchWorkItem { [weak self, weak player, weak item] in
                    guard let self,
                          let player,
                          let item,
                          self.player === player,
                          player.currentItem === item,
                          player.timeControlStatus == .playing,
                          item.status == .readyToPlay,
                          !self.playbackConfirmed else { return }
                    self.playbackConfirmed = true
                    self.showPendingThirdPartyVIPNoticeIfNeeded()
                }
                self.playbackConfirmationWorkItem = confirmation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: confirmation)
            }
        }
        if resumeAt > 0.5 {
            let seekTime = CMTime(seconds: resumeAt, preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
            progress = resumeAt
        }
        guard autoplay else {
            isBuffering = false
            loadFailed = false
            refreshNowPlayingOwnership()
            return
        }
        player.playImmediately(atRate: Float(rate))
        isPlaying = true
        startListeningSegment()
        isBuffering = false
        loadFailed = false
        startAudioSessionWatchdogIfNeeded()
        // 播放次数：原先在 loadCurrent 里预计数，URL 加载失败/手动重试也会 +1，
        // 导致统计异常；改为真正开始播放时计数。同一 load 只计一次（失败重载会换
        // loadGeneration，失败那次本来就没计过，不会重复计）；点同一首歌重播、
        // 切歌再回来都会走新的 load，都会重新计——不再是“同一首歌计过一次就卡住”。
        if let song = currentSong, countedLoadGeneration != loadGeneration {
            bumpPlayCount(song)
            countedLoadGeneration = loadGeneration
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self, let player = self.player else { return }
            if time.seconds.isFinite {
                self.recordListeningProgress(at: time.seconds, player: player)
                self.lyricProgress = time.seconds
                if abs(time.seconds - self.lastPublishedProgress) >= 0.18 {
                    self.lastPublishedProgress = time.seconds
                    self.progress = time.seconds
                    if abs(time.seconds - self.lastPersistedProgress) >= 5.0 {
                        self.lastPersistedProgress = time.seconds
                        self.savePersistedPlaybackState()
                    }
                }
                // 其他音频 App 播放时可能会覆盖系统唯一的 Now Playing 信息。
                // 混音模式下定期重发轻量状态，让 Beans 继续保持锁屏/灵动岛控制权。
                let uptime = ProcessInfo.processInfo.systemUptime
                if self.isPlaying,
                   self.mixesWithOthers,
                   uptime - self.lastNowPlayingRefreshUptime >= 0.6 {
                    self.lastNowPlayingRefreshUptime = uptime
                    self.refreshNowPlayingOwnership()
                }
            }
            if let itemDuration = player.currentItem?.duration, itemDuration.isNumeric {
                let seconds = itemDuration.seconds
                if seconds.isFinite, abs(seconds - self.duration) > 0.25 {
                    self.duration = seconds
                }
            }
            let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            if waiting != self.isBuffering {
                self.isBuffering = waiting
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.stopAfterCurrentSong {
                self.stopAfterCurrentSong = false
                self.pausePlayback()
            } else if self.playMode == .repeatOne {
                self.restartCurrent()
            } else if self.playMode == .sequential,
                      self.currentIndex >= self.queue.count - 1 {
                self.isPlaying = false
                self.stopListeningSegment()
                self.stopAudioSessionWatchdog()
                self.updateNowPlaying()
            } else {
                self.advance()
                self.loadCurrent()
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self,
                  self.player?.currentItem === item,
                  self.currentSong?.identityKey == loadedSong.identityKey else { return }
            if self.retryKugouAtStandardIfNeeded(error: item.error) { return }
            self.finishUnrecoverablePlaybackFailure(song: loadedSong, reason: "播放中断失败")
        }
        updateNowPlaying()
    }

    /// AVFoundation KVO callbacks are not guaranteed to arrive on the main
    /// thread. Serialize callbacks that touch ObservableObject state before
    /// reading or mutating the player model.
    private func performOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func finishUnrecoverablePlaybackFailure(
        song: Song?,
        reason: String,
        message: String? = nil
    ) {
        guard let failedSong = song,
              currentSong?.identityKey == failedSong.identityKey,
              finalizedFailureSongKey != failedSong.identityKey else {
            loadFailed = true
            isBuffering = false
            isPlaying = false
            stopListeningSegment()
            stopAudioSessionWatchdog()
            return
        }
        loadFailed = true
        isBuffering = false
        isPlaying = false
        stopListeningSegment()
        stopAudioSessionWatchdog()
        finalizedFailureSongKey = failedSong.identityKey
        let shouldAutoSkip = defaults.object(forKey: autoSkipOnFailureKey) as? Bool ?? true
        let failureMessage: String
        if shouldAutoSkip && queue.count > 1 {
            failureMessage = coLocalized(
                "播放失败：\(playbackFailureMessage(for: failedSong, reason: reason))，已自动切换到下一首",
                "Playback failed: \(playbackFailureMessage(for: failedSong, reason: reason, english: true)). Switched to the next song automatically."
            )
        } else {
            failureMessage = message ?? coLocalized(
                "播放失败：\(playbackFailureMessage(for: failedSong, reason: reason))",
                "Playback failed: \(playbackFailureMessage(for: failedSong, reason: reason, english: true))"
            )
        }
        Task { @MainActor in
            ToastCenter.shared.show(failureMessage, duration: 3)
        }
        guard shouldAutoSkip, queue.count > 1 else { return }
        let failedSongKey = failedSong.identityKey
        let failedGeneration = loadGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.loadGeneration == failedGeneration,
                  self.currentSong?.identityKey == failedSongKey,
                  self.finalizedFailureSongKey == failedSongKey else {
                return
            }
            self.failureAutoSkipWorkItem = nil
            self.next(manual: false)
        }
        failureAutoSkipWorkItem?.cancel()
        failureAutoSkipWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }


    private func normalizedTrackText(_ value: String) -> String {
        var result = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        for marker in ["(live)", "（live）", "live", "(remix)", "（remix）", "remix", "(dj)", "（dj）", "dj"] {
            result = result.replacingOccurrences(of: marker, with: "", options: .caseInsensitive)
        }
        return result
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }


    private func resetCrossPlatformFallbackState() {
        crossPlatformFallbackOriginKey = nil
        crossPlatformFallbackTriedSources.removeAll()
        crossPlatformFallbackInFlightSongKey = nil
    }

    private func playbackFailureMessage(for song: Song, reason: String, english: Bool = false) -> String {
        if song.source == .bilibili || song.source == .webdav { return reason }
        let category = playbackFailureCategory(for: song, reason: reason)
        if english {
            switch category {
            case .membership:
                return "this song may require a platform membership; sign in to the platform and try again"
            case .network:
                return "the source timed out or the network is unavailable; check the connection and try again"
            case .sourceUnavailable:
                return "the platform did not return a playable address"
            case .unsupportedFormat:
                return "the returned audio format is not supported on this device"
            case .thirdPartyUnavailable:
                return "all enabled custom sources failed to return a playable address"
            case .unknown:
                return "the audio address could not be loaded; try again or switch songs"
            }
        }

        switch category {
        case .membership:
            return "该歌曲可能需要平台会员，请登录平台账号后重试"
        case .network:
            return "音源请求超时或网络不可用，请检查网络后重试"
        case .sourceUnavailable:
            return "平台没有返回可播放地址"
        case .unsupportedFormat:
            return "返回的音频格式不受当前设备支持"
        case .thirdPartyUnavailable:
            return "所有已启用的自定义音源都没有返回可播放地址"
        case .unknown:
            return "音频地址加载失败，请重试或切换歌曲"
        }
    }

    private func playbackFailureCategory(for song: Song, reason: String) -> PlaybackFailureCategory {
        let normalizedReason = reason.lowercased()
        if normalizedReason.contains("长时间") || normalizedReason.contains("timeout") || normalizedReason.contains("超时") {
            return .network
        }
        if normalizedReason.contains("第三方") || normalizedReason.contains("自定义") {
            return .thirdPartyUnavailable
        }
        if normalizedReason.contains("格式") || normalizedReason.contains("解码") || normalizedReason.contains("unsupported") {
            return .unsupportedFormat
        }
        if song.isVIP && !hasMembership(for: song.source) && !externalSourcesEnabled {
            return .membership
        }
        if normalizedReason.contains("解析") || normalizedReason.contains("地址") || normalizedReason.contains("加载") {
            return .sourceUnavailable
        }
        return .unknown
    }

    private func ensurePlaybackAllowed() -> Bool {
        guard !defaults.bool(forKey: CoBackendSettings.blockedKey) else {
            stopPlaybackIfBackendBlocked(showToast: true)
            return false
        }
        return true
    }

    /// 统一按当前歌曲平台重新解析第三方地址，失败重试时不跨平台匹配同名歌曲。
    private func stopPlaybackIfBackendBlocked(showToast: Bool = false) {
        guard defaults.bool(forKey: CoBackendSettings.blockedKey) else { return }
        clearAudioRecoveryIntent()
        loadGeneration += 1
        playbackLoadTask?.cancel()
        playbackLoadTask = nil
        playbackConfirmationWorkItem?.cancel()
        failureAutoSkipWorkItem?.cancel()
        failureAutoSkipWorkItem = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        removeCurrentObservers()
        player = nil
        isPlaying = false
        isBuffering = false
        loadFailed = true
        updateNowPlaying()
        if showToast {
            Task { @MainActor in
                ToastCenter.shared.show("当前设备暂不可播放")
            }
        }
    }

    private func removeCurrentObservers() {
        stopAudioSessionWatchdog()
        stopListeningSegment()
        flushListeningDuration()
        resetListeningProgress()
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        failureObserver = nil
        itemStatusObserver = nil
        timeControlStatusObserver = nil
        playbackConfirmationWorkItem?.cancel()
        playbackConfirmationWorkItem = nil
        failureAutoSkipWorkItem?.cancel()
        failureAutoSkipWorkItem = nil
        playbackStallWorkItem?.cancel()
        playbackStallWorkItem = nil
        playbackConfirmed = false
        pendingThirdPartyVIPNotice = nil
        lastPublishedProgress = -1
    }

    private func resetListeningProgress() {
        lastListeningProgress = nil
        lastListeningSongKey = nil
    }

    private func startListeningSegment() {
        guard listeningSegmentStartedUptime == nil else { return }
        listeningSegmentStartedUptime = ProcessInfo.processInfo.systemUptime
    }

    private func stopListeningSegment() {
        guard let started = listeningSegmentStartedUptime else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0, now - started)
        if elapsed > 0 {
            pendingListeningDuration += elapsed
        }
        listeningSegmentStartedUptime = nil
        flushListeningDuration()
    }

    private func recordListeningProgress(at playbackTime: TimeInterval, player: AVPlayer) {
        guard isPlaying,
              player.timeControlStatus == .playing else {
            stopListeningSegment()
            resetListeningProgress()
            return
        }

        startListeningSegment()
        // 统计真实播放经过的时间，而不是歌曲进度变化。这样拖动、循环、
        // 切歌和同一首歌反复测试都不会把统计值重复计算。
        if let started = listeningSegmentStartedUptime {
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = max(0, now - started)
            if elapsed > 0 {
                pendingListeningDuration += elapsed
                listeningSegmentStartedUptime = now
            }
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        if uptime - lastListeningPublishUptime >= 15 {
            flushListeningDuration()
        }
    }

    private func flushListeningDuration() {
        guard pendingListeningDuration > 0 else { return }
        listeningDuration += pendingListeningDuration
        pendingListeningDuration = 0
        let value = max(0, listeningDuration)
        defaults.set(value, forKey: Self.listeningDurationKey)
        lastListeningPublishUptime = ProcessInfo.processInfo.systemUptime
    }

    /// 均衡器通过 AVAudioMix 的音频处理 tap 工作，不改动 URL、队列或播放器状态。
    /// 曲目切换和开关均复用这里的挂载流程，避免让网络请求跑到主线程。
    private func applyEqualizerToCurrentItem() {
        guard let item = player?.currentItem else { return }
        configureEqualizer(for: item)
    }

    private func configureEqualizer(for item: AVPlayerItem) {
        guard CoEqualizer.shared.isEnabled || CoEqualizer.shared.surroundEnabled else {
            item.audioMix = nil
            return
        }

        let asset = item.asset
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self, weak item, weak asset] in
            guard let self, let item, let asset else { return }
            var error: NSError?
            guard asset.statusOfValue(forKey: "tracks", error: &error) == .loaded,
                  let track = asset.tracks(withMediaType: .audio).first,
                  let mix = CoEqualizer.shared.makeAudioMix(for: track) else {
                return
            }
            self.performOnMain { [weak self, weak item] in
                guard let self,
                      let item,
                      self.player?.currentItem === item,
                      CoEqualizer.shared.isEnabled || CoEqualizer.shared.surroundEnabled else { return }
                item.audioMix = mix
            }
        }
    }

    private func thirdPartyVIPNotice(for song: Song, sourceTitle: String) -> ThirdPartyVIPNotice? {
        guard song.isVIP else { return nil }
        guard defaults.object(forKey: thirdPartyVIPNoticeKey) as? Bool ?? true else { return nil }
        guard !hasMembership(for: song.source) else { return nil }
        let sourceName = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = sourceName.isEmpty ? "第三方音源" : "第三方音源「\(sourceName)」"
        return ThirdPartyVIPNotice(
            songKey: song.identityKey,
            message: "当前账号未识别到对应会员，《\(song.name)》已通过\(suffix)播放"
        )
    }

    private func showPendingThirdPartyVIPNoticeIfNeeded() {
        guard let notice = pendingThirdPartyVIPNotice else { return }
        guard currentSong?.identityKey == notice.songKey else {
            pendingThirdPartyVIPNotice = nil
            return
        }
        guard defaults.object(forKey: thirdPartyVIPNoticeKey) as? Bool ?? true else {
            pendingThirdPartyVIPNotice = nil
            return
        }
        Task { @MainActor in
            ToastCenter.shared.show(notice.message)
        }
        pendingThirdPartyVIPNotice = nil
    }

    private func hasMembership(for source: SongSource) -> Bool {
        source == .kugou && KugouMusicAuth.shared.vipBadge != nil
    }

    private func configureAudioSession() {
        if Self.applyAudioMixPreference(mixesWithOthers) {
            sessionConfigured = true
        } else {
            sessionConfigured = false
        }
    }

    @discardableResult
    static func applyAudioMixPreference(_ mixesWithOthers: Bool, activate: Bool = true) -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            // 「与其他音频同时播放」开关：开启时 mixWithOthers，打开其他音频软件也能继续播放；关闭则自动暂停
            let options: AVAudioSession.CategoryOptions = mixesWithOthers ? [.mixWithOthers] : []
            let policy: AVAudioSession.RouteSharingPolicy = mixesWithOthers ? .default : .longFormAudio
            try session.setCategory(.playback, mode: .default, policy: policy, options: options)
            if activate {
                try session.setActive(true)
            }
            if mixesWithOthers, !session.categoryOptions.contains(.mixWithOthers) {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    /// 延后初始化系统音频服务，降低自签安装后首次启动时的兼容性风险。
    /// 播放真正开始前由 setupPlayer 兜底调用，因此不会影响播放器功能。
    private func prepareForSystemPlayback() {
        guard !systemPlaybackPrepared else { return }
        systemPlaybackPrepared = true
        observeInterruptions()
        observeRouteChanges()
        setupRemoteCommands()
    }

    private func observeRouteChanges() {
        guard !routeObserverInstalled else { return }
        routeObserverInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    /// 输出设备变化（插拔耳机 / 切换扬声器 / 来电路由等）后重新激活会话，避免播放无声
    @objc private func handleRouteChange(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleRouteChange(notification)
            }
            return
        }
        sessionConfigured = false
        if isPlaying || player?.timeControlStatus == .playing {
            rememberAudioPlaybackIntent()
        }
        if shouldResumeAfterAudioLoss || isPlaying || player?.timeControlStatus == .playing {
            scheduleAudioRecovery(reason: "音频路由变化", delay: 0.12)
        }
    }

    // MARK: - 来电/中断处理

    private func observeInterruptions() {
        guard !interruptionObserverInstalled else { return }
        interruptionObserverInstalled = true
        let session = AVAudioSession.sharedInstance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        guard !secondaryAudioHintObserverInstalled else { return }
        secondaryAudioHintObserverInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSecondaryAudioHint(_:)),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: session
        )
        guard !mediaServicesObserverInstalled else { return }
        mediaServicesObserverInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
        guard !applicationAudioObserverInstalled else { return }
        applicationAudioObserverInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidEnterBackground(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleInterruption(notification)
            }
            return
        }
        guard let info = notification.userInfo,
              let rawValue = info[AVAudioSessionInterruptionTypeKey] else { return }
        let rawType: UInt
        if let number = rawValue as? NSNumber {
            rawType = number.uintValue
        } else if let value = rawValue as? UInt {
            rawType = value
        } else {
            return
        }
        guard let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            interruptionResumeWorkItem?.cancel()
            interruptionResumeWorkItem = nil
            interruptionInProgress = true
            rememberAudioPlaybackIntent()
            // 混音模式下系统可能只暂停 AVPlayer 而不改变我们的状态；恢复统一交给
            // 结束通知和次级音频提示，避免在系统仍占用音频会话时抢先播放。
            if !mixesWithOthers {
                isPlaying = false
                stopListeningSegment()
                player?.pause()
                updateNowPlaying()
            } else {
                sessionConfigured = false
                scheduleAudioRecovery(reason: "mixed audio interruption", delay: 0.2)
                refreshNowPlayingOwnership()
            }
        case .ended:
            sessionConfigured = false
            guard interruptionInProgress || shouldResumeAfterAudioLoss else { return }
            scheduleAudioRecovery(reason: "系统音频中断结束", delay: 0.18)
        @unknown default:
            break
        }
    }

    /// 开启混音后，视频/语音类音频通常只发送这个通知，不发送完整 interruption ended 回调。
    @objc private func handleSecondaryAudioHint(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleSecondaryAudioHint(notification)
            }
            return
        }
        guard mixesWithOthers else { return }
        let rawValue = notification.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey]
        let rawType: UInt?
        if let number = rawValue as? NSNumber {
            rawType = number.uintValue
        } else {
            rawType = rawValue as? UInt
        }
        // 系统定义 began=1、ended=0；使用原始值兼容旧系统 SDK。
        if rawType == 1 {
            rememberAudioPlaybackIntent()
            sessionConfigured = false
            scheduleAudioRecovery(reason: "次级音频开始", delay: 0.12)
            refreshNowPlayingOwnership()
        } else {
            sessionConfigured = false
            scheduleAudioRecovery(reason: "次级音频结束", delay: 0.12)
        }
    }

    @objc private func handleMediaServicesReset(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleMediaServicesReset(notification)
            }
            return
        }
        sessionConfigured = false
        guard currentSong != nil else { return }
        rememberAudioPlaybackIntent()
        scheduleAudioRecovery(reason: "系统音频服务重置", delay: 0.2)
    }

    @objc private func handleApplicationWillResignActive(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleApplicationWillResignActive(notification)
            }
            return
        }
        guard isPlaying || player?.timeControlStatus == .playing else { return }
        rememberAudioPlaybackIntent()
    }

    @objc private func handleApplicationDidEnterBackground(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleApplicationDidEnterBackground(notification)
            }
            return
        }
        applicationIsInBackground = true
        guard currentSong != nil,
              isPlaying || shouldResumeAfterAudioLoss || player?.timeControlStatus == .playing else { return }
        rememberAudioPlaybackIntent()
        sessionConfigured = false
        scheduleAudioRecovery(reason: "进入后台保持播放", delay: 0.25)
    }

    @objc private func handleApplicationDidBecomeActive(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleApplicationDidBecomeActive(notification)
            }
            return
        }
        applicationIsInBackground = false
        guard currentSong != nil else { return }
        sessionConfigured = false
        if shouldResumeAfterAudioLoss || isPlaying || player?.timeControlStatus == .playing {
            scheduleAudioRecovery(reason: "应用重新激活", delay: 0.12)
        }
    }

    private func rememberAudioPlaybackIntent() {
        guard currentSong != nil else { return }
        let active = isPlaying || player?.timeControlStatus == .playing || player?.rate != 0
        if active {
            shouldResumeAfterAudioLoss = true
            wasPlayingBeforeInterruption = true
        }
        audioLossInProgress = true
    }

    private func clearAudioRecoveryIntent() {
        shouldResumeAfterAudioLoss = false
        audioLossInProgress = false
        interruptionInProgress = false
        wasPlayingBeforeInterruption = false
        audioRecoveryWorkItem?.cancel()
        audioRecoveryWorkItem = nil
        interruptionResumeWorkItem?.cancel()
        interruptionResumeWorkItem = nil
    }

    /// 混音播放时，部分应用既不发送完整中断通知，也会暂停 AVPlayer 的时间回调。
    /// 用主线程定时器补足这条通知链，同时重新发布系统正在播放信息。
    private func startAudioSessionWatchdogIfNeeded() {
        guard mixesWithOthers,
              currentSong != nil,
              audioSessionWatchdogTimer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.performOnMain { [weak self] in
                self?.handleAudioSessionWatchdogTick()
            }
        }
        audioSessionWatchdogTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAudioSessionWatchdog() {
        audioSessionWatchdogTimer?.invalidate()
        audioSessionWatchdogTimer = nil
    }

    private func handleAudioSessionWatchdogTick() {
        guard mixesWithOthers, currentSong != nil else {
            stopAudioSessionWatchdog()
            return
        }
        guard let currentPlayer = player else {
            stopAudioSessionWatchdog()
            return
        }

        let itemReady = currentPlayer.currentItem?.status == .readyToPlay
        let playerIsPlaying = currentPlayer.timeControlStatus == .playing
        let playerIsPaused = currentPlayer.timeControlStatus == .paused

        if playerIsPaused, itemReady, (!interruptionInProgress || mixesWithOthers) {
            if !shouldResumeAfterAudioLoss {
                rememberAudioPlaybackIntent()
            }
            if isPlaying {
                isPlaying = false
                stopListeningSegment()
                refreshNowPlayingOwnership()
            }
        }

        let session = AVAudioSession.sharedInstance()
        if !session.categoryOptions.contains(.mixWithOthers) {
            sessionConfigured = Self.applyAudioMixPreference(true)
        }
        let otherAudioIsActive = session.isOtherAudioPlaying || session.secondaryAudioShouldBeSilencedHint
        if shouldResumeAfterAudioLoss,
           !playerIsPlaying,
           itemReady,
           (mixesWithOthers || !otherAudioIsActive) {
            scheduleAudioRecovery(reason: "外部音频结束", delay: 0)
        }

        // 其它应用可能已经覆盖系统唯一的 Now Playing 槽位；播放期间持续重发，
        // 结束后也能立即恢复封面、控制中心和灵动岛内容。
        if playerIsPlaying || (shouldResumeAfterAudioLoss && !otherAudioIsActive) {
            let uptime = ProcessInfo.processInfo.systemUptime
            if uptime - lastNowPlayingRefreshUptime >= 0.6 {
                lastNowPlayingRefreshUptime = uptime
                refreshNowPlayingOwnership()
            }
        }
    }

    private func scheduleAudioRecovery(reason: String, delay: TimeInterval, attempt: Int = 0) {
        guard currentSong != nil else { return }
        guard shouldResumeAfterAudioLoss || isPlaying || player?.timeControlStatus == .playing else { return }
        audioRecoveryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.recoverAudioSession(reason: reason, attempt: attempt)
        }
        audioRecoveryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func recoverAudioSession(reason: String, attempt: Int) {
        guard currentSong != nil else { return }
        let session = AVAudioSession.sharedInstance()
        if !mixesWithOthers,
           session.isOtherAudioPlaying || session.secondaryAudioShouldBeSilencedHint {
            scheduleAudioRecovery(
                reason: reason,
                delay: min(0.8, 0.18 + Double(attempt) * 0.08),
                attempt: attempt + 1
            )
            return
        }

        sessionConfigured = false
        guard Self.applyAudioMixPreference(mixesWithOthers) else {
            scheduleAudioRecovery(reason: reason, delay: 0.35, attempt: attempt + 1)
            return
        }

        guard let currentPlayer = player else {
            let resume = progress
            clearAudioRecoveryIntent()
            loadCurrent(resumeAt: resume)
            return
        }
        if currentPlayer.currentItem == nil || currentPlayer.currentItem?.status == .failed {
            let resume = progress
            clearAudioRecoveryIntent()
            loadCurrent(resumeAt: resume)
            return
        }

        currentPlayer.playImmediately(atRate: Float(rate))
        isPlaying = true
        startListeningSegment()
        isBuffering = false
        audioLossInProgress = false
        shouldResumeAfterAudioLoss = false
        interruptionInProgress = false
        wasPlayingBeforeInterruption = false
        startAudioSessionWatchdogIfNeeded()
        refreshNowPlayingOwnership()
    }

    // MARK: - 播放历史与统计

    private func pushHistory(_ song: Song) {
        history.removeAll { $0.identityKey == song.identityKey }
        history.insert(song, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: historyKey),
              let saved = try? JSONDecoder().decode([Song].self, from: data) else { return }
        history = saved
    }

    private func bumpPlayCount(_ song: Song) {
        playCounts[song.identityKey, default: 0] += 1
        countedSongs[song.identityKey] = song
        if let data = try? JSONEncoder().encode(playCounts) {
            defaults.set(data, forKey: countsKey)
        }
        if let data = try? JSONEncoder().encode(countedSongs) {
            defaults.set(data, forKey: countedSongsKey)
        }
    }

    private func loadPlayCounts() {
        if let data = defaults.data(forKey: countsKey),
           let saved = try? JSONDecoder().decode([String: Int].self, from: data) {
            playCounts = saved
        }
        // 先读已存的计过数的歌，再用 history 里还找得到的歌补齐缺口（老用户升级时
        // countedSongs 还是空的，history 里能找到的就先认下来，不丢旧计数对应的歌）。
        if let data = defaults.data(forKey: countedSongsKey),
           let saved = try? JSONDecoder().decode([String: Song].self, from: data) {
            countedSongs = saved
        }
        for key in playCounts.keys where countedSongs[key] == nil {
            if let song = history.first(where: { $0.identityKey == key }) {
                countedSongs[key] = song
            }
        }
        // 迁移只填内存是不够的：补进来的歌要落盘，否则下次启动前
        // countedSongs 又是空的、详情页又可能空白。
        if let data = try? JSONEncoder().encode(countedSongs) {
            defaults.set(data, forKey: countedSongsKey)
        }
    }

    /// 有计数、但歌名记录已对不上的播放次数合计（历史被清空、旧记录
    /// 解码失败、或歌已滚出历史时会出现）：不是假数据，是真实播放次数
    /// 减去能找到歌名的那部分，详情页要把它诚实显示出来，不能直接空白。
    var orphanPlayCount: Int {
        playCounts.filter { countedSongs[$0.key] == nil }.values.reduce(0, +)
    }

    private func savePersistedPlaybackState() {
        guard !queue.isEmpty, queue.indices.contains(currentIndex) else {
            defaults.removeObject(forKey: playbackStateKey)
            return
        }
        let state = PersistedPlaybackState(
            queue: queue,
            currentIndex: currentIndex,
            progress: progress,
            duration: duration,
            savedAt: Date()
        )
        let defaults = self.defaults
        let key = playbackStateKey
        playbackPersistenceQueue.async {
            guard let data = try? JSONEncoder().encode(state) else { return }
            defaults.set(data, forKey: key)
        }
    }

    private func restorePersistedPlaybackState() {
        guard let data = defaults.data(forKey: playbackStateKey),
              let saved = try? JSONDecoder().decode(PersistedPlaybackState.self, from: data),
              !saved.queue.isEmpty else { return }
        queue = saved.queue
        currentIndex = min(max(saved.currentIndex, 0), saved.queue.count - 1)
        duration = max(saved.duration, currentSong?.duration ?? 0)
        progress = max(0, min(saved.progress, max(duration, currentSong?.duration ?? 0)))
        isPlaying = false
        isBuffering = false
        loadFailed = false
        buildPlayOrder()
    }

    /// 清除常听记录（只清常听这一项）：播放次数 playCounts、计过数的歌库
    /// countedSongs 一起清并落盘，外面那个数回到 0、详情页回到空状态。
    /// 不动历史（beans.history）、不收藏、不动歌单、不动播放队列，确认后才调。
    func clearTopPlayed() {
        playCounts = [:]
        countedSongs = [:]
        defaults.removeObject(forKey: countsKey)
        defaults.removeObject(forKey: countedSongsKey)
    }

    /// 听歌排行：按真实播放次数排序的前 8 首，歌从 countedSongs 里找，
    /// 不再从 history 里找——history 上限 50 首，老歌滚出去后榜单会掉歌、但总数还在。
    var topPlayed: [(song: Song, count: Int)] {
        var result: [(song: Song, count: Int)] = []
        for (key, count) in playCounts {
            if let song = countedSongs[key] {
                result.append((song, count))
            }
        }
        return result.sorted { $0.count > $1.count }.prefix(8).map { $0 }
    }

    // MARK: - 系统正在播放

    private func updateNowPlaying() {
        guard nowPlayingEnabled else {
            clearNowPlayingInfo()
            return
        }
        guard let song = currentSong else { return }
        let sameSong = nowPlayingSongKey == song.identityKey
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.artists,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: max(duration, song.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if sameSong, let artwork = nowPlayingInfo[MPMediaItemPropertyArtwork] {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        if let artworkURL = CustomSongCoverStore.shared.url(for: song) ?? song.coverURL {
            let artworkKey = song.identityKey + "|" + artworkURL.absoluteString
            if let cached = Self.nowPlayingArtworkCache.object(forKey: artworkURL as NSURL) {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: cached.size) { _ in cached }
            } else if lastNowPlayingArtworkKey != artworkKey {
                lastNowPlayingArtworkKey = artworkKey
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    let image: UIImage?
                    if artworkURL.isFileURL {
                        image = CustomCoverMedia.systemArtworkImage(at: artworkURL)
                    } else if let data = try? Data(contentsOf: artworkURL) {
                        image = UIImage(data: data)
                    } else {
                        image = nil
                    }
                    if let image {
                        Self.nowPlayingArtworkCache.setObject(image, forKey: artworkURL as NSURL)
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        DispatchQueue.main.async {
                            guard let self,
                                  self.currentSong?.identityKey == song.identityKey,
                                  (CustomSongCoverStore.shared.url(for: song) ?? song.coverURL) == artworkURL else { return }
                            guard self.nowPlayingEnabled else { return }
                            self.nowPlayingSongKey = song.identityKey
                            self.nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                            self.publishNowPlayingInfo()
                        }
                    }
                }
            }
        } else {
            lastNowPlayingArtworkKey = nil
        }
        nowPlayingSongKey = song.identityKey
        nowPlayingInfo = info
        publishNowPlayingInfo()
    }

    /// 混音播放时只更新锁屏所需的轻量字段，避免重复下载或解码封面。
    /// 系统的 Now Playing 信息是全局单例，其他音乐 App 播放后需要重新声明当前内容。
    private func refreshNowPlayingOwnership() {
        guard nowPlayingEnabled, let song = currentSong else { return }
        guard nowPlayingSongKey == song.identityKey, !nowPlayingInfo.isEmpty else {
            updateNowPlaying()
            return
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? rate : 0.0
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = max(duration, song.duration)
        if let artworkURL = CustomSongCoverStore.shared.url(for: song) ?? song.coverURL,
           let cached = Self.nowPlayingArtworkCache.object(forKey: artworkURL as NSURL) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: cached.size) { _ in cached }
        }
        publishNowPlayingInfo()
    }

    private func publishNowPlayingInfo() {
        guard nowPlayingEnabled, !nowPlayingInfo.isEmpty else { return }
        if isPlaying {
            let center = MPRemoteCommandCenter.shared()
            center.nextTrackCommand.isEnabled = true
            center.previousTrackCommand.isEnabled = true
            center.skipForwardCommand.isEnabled = false
            center.skipBackwardCommand.isEnabled = false
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        Task { @MainActor in CoNowPlayingLiveActivity.shared.update(song: self.currentSong, isPlaying: self.isPlaying) }
    }

    private func clearNowPlayingInfo() {
        lastNowPlayingArtworkKey = nil
        nowPlayingSongKey = nil
        nowPlayingInfo = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        Task { @MainActor in CoNowPlayingLiveActivity.shared.update(song: nil, isPlaying: false) }
    }

    private func setupRemoteCommands() {
        guard !remoteCommandsInstalled else { return }
        remoteCommandsInstalled = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.performOnMain { [weak self] in
                guard let self else { return }
                        guard self.ensurePlaybackAllowed() else { return }
                self.clearAudioRecoveryIntent()
                self.player?.playImmediately(atRate: Float(self.rate))
                self.isPlaying = true
                self.startListeningSegment()
                self.updateNowPlaying()
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.performOnMain { [weak self] in
                guard let self else { return }
                        self.clearAudioRecoveryIntent()
                self.isPlaying = false
                self.stopListeningSegment()
                self.player?.pause()
                self.stopAudioSessionWatchdog()
                self.updateNowPlaying()
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.performOnMain { [weak self] in
                        self?.next()
            }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.performOnMain { [weak self] in
                        self?.previous()
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.performOnMain { [weak self] in
                        self?.togglePlayPause()
            }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.performOnMain { [weak self] in
                        self?.seek(to: event.positionTime)
            }
            return .success
        }
    }

    // MARK: - 与其他音频同时播放

    /// 与其他 App 音频混合播放。此开关与锁屏/灵动岛显示相互独立。
    var mixesWithOthers: Bool {
        get { defaults.object(forKey: audioMixKey) as? Bool ?? false }
        set { setMixesWithOthers(newValue) }
    }

    /// 更新混音会话后立即重申系统正在播放信息，避免混音开关影响锁屏和灵动岛显示。
    func setMixesWithOthers(_ enabled: Bool) {
        defaults.set(enabled, forKey: audioMixKey)
        sessionConfigured = false
        configureAudioSession()
        if enabled, isPlaying || player?.timeControlStatus == .playing {
            startAudioSessionWatchdogIfNeeded()
        } else if !enabled {
            stopAudioSessionWatchdog()
        }
        updateNowPlaying()
    }

    /// 独立控制锁屏和灵动岛的系统正在播放信息，不影响与其他音频混合播放。
    var nowPlayingEnabled: Bool {
        get { defaults.object(forKey: nowPlayingEnabledKey) as? Bool ?? true }
        set { setNowPlayingEnabled(newValue) }
    }

    func setNowPlayingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: nowPlayingEnabledKey)
        if enabled {
            updateNowPlaying()
        } else {
            clearNowPlayingInfo()
        }
    }

}
