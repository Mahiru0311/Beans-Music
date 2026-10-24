import AVFoundation
import Combine
import Foundation
import MediaToolbox

enum CoEqualizerPreset: String, CaseIterable, Identifiable {
    case flat
    case bass
    case vocal
    case pop
    case rock
    case classical
    case jazz
    case electronic
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flat: return coLocalized("默认", "Default")
        case .bass: return coLocalized("低音增强", "Bass Boost")
        case .vocal: return coLocalized("人声", "Vocal")
        case .pop: return coLocalized("流行", "Pop")
        case .rock: return coLocalized("摇滚", "Rock")
        case .classical: return coLocalized("古典", "Classical")
        case .jazz: return coLocalized("爵士", "Jazz")
        case .electronic: return coLocalized("电子", "Electronic")
        case .custom: return coLocalized("自定义", "Custom")
        }
    }

    var gains: [Double]? {
        switch self {
        case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bass: return [6, 5, 3, 1, 0, 0, -1, -1, 0, 0]
        case .vocal: return [-2, -1, 0, 2, 4, 4, 3, 2, 0, -1]
        case .pop: return [2, 2, 1, 0, 2, 3, 2, 1, 2, 2]
        case .rock: return [5, 4, 2, -1, -2, 1, 3, 4, 5, 4]
        case .classical: return [3, 2, 1, 0, 0, 1, 2, 3, 4, 4]
        case .jazz: return [3, 2, 1, 2, -1, -1, 0, 2, 3, 3]
        case .electronic: return [5, 4, 1, -2, -1, 2, 4, 3, 5, 4]
        case .custom: return nil
        }
    }
}

struct CoEqualizerCustomPreset: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var gains: [Double]
    var preampGain: Double

    init(id: String = UUID().uuidString, name: String, gains: [Double], preampGain: Double) {
        self.id = id
        self.name = name
        self.gains = gains
        self.preampGain = preampGain
    }
}

/// AVPlayerItem uses an audio-processing tap for the equalizer, so it keeps the
/// existing AVPlayer playback, queue, remote command, and background behavior.
final class CoEqualizer: ObservableObject {
    static let shared = CoEqualizer()
    static let settingsDidChange = Notification.Name("co.equalizer.settingsDidChange")

    static let bandFrequencies: [Double] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    static let maximumGain: Double = 12

    @Published private(set) var isEnabled: Bool
    /// 3D 环绕（轻量版）：人声左右摆动，可开关，默认关。
    @Published private(set) var surroundEnabled: Bool
    /// 耳机增强：低音 + 清晰度 + 声场轻微加宽，让官方音质档位在耳机上听感更好，可开关，默认关。
    @Published private(set) var headphoneBoostEnabled: Bool
    /// 人声清晰：只提 mid 通道、2.5kHz 宽峰值 +6dB，人声相对伴奏的比例直接拉开，可开关，默认关。
    @Published private(set) var vocalBoostEnabled: Bool
    /// 声场加宽：Mid/Side 法，side ×1.8，声场一耳朵撑开，单声道求和分毫不差，可开关，默认关。
    @Published private(set) var widenEnabled: Bool
    @Published private(set) var bandGains: [Double]
    @Published private(set) var selectedPreset: CoEqualizerPreset
    @Published private(set) var selectedCustomPresetName: String?
    @Published private(set) var preampGain: Double
    @Published private(set) var customPresets: [CoEqualizerCustomPreset]

    private let defaults = UserDefaults.standard
    private let configurationLock = NSLock()
    private var processingEnabled = false
    private var processingGains: [Double] = Array(repeating: 0, count: 10)
    private var processingPreampLinear: Float = 1
    private var processingFormatIsFloat32 = false
    private var processingFormatIsInt16 = false
    private var sampleRate: Double = 44_100
    private var coefficients: [BiquadCoefficients] = Array(repeating: .identity, count: 10)
    private var filterStates: [BiquadState] = Array(repeating: .zero, count: 80)
    private var enhancementCoefficients: [BiquadCoefficients] = [.identity, .identity]
    private var enhancementStates: [BiquadState] = Array(repeating: .zero, count: 16)
    /// 3D 声像摆动相位（弧度）：不随换歌清零，摆动不跳变。
    private var surroundPanPhase: Double = 0
    /// 3D 混响状态：每声道 4 个梳状 + 2 个全通（Freeverb 精简版），给 3D 那种“整个大脑里回荡”的空间感。
    private var reverbCombDelays: [Int] = []
    private var reverbAllpassDelays: [Int] = []
    /// 左右声道去相关：右声道梳状延迟 +23 采样（Freeverb stereo spread），同单声道输入进、左右出来不一样宽。
    private var reverbSpread = 0
    private var reverbCombBuffers: [[[Float]]] = []
    private var reverbCombIndices: [[Int]] = []
    private var reverbCombFilterStores: [[Float]] = []
    private var reverbAllpassBuffers: [[[Float]]] = []
    private var reverbAllpassIndices: [[Int]] = []
    private var reverbNeedsReset = false
    /// 3D 耳间时差：每声道一条微延迟线（最大 0.6ms，真实头宽量级），左/右延迟随声像走，声音出颅。
    private var itdBuffers: [[Float]] = []
    private var itdIndex = 0
    /// 3D 早期反射：单声道延迟线上的 6 个抽头（15/25/38/52/68/82ms），只进混响输入，给房间尺寸线索。
    private var earlyReflectionBuffer: [Float] = []
    private var earlyReflectionIndex = 0
    /// 人声清晰系数与状态：单段峰值滤波，每声道 1 组状态。
    private var vocalCoefficients: BiquadCoefficients = .identity
    private var vocalStates: [BiquadState] = Array(repeating: .zero, count: 8)
    private var pendingPersistWorkItem: DispatchWorkItem?

    private static let enabledKey = "co.equalizer.enabled"
    static let surroundKey = "co.surround3D.enabled"
    static let headphoneBoostKey = "co.headphoneBoost.enabled"
    static let vocalBoostKey = "co.vocalBoost.enabled"
    static let widenKey = "co.widen.enabled"
    private static let gainsKey = "co.equalizer.bandGains"
    private static let presetKey = "co.equalizer.preset"
    private static let customPresetNameKey = "co.equalizer.customPresetName"
    private static let customPresetsKey = "co.equalizer.customPresets"
    private static let preampKey = "co.equalizer.preampGain"
    private static let maximumChannels = 8

    private init() {
        let storedGains = defaults.array(forKey: Self.gainsKey)?
            .compactMap { ($0 as? NSNumber)?.doubleValue }
        let normalizedGains = Self.normalizedGains(storedGains)
        let storedPreset = defaults.string(forKey: Self.presetKey)
            .flatMap(CoEqualizerPreset.init(rawValue:)) ?? .flat
        let storedCustomPresets = defaults.data(forKey: Self.customPresetsKey)
            .flatMap { try? JSONDecoder().decode([CoEqualizerCustomPreset].self, from: $0) } ?? []
        let normalizedCustomPresets = storedCustomPresets.compactMap { preset -> CoEqualizerCustomPreset? in
            let name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return CoEqualizerCustomPreset(
                id: preset.id,
                name: name,
                gains: Self.normalizedGains(preset.gains),
                preampGain: Self.normalizedGain(preset.preampGain)
            )
        }

        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? false
        surroundEnabled = defaults.object(forKey: Self.surroundKey) as? Bool ?? false
        headphoneBoostEnabled = defaults.object(forKey: Self.headphoneBoostKey) as? Bool ?? false
        vocalBoostEnabled = defaults.object(forKey: Self.vocalBoostKey) as? Bool ?? false
        widenEnabled = defaults.object(forKey: Self.widenKey) as? Bool ?? false
        bandGains = normalizedGains
        selectedPreset = storedPreset
        selectedCustomPresetName = defaults.string(forKey: Self.customPresetNameKey)
        preampGain = Self.normalizedGain((defaults.object(forKey: Self.preampKey) as? NSNumber)?.doubleValue ?? 0)
        customPresets = normalizedCustomPresets
        processingEnabled = isEnabled || surroundEnabled || headphoneBoostEnabled || vocalBoostEnabled || widenEnabled
        processingGains = normalizedGains
        processingPreampLinear = Self.linearGain(for: preampGain)
        rebuildCoefficientsLocked(using: normalizedGains)
        rebuildEnhancementCoefficientsLocked()
        rebuildVocalCoefficientsLocked()
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        configurationLock.lock()
        processingEnabled = enabled || surroundEnabled || headphoneBoostEnabled || vocalBoostEnabled || widenEnabled
        configurationLock.unlock()
        defaults.set(enabled, forKey: Self.enabledKey)
        notifySettingsChanged()
    }

    /// 3D 环绕开关：改动后经 settingsDidChange 通知，播放器会重挂音频处理。
    func setSurroundEnabled(_ enabled: Bool) {
        guard surroundEnabled != enabled else { return }
        surroundEnabled = enabled
        configurationLock.lock()
        processingEnabled = isEnabled || enabled || headphoneBoostEnabled || vocalBoostEnabled || widenEnabled
        reverbNeedsReset = true
        configurationLock.unlock()
        defaults.set(enabled, forKey: Self.surroundKey)
        notifySettingsChanged()
    }

    /// 耳机增强开关：改动后经 settingsDidChange 通知，播放器会重挂音频处理。
    func setHeadphoneBoostEnabled(_ enabled: Bool) {
        guard headphoneBoostEnabled != enabled else { return }
        headphoneBoostEnabled = enabled
        configurationLock.lock()
        processingEnabled = isEnabled || surroundEnabled || enabled || vocalBoostEnabled || widenEnabled
        configurationLock.unlock()
        defaults.set(enabled, forKey: Self.headphoneBoostKey)
        notifySettingsChanged()
    }



    /// 人声清晰开关：改动后经 settingsDidChange 通知，播放器会重挂音频处理。
    func setVocalBoostEnabled(_ enabled: Bool) {
        guard vocalBoostEnabled != enabled else { return }
        vocalBoostEnabled = enabled
        configurationLock.lock()
        processingEnabled = isEnabled || surroundEnabled || headphoneBoostEnabled || enabled || widenEnabled
        configurationLock.unlock()
        defaults.set(enabled, forKey: Self.vocalBoostKey)
        notifySettingsChanged()
    }

    /// 声场加宽开关：改动后经 settingsDidChange 通知，播放器会重挂音频处理。
    func setWidenEnabled(_ enabled: Bool) {
        guard widenEnabled != enabled else { return }
        widenEnabled = enabled
        configurationLock.lock()
        processingEnabled = isEnabled || surroundEnabled || headphoneBoostEnabled || vocalBoostEnabled || enabled
        configurationLock.unlock()
        defaults.set(enabled, forKey: Self.widenKey)
        notifySettingsChanged()
    }

    func setBandGain(at index: Int, to gain: Double) {
        guard bandGains.indices.contains(index) else { return }
        let normalized = Self.normalizedGain(gain)
        guard bandGains[index] != normalized else { return }
        var updatedGains = bandGains
        updatedGains[index] = normalized
        bandGains = updatedGains
        selectedPreset = .custom
        selectedCustomPresetName = nil
        configurationLock.lock()
        processingGains = updatedGains
        rebuildCoefficientsLocked(using: updatedGains)
        configurationLock.unlock()
        schedulePersist()
        notifySettingsChanged()
    }

    func setPreampGain(_ gain: Double) {
        let normalized = Self.normalizedGain(gain)
        guard preampGain != normalized else { return }
        preampGain = normalized
        selectedPreset = .custom
        selectedCustomPresetName = nil
        configurationLock.lock()
        processingPreampLinear = Self.linearGain(for: normalized)
        configurationLock.unlock()
        schedulePersist()
        notifySettingsChanged()
    }

    func applyPreset(_ preset: CoEqualizerPreset) {
        guard let gains = preset.gains else { return }
        let normalized = Self.normalizedGains(gains)
        bandGains = normalized
        selectedPreset = preset
        selectedCustomPresetName = nil
        preampGain = 0
        configurationLock.lock()
        processingGains = normalized
        processingPreampLinear = 1
        rebuildCoefficientsLocked(using: normalized)
        configurationLock.unlock()
        persistNow()
        notifySettingsChanged()
    }

    func applyCustomPreset(_ preset: CoEqualizerCustomPreset) {
        let normalized = Self.normalizedGains(preset.gains)
        let normalizedPreamp = Self.normalizedGain(preset.preampGain)
        bandGains = normalized
        selectedPreset = .custom
        selectedCustomPresetName = preset.name
        preampGain = normalizedPreamp
        configurationLock.lock()
        processingGains = normalized
        processingPreampLinear = Self.linearGain(for: normalizedPreamp)
        rebuildCoefficientsLocked(using: normalized)
        configurationLock.unlock()
        persistNow()
        notifySettingsChanged()
    }

    @discardableResult
    func saveCustomPreset(name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        let current = CoEqualizerCustomPreset(
            name: trimmedName,
            gains: bandGains,
            preampGain: preampGain
        )
        if let index = customPresets.firstIndex(where: {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            customPresets[index] = CoEqualizerCustomPreset(
                id: customPresets[index].id,
                name: trimmedName,
                gains: current.gains,
                preampGain: current.preampGain
            )
        } else {
            customPresets.append(current)
        }
        selectedPreset = .custom
        selectedCustomPresetName = trimmedName
        persistNow()
        return true
    }

    func deleteCustomPreset(_ preset: CoEqualizerCustomPreset) {
        customPresets.removeAll { $0.id == preset.id }
        if selectedCustomPresetName == preset.name {
            selectedCustomPresetName = nil
        }
        persistNow()
    }

    func reset() {
        applyPreset(.flat)
    }

    /// Creates one processing tap per AVPlayerItem. The singleton stays alive for
    /// the whole app lifetime, so the tap's unretained callback context is stable.
    func makeAudioMix(for track: AVAssetTrack) -> AVAudioMix? {
        configurationLock.lock()
        let shouldProcess = processingEnabled
        configurationLock.unlock()
        guard shouldProcess else { return nil }

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(self).toOpaque(),
            init: equalizerTapInit,
            finalize: equalizerTapFinalize,
            prepare: equalizerTapPrepare,
            unprepare: equalizerTapUnprepare,
            process: equalizerTapProcess
        )
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )
        guard status == noErr, let tap else {
            CoLogger.shared.log("均衡器音频处理器创建失败：\(status)", level: .error)
            return nil
        }

        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        return mix
    }

    private func schedulePersist() {
        pendingPersistWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistNow()
        }
        pendingPersistWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func persistNow() {
        pendingPersistWorkItem?.cancel()
        pendingPersistWorkItem = nil
        defaults.set(bandGains, forKey: Self.gainsKey)
        defaults.set(selectedPreset.rawValue, forKey: Self.presetKey)
        if let selectedCustomPresetName {
            defaults.set(selectedCustomPresetName, forKey: Self.customPresetNameKey)
        } else {
            defaults.removeObject(forKey: Self.customPresetNameKey)
        }
        defaults.set(preampGain, forKey: Self.preampKey)
        if let data = try? JSONEncoder().encode(customPresets) {
            defaults.set(data, forKey: Self.customPresetsKey)
        }
    }

    private static func normalizedGains(_ values: [Double]?) -> [Double] {
        let values = values ?? []
        if values.count == 5 {
            // Migrate the original five-band layout to the nearest bands in the
            // new ten-band studio layout without discarding user adjustments.
            let legacyIndexes = [0, 2, 4, 7, 9]
            var migrated = Array(repeating: 0.0, count: bandFrequencies.count)
            for (legacyIndex, newIndex) in legacyIndexes.enumerated() where legacyIndex < values.count {
                migrated[newIndex] = values[legacyIndex]
            }
            return migrated.map(normalizedGain)
        }
        return bandFrequencies.indices.map { index in
            normalizedGain(index < values.count ? values[index] : 0)
        }
    }

    private static func normalizedGain(_ value: Double) -> Double {
        let clamped = min(max(value, -maximumGain), maximumGain)
        return (clamped * 2).rounded() / 2
    }

    private static func linearGain(for gain: Double) -> Float {
        Float(pow(10, gain / 20))
    }

    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: Self.settingsDidChange, object: self)
    }

    private func rebuildCoefficientsLocked(using gains: [Double]) {
        coefficients = zip(Self.bandFrequencies, Self.normalizedGains(gains)).map { frequency, gain in
            BiquadCoefficients.peaking(frequency: frequency, gain: gain, sampleRate: sampleRate)
        }
    }

    private func rebuildVocalCoefficientsLocked() {
        vocalCoefficients = BiquadCoefficients.peaking(frequency: 2_500, gain: 6, sampleRate: sampleRate, q: 0.7)
    }

    private func rebuildEnhancementCoefficientsLocked() {
        enhancementCoefficients = [
            BiquadCoefficients.lowShelf(frequency: 100, gain: 6, sampleRate: sampleRate),
            BiquadCoefficients.highShelf(frequency: 8_000, gain: 2, sampleRate: sampleRate),
        ]
    }

    fileprivate func prepare(with format: AudioStreamBasicDescription) {
        configurationLock.lock()
        sampleRate = max(format.mSampleRate, 8_000)
        processingFormatIsFloat32 = format.mFormatID == kAudioFormatLinearPCM
            && format.mBitsPerChannel == 32
            && (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        processingFormatIsInt16 = format.mFormatID == kAudioFormatLinearPCM
            && format.mBitsPerChannel == 16
            && (format.mFormatFlags & kAudioFormatFlagIsFloat) == 0
        filterStates = Array(repeating: .zero, count: Self.maximumChannels * Self.bandFrequencies.count)
        rebuildCoefficientsLocked(using: processingGains)
        enhancementStates = Array(repeating: .zero, count: Self.maximumChannels * 2)
        rebuildEnhancementCoefficientsLocked()
        vocalStates = Array(repeating: .zero, count: Self.maximumChannels)
        rebuildVocalCoefficientsLocked()
        let reverbScale = sampleRate / 44_100
        reverbCombDelays = [1557, 1617, 1491, 1422].map { max(1, Int(Double($0) * reverbScale)) }
        reverbAllpassDelays = [556, 441].map { max(1, Int(Double($0) * reverbScale)) }
        reverbSpread = max(1, Int(23 * reverbScale))
        reverbCombBuffers = (0..<2).map { channel in
            reverbCombDelays.map { delay in Array(repeating: 0, count: delay + (channel == 1 ? reverbSpread : 0)) }
        }
        reverbCombIndices = Array(repeating: Array(repeating: 0, count: 4), count: 2)
        reverbCombFilterStores = Array(repeating: Array(repeating: 0, count: 4), count: 2)
        reverbAllpassBuffers = (0..<2).map { _ in reverbAllpassDelays.map { delay in Array(repeating: 0, count: delay) } }
        reverbAllpassIndices = Array(repeating: Array(repeating: 0, count: 2), count: 2)
        let itdSize = max(64, Int(sampleRate * 0.001))
        itdBuffers = [Array(repeating: 0, count: itdSize), Array(repeating: 0, count: itdSize)]
        itdIndex = 0
        earlyReflectionBuffer = Array(repeating: 0, count: max(1024, Int(sampleRate * 0.1)))
        earlyReflectionIndex = 0
        reverbNeedsReset = false
        configurationLock.unlock()
    }

    fileprivate func process(bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) {
        guard frameCount > 0 else { return }
        configurationLock.lock()
        defer { configurationLock.unlock() }
        // tap 可能是 Float32 也可能是 Int16（不同解码格式）：只认 Float32 会让另一路全程静默。
        guard processingEnabled, processingFormatIsFloat32 || processingFormatIsInt16 else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        // 分开声道布局（两路各 1 声道）：交错那套按单声道会跳过摆动，先交错成一路再走同一套处理。
        if buffers.count == 2,
           Int(buffers[0].mNumberChannels) == 1, Int(buffers[1].mNumberChannels) == 1,
           let leftData = buffers[0].mData, let rightData = buffers[1].mData {
            let leftFrames = Int(buffers[0].mDataByteSize) / (processingFormatIsFloat32 ? MemoryLayout<Float>.size : MemoryLayout<Int16>.size)
            let rightFrames = Int(buffers[1].mDataByteSize) / (processingFormatIsFloat32 ? MemoryLayout<Float>.size : MemoryLayout<Int16>.size)
            let framesToProcess = min(frameCount, leftFrames, rightFrames)
            if framesToProcess > 0 {
                var interleaved = [Float](repeating: 0, count: framesToProcess * 2)
                if processingFormatIsFloat32 {
                    let left = leftData.assumingMemoryBound(to: Float.self)
                    let right = rightData.assumingMemoryBound(to: Float.self)
                    for frame in 0..<framesToProcess {
                        interleaved[frame * 2] = left[frame]
                        interleaved[frame * 2 + 1] = right[frame]
                    }
                    interleaved.withUnsafeMutableBufferPointer { pointer in
                        guard let base = pointer.baseAddress else { return }
                        processFloatSamples(base, frameCount: framesToProcess, channelCount: 2, firstChannelIndex: 0)
                    }
                    for frame in 0..<framesToProcess {
                        left[frame] = interleaved[frame * 2]
                        right[frame] = interleaved[frame * 2 + 1]
                    }
                } else {
                    let left = leftData.assumingMemoryBound(to: Int16.self)
                    let right = rightData.assumingMemoryBound(to: Int16.self)
                    for frame in 0..<framesToProcess {
                        interleaved[frame * 2] = Float(left[frame]) / 32768
                        interleaved[frame * 2 + 1] = Float(right[frame]) / 32768
                    }
                    interleaved.withUnsafeMutableBufferPointer { pointer in
                        guard let base = pointer.baseAddress else { return }
                        processFloatSamples(base, frameCount: framesToProcess, channelCount: 2, firstChannelIndex: 0)
                    }
                    for frame in 0..<framesToProcess {
                        left[frame] = Int16(clamping: Int(max(-1, min(1, interleaved[frame * 2])) * 32767))
                        right[frame] = Int16(clamping: Int(max(-1, min(1, interleaved[frame * 2 + 1])) * 32767))
                    }
                }
            }
            return
        }
        var firstChannelIndex = 0
        for buffer in buffers {
            let channelCount = max(Int(buffer.mNumberChannels), 1)
            defer { firstChannelIndex += channelCount }
            guard let rawData = buffer.mData else { continue }

            if processingFormatIsFloat32 {
                let samples = rawData.assumingMemoryBound(to: Float.self)
                let availableFrames = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * channelCount)
                let framesToProcess = min(frameCount, availableFrames)
                guard framesToProcess > 0 else { continue }
                processFloatSamples(samples, frameCount: framesToProcess, channelCount: channelCount, firstChannelIndex: firstChannelIndex)
            } else {
                let intSamples = rawData.assumingMemoryBound(to: Int16.self)
                let availableFrames = Int(buffer.mDataByteSize) / (MemoryLayout<Int16>.size * channelCount)
                let framesToProcess = min(frameCount, availableFrames)
                guard framesToProcess > 0 else { continue }
                var floatSamples = [Float](repeating: 0, count: framesToProcess * channelCount)
                for i in 0..<(framesToProcess * channelCount) {
                    floatSamples[i] = Float(intSamples[i]) / 32768
                }
                floatSamples.withUnsafeMutableBufferPointer { pointer in
                    guard let base = pointer.baseAddress else { return }
                    processFloatSamples(base, frameCount: framesToProcess, channelCount: channelCount, firstChannelIndex: firstChannelIndex)
                }
                for i in 0..<(framesToProcess * channelCount) {
                    let clamped = max(-1, min(1, floatSamples[i]))
                    intSamples[i] = Int16(clamping: Int(clamped * 32767))
                }
            }
        }
    }

    /// Float32 采样的均衡 + 3D 处理本体；Int16 先转 Float 走同一套，效果与 Float 路一致。
    private func processFloatSamples(_ samples: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int, firstChannelIndex: Int) {

            if isEnabled {
                for channelOffset in 0..<channelCount {
                    let channel = min(firstChannelIndex + channelOffset, Self.maximumChannels - 1)
                    let stateOffset = channel * Self.bandFrequencies.count
                    for frame in 0..<frameCount {
                        let sampleIndex = frame * channelCount + channelOffset
                        var sample = samples[sampleIndex] * processingPreampLinear
                        for bandIndex in coefficients.indices {
                            let stateIndex = stateOffset + bandIndex
                            let coefficient = coefficients[bandIndex]
                            var state = filterStates[stateIndex]
                            let filtered = coefficient.b0 * sample + state.z1
                            state.z1 = coefficient.b1 * sample - coefficient.a1 * filtered + state.z2
                            state.z2 = coefficient.b2 * sample - coefficient.a2 * filtered
                            filterStates[stateIndex] = state
                            sample = filtered
                        }
                        // Keep processed PCM inside the normalized range expected by
                        // the output route; values above 1.0 can become audible
                        // clipping, especially on headphones.
                        samples[sampleIndex] = sample.isFinite ? min(max(sample, -0.98), 0.98) : 0
                    }
                }
            }
            if headphoneBoostEnabled, channelCount == 2 {
                // 耳机增强：官方音质档位是酷狗给的、再高也没有了，所以在 Co 这边补一层——
                // 低音搁架 +6dB@100Hz、高音搁架 +2dB@8kHz、声场加宽 1.6（原来 1.25 在阈值附近听不出来）。
                for channelOffset in 0..<2 {
                    let channel = min(firstChannelIndex + channelOffset, Self.maximumChannels - 1)
                    let stateOffset = channel * 2
                    for frame in 0..<frameCount {
                        let sampleIndex = frame * channelCount + channelOffset
                        var sample = samples[sampleIndex]
                        for shelfIndex in enhancementCoefficients.indices {
                            let stateIndex = stateOffset + shelfIndex
                            let coefficient = enhancementCoefficients[shelfIndex]
                            var state = enhancementStates[stateIndex]
                            let filtered = coefficient.b0 * sample + state.z1
                            state.z1 = coefficient.b1 * sample - coefficient.a1 * filtered + state.z2
                            state.z2 = coefficient.b2 * sample - coefficient.a2 * filtered
                            enhancementStates[stateIndex] = state
                            sample = filtered
                        }
                        samples[sampleIndex] = sample.isFinite ? min(max(sample, -0.98), 0.98) : 0
                    }
                }
                for frame in 0..<frameCount {
                    let leftIndex = frame * channelCount
                    let rightIndex = leftIndex + 1
                    let mid = (samples[leftIndex] + samples[rightIndex]) * 0.5
                    let side = (samples[leftIndex] - samples[rightIndex]) * 0.5
                    let outLeft = mid + side * 1.6
                    let outRight = mid - side * 1.6
                    samples[leftIndex] = outLeft.isFinite ? min(max(outLeft, -0.98), 0.98) : 0
                    samples[rightIndex] = outRight.isFinite ? min(max(outRight, -0.98), 0.98) : 0
                }
            }
            if vocalBoostEnabled, channelCount == 2 {
                // 人声清晰：只提 mid 通道（人声基本在中央，伴奏在两侧），2.5kHz 宽峰值 +6dB——
                // 动的是人声相对伴奏的比例，不是全混音绝对电平，一耳朵就出来；只对立体声生效。
                var midState = vocalStates[0]
                for frame in 0..<frameCount {
                    let leftIndex = frame * channelCount
                    let rightIndex = leftIndex + 1
                    let mid = (samples[leftIndex] + samples[rightIndex]) * 0.5
                    let side = (samples[leftIndex] - samples[rightIndex]) * 0.5
                    let filtered = vocalCoefficients.b0 * mid + midState.z1
                    midState.z1 = vocalCoefficients.b1 * mid - vocalCoefficients.a1 * filtered + midState.z2
                    midState.z2 = vocalCoefficients.b2 * mid - vocalCoefficients.a2 * filtered
                    let outLeft = filtered + side
                    let outRight = filtered - side
                    samples[leftIndex] = outLeft.isFinite ? min(max(outLeft, -0.98), 0.98) : 0
                    samples[rightIndex] = outRight.isFinite ? min(max(outRight, -0.98), 0.98) : 0
                }
                vocalStates[0] = midState
            }
            if widenEnabled, channelCount == 2 {
                // 声场加宽：Mid/Side 法，side ×1.8，声场一耳朵撑开；mid 完全不动，
                // 单声道求和时 side 抵消、原混音分毫不差（不用 Haas 延迟，避免单声道梳状滤波）。
                for frame in 0..<frameCount {
                    let leftIndex = frame * channelCount
                    let rightIndex = leftIndex + 1
                    let mid = (samples[leftIndex] + samples[rightIndex]) * 0.5
                    let side = (samples[leftIndex] - samples[rightIndex]) * 0.5
                    let outLeft = mid + side * 1.8
                    let outRight = mid - side * 1.8
                    samples[leftIndex] = outLeft.isFinite ? min(max(outLeft, -0.98), 0.98) : 0
                    samples[rightIndex] = outRight.isFinite ? min(max(outRight, -0.98), 0.98) : 0
                }
            }
            if surroundEnabled, channelCount == 2 {
                // 3D 环绕 2.0：摆动只是骨架，空间感靠三样补齐——
                // ① 耳间时差 ITD：左右各一条微延迟（最大 0.6ms，真实头宽量级），声音出颅，不再只在脑袋里晃；
                // ② 混响单声道喂入 + 左右去相关：房间不动、干声在房间里动，两者一对比才有“绕头”感（原来混响跟着干声一起摆，空间感被抵消）；
                // ③ 早期反射：6 个抽头只进混响输入，给房间尺寸线索。摆动本身不变（正弦三次方、8 秒、三点停留、单耳最低 0.12）。
                // 只对立体声生效，单声道/多声道不动。
                if reverbNeedsReset {
                    reverbNeedsReset = false
                    for channel in 0..<2 {
                        for comb in 0..<4 where channel < reverbCombBuffers.count && comb < reverbCombBuffers[channel].count {
                            reverbCombBuffers[channel][comb] = Array(repeating: 0, count: reverbCombBuffers[channel][comb].count)
                        }
                        for ap in 0..<2 where channel < reverbAllpassBuffers.count && ap < reverbAllpassBuffers[channel].count {
                            reverbAllpassBuffers[channel][ap] = Array(repeating: 0, count: reverbAllpassBuffers[channel][ap].count)
                        }
                    }
                    reverbCombIndices = Array(repeating: Array(repeating: 0, count: 4), count: 2)
                    reverbCombFilterStores = Array(repeating: Array(repeating: 0, count: 4), count: 2)
                    reverbAllpassIndices = Array(repeating: Array(repeating: 0, count: 2), count: 2)
                    if itdBuffers.count == 2 {
                        itdBuffers[0] = Array(repeating: 0, count: itdBuffers[0].count)
                        itdBuffers[1] = Array(repeating: 0, count: itdBuffers[1].count)
                    }
                    itdIndex = 0
                    if !earlyReflectionBuffer.isEmpty {
                        earlyReflectionBuffer = Array(repeating: 0, count: earlyReflectionBuffer.count)
                    }
                    earlyReflectionIndex = 0
                }
                let phaseStep = 2 * Double.pi / max(sampleRate * 8, 1)
                let hasReverb = reverbCombBuffers.count >= 2 && reverbCombDelays.count == 4 && reverbAllpassDelays.count == 2
                let hasITD = itdBuffers.count == 2 && !itdBuffers[0].isEmpty && !itdBuffers[1].isEmpty
                let itdSize = hasITD ? itdBuffers[0].count : 1
                let erSize = earlyReflectionBuffer.count
                // 早期反射抽头：时间 ms / 增益 dB（只进混响输入，不进干声）。
                let erTimes: [Double] = [15, 25, 38, 52, 68, 82]
                let erGains: [Float] = [-14.0, -18.0, -21.0, -24.0, -27.0, -30.0].map { Float(pow(10.0, $0 / 20.0)) }
                for frame in 0..<frameCount {
                    surroundPanPhase += phaseStep
                    if surroundPanPhase > 2 * Double.pi { surroundPanPhase -= 2 * Double.pi }
                    let sine = sin(surroundPanPhase)
                    let pan = sine * sine * sine // 三点停留形：左、中、右都停得住，-1 全左 … +1 全右
                    let leftGain = Float(0.12 + 0.88 * cos((pan + 1) * Double.pi / 4))
                    let rightGain = Float(0.12 + 0.88 * sin((pan + 1) * Double.pi / 4))
                    let leftIndex = frame * channelCount
                    let rightIndex = leftIndex + 1
                    var outLeft = samples[leftIndex] * leftGain
                    var outRight = samples[rightIndex] * rightGain
                    if hasITD {
                        // 摆到最左时左声道早约 0.6ms、摆到最右时反过来；线性插值读数，延迟随声像缓慢变，无 zipper 噪声。
                        let delayLeft = Float((1 - pan) / 2 * 0.0006 * sampleRate)
                        let delayRight = Float((1 + pan) / 2 * 0.0006 * sampleRate)
                        itdBuffers[0][itdIndex] = outLeft
                        itdBuffers[1][itdIndex] = outRight
                        outLeft = interpolatedDelayRead(buffer: itdBuffers[0], writeIndex: itdIndex, delay: delayLeft)
                        outRight = interpolatedDelayRead(buffer: itdBuffers[1], writeIndex: itdIndex, delay: delayRight)
                        itdIndex += 1
                        if itdIndex >= itdSize { itdIndex = 0 }
                    }
                    if hasReverb {
                        // 房间不动：单声道求和喂混响，左右用 spread 去相关，湿声 0.2 不变（原来 0.35 嫌杂）。
                        let mono = (outLeft + outRight) * 0.5
                        var reverbInput = mono
                        if erSize > 0 {
                            earlyReflectionBuffer[earlyReflectionIndex] = mono
                            for tap in 0..<erTimes.count {
                                let tapDelay = max(1, Int(erTimes[tap] / 1000 * sampleRate))
                                var tapIndex = earlyReflectionIndex - tapDelay
                                tapIndex %= erSize
                                if tapIndex < 0 { tapIndex += erSize }
                                reverbInput += earlyReflectionBuffer[tapIndex] * erGains[tap]
                            }
                            earlyReflectionIndex += 1
                            if earlyReflectionIndex >= erSize { earlyReflectionIndex = 0 }
                        }
                        outLeft += reverbSample(input: reverbInput, channel: 0) * 0.2
                        outRight += reverbSample(input: reverbInput, channel: 1) * 0.2
                    }
                    samples[leftIndex] = outLeft.isFinite ? min(max(outLeft, -0.98), 0.98) : 0
                    samples[rightIndex] = outRight.isFinite ? min(max(outRight, -0.98), 0.98) : 0
                }
            }
    }

    /// 延迟线线性插值读数：writeIndex 是刚写入的位置，delay 为采样数（可含小数），读数点在过去。
    private func interpolatedDelayRead(buffer: [Float], writeIndex: Int, delay: Float) -> Float {
        guard !buffer.isEmpty else { return 0 }
        let size = buffer.count
        var readPos = Float(writeIndex) - delay
        while readPos < 0 { readPos += Float(size) }
        let i0 = Int(readPos) % size
        let i1 = (i0 + 1) % size
        let frac = readPos - Float(Int(readPos))
        return buffer[i0] * (1 - frac) + buffer[i1] * frac
    }

    /// 单声道混响（Freeverb 精简版）：4 梳状并联 + 2 全通串联，只出湿声，由调用方按 0.2 混入。
    private func reverbSample(input: Float, channel: Int) -> Float {
        guard channel < reverbCombBuffers.count,
              reverbCombDelays.count == 4, reverbAllpassDelays.count == 2 else { return 0 }
        var combSum: Float = 0
        for comb in 0..<4 {
            let delay = reverbCombDelays[comb] + (channel == 1 ? reverbSpread : 0)
            var index = reverbCombIndices[channel][comb]
            let output = reverbCombBuffers[channel][comb][index]
            var filterStore = reverbCombFilterStores[channel][comb]
            filterStore = output * 0.8 + filterStore * 0.2
            reverbCombFilterStores[channel][comb] = filterStore
            reverbCombBuffers[channel][comb][index] = input + filterStore * 0.75
            index += 1
            if index >= delay { index = 0 }
            reverbCombIndices[channel][comb] = index
            combSum += output
        }
        var signal = combSum * 0.25
        for ap in 0..<2 {
            let delay = reverbAllpassDelays[ap]
            var index = reverbAllpassIndices[channel][ap]
            let bufferOut = reverbAllpassBuffers[channel][ap][index]
            let output = -signal + bufferOut
            reverbAllpassBuffers[channel][ap][index] = signal + bufferOut * 0.5
            index += 1
            if index >= delay { index = 0 }
            reverbAllpassIndices[channel][ap] = index
            signal = output
        }
        return signal
    }

}

private func equalizerTapInit(
    _ tap: MTAudioProcessingTap,
    clientInfo: UnsafeMutableRawPointer?,
    tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

private func equalizerTapFinalize(_ tap: MTAudioProcessingTap) {}

private func equalizerTapPrepare(
    _ tap: MTAudioProcessingTap,
    maxFrames: CMItemCount,
    processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    let storage = MTAudioProcessingTapGetStorage(tap)
    let equalizer = Unmanaged<CoEqualizer>.fromOpaque(storage).takeUnretainedValue()
    equalizer.prepare(with: processingFormat.pointee)
}

private func equalizerTapUnprepare(_ tap: MTAudioProcessingTap) {}

private func equalizerTapProcess(
    _ tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    flags: MTAudioProcessingTapFlags,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    let _ = flags
    var sourceFlags = MTAudioProcessingTapFlags()
    var sourceFrames: CMItemCount = 0
    let status = MTAudioProcessingTapGetSourceAudio(
        tap,
        numberFrames,
        bufferListInOut,
        &sourceFlags,
        nil,
        &sourceFrames
    )
    guard status == noErr else {
        numberFramesOut.pointee = 0
        flagsOut.pointee = sourceFlags
        return
    }

    numberFramesOut.pointee = sourceFrames
    flagsOut.pointee = sourceFlags
    let storage = MTAudioProcessingTapGetStorage(tap)
    let equalizer = Unmanaged<CoEqualizer>.fromOpaque(storage).takeUnretainedValue()
    equalizer.process(bufferList: bufferListInOut, frameCount: Int(sourceFrames))
}

private struct BiquadCoefficients {
    let b0: Float
    let b1: Float
    let b2: Float
    let a1: Float
    let a2: Float

    static let identity = BiquadCoefficients(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)

    static func peaking(frequency: Double, gain: Double, sampleRate: Double, q: Double = 1) -> BiquadCoefficients {
        guard abs(gain) > 0.001 else { return .identity }
        let clampedFrequency = min(max(frequency, 20), sampleRate * 0.45)
        let amplitude = pow(10, gain / 40)
        let omega = 2 * Double.pi * clampedFrequency / sampleRate
        let alpha = sin(omega) / (2 * max(q, 0.05))
        let cosine = cos(omega)
        let b0 = 1 + alpha * amplitude
        let b1 = -2 * cosine
        let b2 = 1 - alpha * amplitude
        let a0 = 1 + alpha / amplitude
        let a1 = -2 * cosine
        let a2 = 1 - alpha / amplitude
        return BiquadCoefficients(
            b0: Float(b0 / a0),
            b1: Float(b1 / a0),
            b2: Float(b2 / a0),
            a1: Float(a1 / a0),
            a2: Float(a2 / a0)
        )
    }

    static func lowShelf(frequency: Double, gain: Double, sampleRate: Double) -> BiquadCoefficients {
        shelf(frequency: frequency, gain: gain, sampleRate: sampleRate, high: false)
    }

    static func highShelf(frequency: Double, gain: Double, sampleRate: Double) -> BiquadCoefficients {
        shelf(frequency: frequency, gain: gain, sampleRate: sampleRate, high: true)
    }

    private static func shelf(frequency: Double, gain: Double, sampleRate: Double, high: Bool) -> BiquadCoefficients {
        guard abs(gain) > 0.001 else { return .identity }
        let clampedFrequency = min(max(frequency, 20), sampleRate * 0.45)
        let amplitude = pow(10, gain / 40)
        let omega = 2 * Double.pi * clampedFrequency / sampleRate
        let sine = sin(omega)
        let cosine = cos(omega)
        let slope: Double = 0.9
        let alpha = sine / 2 * sqrt((amplitude + 1 / amplitude) * (1 / slope - 1) + 2)
        let sqrtAmplitude = sqrt(amplitude)
        let b0: Double
        let b1: Double
        let b2: Double
        let a0: Double
        let a1: Double
        let a2: Double
        if high {
            b0 = amplitude * ((amplitude + 1) + (amplitude - 1) * cosine + 2 * sqrtAmplitude * alpha)
            b1 = -2 * amplitude * ((amplitude - 1) + (amplitude + 1) * cosine)
            b2 = amplitude * ((amplitude + 1) + (amplitude - 1) * cosine - 2 * sqrtAmplitude * alpha)
            a0 = (amplitude + 1) - (amplitude - 1) * cosine + 2 * sqrtAmplitude * alpha
            a1 = 2 * ((amplitude - 1) - (amplitude + 1) * cosine)
            a2 = (amplitude + 1) - (amplitude - 1) * cosine - 2 * sqrtAmplitude * alpha
        } else {
            b0 = amplitude * ((amplitude + 1) - (amplitude - 1) * cosine + 2 * sqrtAmplitude * alpha)
            b1 = 2 * amplitude * ((amplitude - 1) - (amplitude + 1) * cosine)
            b2 = amplitude * ((amplitude + 1) - (amplitude - 1) * cosine - 2 * sqrtAmplitude * alpha)
            a0 = (amplitude + 1) + (amplitude - 1) * cosine + 2 * sqrtAmplitude * alpha
            a1 = -2 * ((amplitude - 1) + (amplitude + 1) * cosine)
            a2 = (amplitude + 1) + (amplitude - 1) * cosine - 2 * sqrtAmplitude * alpha
        }
        return BiquadCoefficients(
            b0: Float(b0 / a0),
            b1: Float(b1 / a0),
            b2: Float(b2 / a0),
            a1: Float(a1 / a0),
            a2: Float(a2 / a0)
        )
    }
}

private struct BiquadState {
    var z1: Float = 0
    var z2: Float = 0

    static let zero = BiquadState()
}